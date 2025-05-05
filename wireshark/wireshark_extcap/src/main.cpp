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
#include <netinet/in.h> 
#include <signal.h>

namespace fs = std::filesystem;

#define LOG_INFO(msg)  std::cout << "[INFO] " << msg << std::endl  // Use clog
#define LOG_ERROR(msg) std::cerr << "[ERROR] " << msg << std::endl // Keep errors on cerr

// Function to list available UART devices
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

// Function to configure the serial port
bool configure_serial_port(int fd, int baudrate) {
    struct termios2 tio;
    if (ioctl(fd, TCGETS2, &tio) < 0) {
        LOG_ERROR("Failed to get termios2: " << strerror(errno));
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
        LOG_ERROR("Failed to set termios2: " << strerror(errno));
        return false;
    }

    return true;
}

// PCAP Global Header
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
    ssize_t result = write(fd, &header, sizeof(header));
    if (result == -1) {
        if (errno == EPIPE || errno == EBADF) {
            // FIFO closed by Wireshark — silently exit
            std::exit(0);
        } else {
            LOG_ERROR("write() PCAP header failed: " << strerror(errno));
            std::exit(1);
        }
    }
}


// PCAP Record Header, used for each packet
struct pcaprec_hdr_t {
    uint32_t ts_sec;         // timestamp seconds
    uint32_t ts_usec;        // timestamp microseconds
    uint32_t incl_len;       // number of bytes of packet saved in file
    uint32_t orig_len;       // actual length of packet
};

// Function to run the extcap capture
int run_extcap_capture(const std::string& fifo_path, const std::string& device_path, int baudrate, int buffer_size) {
    LOG_INFO("Running extcap capture...");

    // Create the FIFO if it doesn't exist
    int fd_fifo = open(fifo_path.c_str(), O_WRONLY);
    if (fd_fifo < 0) {
        LOG_ERROR("Could not open FIFO: " << fifo_path << " - " << strerror(errno));
        return 1;
    }

    LOG_INFO("FIFO opened: " << fifo_path);
    write_pcap_global_header(fd_fifo);

    // Open the UART device
    int fd_uart = open(device_path.c_str(), O_RDWR | O_NOCTTY);
    if (fd_uart < 0) {
        LOG_ERROR("Could not open UART device: " << device_path << " - " << strerror(errno));
        close(fd_fifo);
        return 1;
    }

    // Use provided baudrate
    if (!configure_serial_port(fd_uart, baudrate)) {
        close(fd_uart);
        close(fd_fifo);
        return 1;
    }

    uint8_t buffer[buffer_size];

    // Set the UART to non-blocking mode
    while (true) {
        ssize_t bytes_read = read(fd_uart, buffer, buffer_size);
        if (bytes_read > 0) {
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

            ssize_t header_written = write(fd_fifo, &pkt_header, sizeof(pkt_header));
            if (header_written == -1) {
                if (errno == EPIPE || errno == EBADF) {
                    break; // FIFO closed by Wireshark — exit loop
                } else {
                    LOG_ERROR("write() header failed: " << strerror(errno));
                    break;
                }
            }

            ssize_t data_written = write(fd_fifo, buffer, bytes_read);
            if (data_written == -1) {
                if (errno == EPIPE || errno == EBADF) {
                    break;
                } else {
                    LOG_ERROR("write() data failed: " << strerror(errno));
                    break;
                }
            }

        } else {
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }

    close(fd_uart);
    close(fd_fifo);
    return 0;
}

// Main function to handle arguments and run the extcap
int main(int argc, char* argv[]) {
    LOG_INFO("FPGA UART Extcap started");
    for (int i = 0; i < argc; ++i) {
        std::cout << "  argv[" << i << "] = " << argv[i] << "\n";
    }

    signal(SIGPIPE, SIG_IGN);

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
                // UART device selection
                std::cout << "arg {number=0}{call=--serial-device}{display=Serial Device}"
                             "{tooltip=Select the UART device}{type=selector}{required=true}{group=UART}\n";
                for (const auto& dev : list_uart_devices()) {
                    std::cout << "value {arg=0}{value=" << dev << "}{display=" << dev << "}\n";
                }

                // Baudrate selection
                std::cout << "arg {number=1}{call=--baudrate}{display=Baud Rate}"
                             "{tooltip=Set the UART baud rate (e.g. 12000000)}"
                             "{type=string}{default=12000000}{group=UART}\n";
                
                // Buffer size selection
                std::cout << "arg {number=2}{call=--buffer-size}{display=Buffer Size}"
                             "{tooltip=Set the buffer size (e.g. 6)}"
                             "{type=string}{default=6}{group=UART}\n";

                return 0;
            } else if (arg == "--extcap-version") {
                std::cout << "extcap_uart version 1.0\n";
                return 0;
            }
        }
    }

    std::string fifo_path;
    std::string selected_device;
    int baudrate = 12000000;  // Default baudrate
    int buffer_size = 6;      // Default buffer size

    // Second pass: parse the arguments
    for (int i = 1; i < argc; ++i) {
        std::string arg(argv[i]);
        if (arg == "--fifo" && i + 1 < argc) {
            fifo_path = argv[++i];
        } else if (arg == "--serial-device" && i + 1 < argc) {
            selected_device = argv[++i];
        } else if (arg == "--baudrate" && i + 1 < argc) {
            baudrate = std::stoi(argv[++i]);
        } else if (arg == "--buffer-size" && i + 1 < argc) {
            buffer_size = std::stoi(argv[++i]);
        }
    }

    // Check if we are in capture mode
    if (capture_mode) {
        LOG_INFO("Capture mode activated");
        LOG_INFO("Interface: " << interface_name);
        LOG_INFO("FIFO: " << fifo_path);
        LOG_INFO("UART: " << selected_device);
        LOG_INFO("Baudrate: " << baudrate);
        LOG_INFO("Buffer size: " << buffer_size);

        if (!fifo_path.empty() && !selected_device.empty()) {
            return run_extcap_capture(fifo_path, selected_device, baudrate, buffer_size);
        } else {
            LOG_ERROR("FIFO path or UART device not specified.");
            return 1;
        }
    }

    return 0;
}
