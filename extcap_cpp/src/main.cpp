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

    struct pcaprec_hdr_t {
        uint32_t ts_sec;         // timestamp seconds
        uint32_t ts_usec;        // timestamp microseconds
        uint32_t incl_len;       // number of bytes of packet saved in file
        uint32_t orig_len;       // actual length of packet
    };
    
int run_extcap_capture(const std::string& fifo_path, const std::string& device_path) {
    std::cerr << "[DEBUG] Entered run_extcap_capture()\n";

    int fd_fifo = open(fifo_path.c_str(), O_WRONLY);
    if (fd_fifo < 0) {
        std::cerr << "[ERROR] Could not open FIFO: " << strerror(errno) << "\n";
        return 1;
    }

    std::cerr << "[DEBUG] Writing PCAP header...\n";
    write_pcap_global_header(fd_fifo);

    int fd_uart = open(device_path.c_str(), O_RDWR | O_NOCTTY);
    if (fd_uart < 0) {
        std::cerr << "[ERROR] Could not open UART: " << strerror(errno) << "\n";
        close(fd_fifo);
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
            // Get current time
            auto now = std::chrono::system_clock::now();
            auto duration = now.time_since_epoch();
            auto micros = std::chrono::duration_cast<std::chrono::microseconds>(duration).count();

            uint32_t ts_sec = micros / 1000000;
            uint32_t ts_usec = micros % 1000000;

            pcaprec_hdr_t pkt_header;
            pkt_header.ts_sec = ts_sec;
            pkt_header.ts_usec = ts_usec;
            pkt_header.incl_len = bytes_read;
            pkt_header.orig_len = bytes_read;

            write(fd_fifo, &pkt_header, sizeof(pkt_header));
            write(fd_fifo, buffer, bytes_read);
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
    
    bool capture_mode = false;

    // First pass: check if capture mode is requested
    for (int i = 1; i < argc; ++i) {
        if (std::string(argv[i]) == "--capture") {
            capture_mode = true;
            break;
        }
    }

    if (!capture_mode) {
        // Handle extcap discovery options
        for (int i = 1; i < argc; ++i) {
            std::string arg(argv[i]);

            if (arg == "--extcap-interfaces") {
                std::cout << "extcap {version=1.0}{help=https://example.com/help}\n";
                std::cout << "interface {value=" << interface_name << "}{display=FPGA UART Interface}\n";
                return 0;
            } else if (arg == "--extcap-interface" && i + 1 < argc) {
                std::string iface(argv[++i]);
                if (iface == interface_name) {
                    std::cout << "dlt {number=147}{name=USER0}{display=User DLT 0}\n";
                    return 0;
                }
            } else if (arg == "--extcap-config") {
                std::cout << "arg {number=0}{call=--serial-device}{display=Serial Device}"
                            "{tooltip=Select the UART device}{type=selector}{required=true}{group=UART}\n";
                for (const auto& dev : list_uart_devices()) {
                    std::cout << "value {arg=0}{value=" << dev << "}{display=" << dev << "}\n";
                }
                return 0;
            } else if (arg == "--extcap-version") {
                std::cout << "extcap_uart version 1.0\n";
                return 0;
            }
        }
    }

    std::string fifo_path;
    std::string selected_device;

    for (int i = 1; i < argc; ++i) {
        std::string arg(argv[i]);
        if (arg == "--fifo" && i + 1 < argc) {
            fifo_path = argv[++i];
        } else if (arg == "--serial-device" && i + 1 < argc) {
            selected_device = argv[++i];
        }
    }

    if (capture_mode) {
        std::cerr << "Running capture mode:\n";
        std::cerr << "  Interface: " << interface_name << "\n";
        std::cerr << "  FIFO: " << fifo_path << "\n";
        std::cerr << "  UART: " << selected_device << "\n";

        if (!fifo_path.empty() && !selected_device.empty()) {
            return run_extcap_capture(fifo_path, selected_device);
        } else {
            std::cerr << "Missing fifo or serial-device!\n";
            return 1;
        }
    }
}
