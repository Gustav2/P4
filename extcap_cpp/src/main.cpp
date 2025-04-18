#include <iostream>
#include <fcntl.h>
#include <unistd.h>
#include <cstring>
#include <cerrno>
#include <asm/termbits.h>
#include <sys/ioctl.h>
#include <filesystem>
#include <chrono>
#include <thread>
#include <algorithm>
#include <string>
#include <vector>

namespace fs = std::filesystem;

bool configure_serial_port(int fd, int baudrate) {
    struct termios2 tio;
    if (ioctl(fd, TCGETS2, &tio) < 0) {
        std::cerr << "Failed to get termios2: " << strerror(errno) << std::endl;
        return false;
    }

    tio.c_cflag &= ~CBAUD;
    tio.c_cflag |= BOTHER;
    tio.c_ispeed = baudrate;
    tio.c_ospeed = baudrate;

    tio.c_cflag |= CS8 | CLOCAL | CREAD;
    tio.c_iflag = 0;
    tio.c_oflag = 0;
    tio.c_lflag = 0;
    tio.c_cc[VMIN] = 1;
    tio.c_cc[VTIME] = 0;

    if (ioctl(fd, TCSETS2, &tio) < 0) {
        std::cerr << "Failed to set termios2: " << strerror(errno) << std::endl;
        return false;
    }

    return true;
}

int run_uart_capture() {
    std::string device_path;

    for (const auto& entry : fs::directory_iterator("/dev")) {
        if (entry.path().string().find("ttyUSB") != std::string::npos) {
            device_path = entry.path();
            std::cout << "Found device: " << device_path << std::endl;
            break;
        }
    }

    if (device_path.empty()) {
        std::cerr << "No ttyUSB devices found." << std::endl;
        return 1;
    }

    int fd = open(device_path.c_str(), O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fd < 0) {
        std::cerr << "Failed to open " << device_path << ": " << strerror(errno) << std::endl;
        return 1;
    }

    if (!configure_serial_port(fd, 12000000)) { // 12 Mbaud
        close(fd);
        return 1;
    }

    std::cout << "Serial port configured for high-speed!" << std::endl;

    const int IDLE_TIMEOUT_MS = 300;
    const size_t BUFFER_SIZE = 512;
    uint8_t buffer[BUFFER_SIZE];
    size_t total_bytes = 0;

    auto start_time = std::chrono::steady_clock::now();
    auto last_read_time = start_time;

    while (true) {
        ssize_t bytes_read = read(fd, buffer, BUFFER_SIZE);
        auto now = std::chrono::steady_clock::now();

        if (bytes_read > 0) {
            total_bytes += bytes_read;
            last_read_time = now;

            // Optional: uncomment for live debug output
            // std::cout << "Read " << bytes_read << " bytes" << std::endl;
        } else {
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - last_read_time).count();
            if (elapsed > IDLE_TIMEOUT_MS) {
                break;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }

    auto end_time = std::chrono::steady_clock::now();
    double duration_seconds = std::chrono::duration_cast<std::chrono::duration<double>>(end_time - start_time).count();

    std::cout << "Received total: " << total_bytes << " bytes in " << duration_seconds << " seconds." << std::endl;

    if (duration_seconds > 0.0) {
        double throughput = total_bytes / (1024.0 * 1024.0) / duration_seconds;
        std::cout << "Throughput: " << throughput << " MiB/s" << std::endl;
    }

    close(fd);
    return 0;
}

int run_extcap_capture(const std::string& fifo_path) {
    std::string device_path;

    for (const auto& entry : fs::directory_iterator("/dev")) {
        if (entry.path().string().find("ttyUSB") != std::string::npos) {
            device_path = entry.path();
            std::cout << "Found device: " << device_path << std::endl;
            break;
        }
    }

    if (device_path.empty()) {
        std::cerr << "No ttyUSB devices found." << std::endl;
        return 1;
    }

    int fd_uart = open(device_path.c_str(), O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fd_uart < 0) {
        std::cerr << "Failed to open UART: " << strerror(errno) << std::endl;
        return 1;
    }

    if (!configure_serial_port(fd_uart, 12000000)) {
        close(fd_uart);
        return 1;
    }

    std::cout << "UART configured, opening FIFO: " << fifo_path << std::endl;

    int fd_fifo = open(fifo_path.c_str(), O_WRONLY);
    if (fd_fifo < 0) {
        std::cerr << "Failed to open FIFO: " << strerror(errno) << std::endl;
        close(fd_uart);
        return 1;
    }

    const int IDLE_TIMEOUT_MS = 300;
    const size_t BUFFER_SIZE = 512;
    uint8_t buffer[BUFFER_SIZE];

    auto last_read_time = std::chrono::steady_clock::now();

    while (true) {
        ssize_t bytes_read = read(fd_uart, buffer, BUFFER_SIZE);
        auto now = std::chrono::steady_clock::now();

        if (bytes_read > 0) {
            write(fd_fifo, buffer, bytes_read);
            last_read_time = now;
        } else {
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - last_read_time).count();
            if (elapsed > IDLE_TIMEOUT_MS) {
                break;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }

    close(fd_uart);
    close(fd_fifo);
    return 0;
}

int main(int argc, char* argv[]) {
    std::vector<std::string> args(argv + 1, argv + argc);

    // Handle --extcap-interfaces
    if (std::find(args.begin(), args.end(), "--extcap-interfaces") != args.end()) {
        std::cout << "extcap {version=1.0}{display=UART Extcap Interface}" << std::endl;
        std::cout << "interface {value=uart0}{display=FPGA UART @ 12Mbaud}" << std::endl;
        return 0;
    }

    // Handle --extcap-interface
    if (std::find(args.begin(), args.end(), "--extcap-interface=uart0") != args.end()) {
        std::cout << "extcap {\n    version = \"1.0\"\n    display = \"FPGA UART @ 12Mbaud\"\n}" << std::endl;
        std::cout << "interface {\n    value = \"uart0\"\n    dlt = 147\n    display = \"FPGA UART interface\"\n}" << std::endl;
        return 0;
    }

    // Handle --capture
    auto it = std::find_if(args.begin(), args.end(), [](const std::string& arg) {
        return arg.find("--fifo=") == 0;
    });

    if (std::find(args.begin(), args.end(), "--capture") != args.end() && it != args.end()) {
        std::string fifo_path = it->substr(strlen("--fifo="));
        return run_extcap_capture(fifo_path);
    }

    // Default to test capture for standalone use
    return run_uart_capture();
}


