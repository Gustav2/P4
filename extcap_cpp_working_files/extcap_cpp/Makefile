# Makefile for extcap_uart

CXX = g++
CXXFLAGS = -O2 -Wall -std=c++17
LDFLAGS = 
TARGET = build/extcap_uart
SRC = src/main.cpp

# If you get linker errors about filesystem, uncomment the line below:
# LDFLAGS += -lstdc++fs

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(TARGET)
