# Makefile for extcap_uart

CXX = g++
CXXFLAGS = -O2 -Wall -std=c++17
LDFLAGS =
TARGET = build/extcap_uart
SRC = src/main.cpp

.PHONY: all clean install

all: $(TARGET)

$(TARGET): $(SRC)
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

install: $(TARGET)
	sudo cp $(TARGET) /usr/lib/x86_64-linux-gnu/wireshark/extcap/
	sudo chmod +x /usr/lib/x86_64-linux-gnu/wireshark/extcap/$(notdir $(TARGET))

clean:
	rm -f $(TARGET)
