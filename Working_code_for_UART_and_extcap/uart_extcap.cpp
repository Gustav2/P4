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
#include <string>
#include <filesystem>
#include <regex>
#include <netinet/in.h> // For htonl()

namespace fs = std::filesystem;

    std::vector<std::string> list_uart_devices() {
    std::vector<std::string> devices;
    const std::regex ttyusb_regex("^ttyUSB[0-9]+$");

    for (const auto& entry : fs::directory_iterator("/dev")) {
        std::string name = entry.path().filename();
        if (std::regex_match(name, ttyusb_regex)) {
            devices.push_back("/dev/" + name);
        }
    }

    return devices;
}

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

    struct PcapGlobalHeader {
        uint32_t magic_number = 0xa1b2c3d4;
        uint16_t version_major = 2;
        uint16_t version_minor = 4;
        int32_t  thiszone = 0;
        uint32_t sigfigs = 0;
        uint32_t snaplen = 65535;
        uint32_t network = 147; // DLT = USER0
    };

    void write_pcap_global_header(int fd) {
        PcapGlobalHeader header;
        write(fd, &header, sizeof(header));
    }

int run_extcap_capture(const std::string& fifo_path, const std::string& device_path) {
    int fd_fifo = open(fifo_path.c_str(), O_WRONLY);
    if (fd_fifo < 0) {
        std::cerr << "Failed to open FIFO: " << strerror(errno) << std::endl;
        return 1;
    }

    write_pcap_global_header(fd_fifo); // ✅ Write header early

    int fd_uart = open(device_path.c_str(), O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fd_uart < 0) {
        std::cerr << "Failed to open UART: " << strerror(errno) << std::endl;
        close(fd_fifo); // Don't forget to close
        return 1;
    }

    if (!configure_serial_port(fd_uart, 12000000)) {
        close(fd_uart);
        close(fd_fifo);
        return 1;
    }

    const size_t BUFFER_SIZE = 512;
    uint8_t buffer[BUFFER_SIZE];

    while (true) {
        ssize_t bytes_read = read(fd_uart, buffer, BUFFER_SIZE);
        if (bytes_read > 0) {
            ssize_t bytes_written = write(fd_fifo, buffer, bytes_read);
            if (bytes_written != bytes_read) {
                std::cerr << "Warning: not all bytes written to FIFO!" << std::endl;
            }
        } else {
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }

    close(fd_uart);
    close(fd_fifo);
    return 0;
}

int main(int argc, char* argv[]) {
    std::cerr << "Arguments passed to extcap_uart:\n";
    for (int i = 0; i < argc; ++i) {
        std::cerr << "  argv[" << i << "] = " << argv[i] << "\n";
    }    

    std::string interface_name = "fpga_uart";
    std::string fifo_path;
    std::string selected_device;

    for (int i = 1; i < argc; ++i) {
        std::string arg(argv[i]);

        if (arg == "--extcap-interfaces") {
            std::cout << "extcap {version=1.0}{help=https://example.com/help}\n";
            std::cout << "interface {value=" << interface_name << "}{display=FPGA UART Interface}\n";
            return 0;
        } else if (arg == "--extcap-interface") {
            if (i + 1 < argc && argv[i + 1] == interface_name) {
                std::cout << "dlt {number=147}{name=USER0}{display=User DLT 0}\n";
                return 0;
            }
        } else if (arg == "--extcap-config") {
            std::cout << "arg {number=0}{call=--serial-device}{display=Serial Device}{tooltip=Select the UART device}"
                         "{type=selector}{required=true}{group=UART}\n";
            for (const auto& dev : list_uart_devices()) {
                std::cout << "value {arg=0}{value=" << dev << "}{display=" << dev << "}\n";
            }
            return 0;
        } else if (arg == "--capture") {
            // Start capture after parsing all args
        } else if (arg == "--fifo" && i + 1 < argc) {
            fifo_path = argv[++i];
        } else if (arg == "--serial-device" && i + 1 < argc) {
            selected_device = argv[++i];
        } else if (arg == "--extcap-version") {
            std::cout << "extcap_uart version 1.0\n";
            return 0;
        }
    }

    if (!fifo_path.empty() && !selected_device.empty()) {
        std::cerr << "Running capture with:\n";
        std::cerr << "  FIFO = " << fifo_path << "\n";
        std::cerr << "  UART = " << selected_device << "\n";
        return run_extcap_capture(fifo_path, selected_device);
    }

    std::cerr << "Missing required arguments (--fifo and --serial-device)\n";

    if (!fifo_path.empty() && !selected_device.empty()) {
        return run_extcap_capture(fifo_path, selected_device);
    }

    std::cerr << "Missing required arguments (--fifo and --serial-device)\n";
    return 1;
}

