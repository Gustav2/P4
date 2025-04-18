# Makefile for extcap_uart

TARGET = extcap_uart
BUILD_DIR = build
SRC = src/main.cpp
INSTALL_PATH = /usr/lib/x86_64-linux-gnu/wireshark/extcap

CXX = g++
CXXFLAGS = -O2 -Wall -std=c++17

all: $(BUILD_DIR)/$(TARGET)

$(BUILD_DIR)/$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) -o $@ $^

clean:
	rm -f $(BUILD_DIR)/$(TARGET)

install: $(BUILD_DIR)/$(TARGET)
	sudo cp $(BUILD_DIR)/$(TARGET) $(INSTALL_PATH)/
	sudo chmod +x $(INSTALL_PATH)/$(TARGET)

reinstall: clean all install
