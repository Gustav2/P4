# !!!!!!!!!!! NOT FUNCTIONAL DO NOT RUN !!!!!!!!!!!

# This Makefile is used to build the SPI Sniffer interface for Wireshark.
# It installs:
# - the configuration profile accessibly through Edit -> Configuration Profiles
# - the dissector plugin
# - the extcap interface

CXX = g++
CXXFLAGS = -O2 -Wall -std=c++17

HOME_DIR := $(shell echo ${HOME})
WIRESHARK_PATH = $(HOME_DIR)/.local/lib/wireshark
CONFIG_DIR = $(HOME_DIR)/.config/wireshark/profiles

SRC_DISSECTOR = wireshark_dissector/spi_dissector.lua
EXTCAP_SRC = wireshark_extcap/src/main.cpp
EXTCAP_TARGET = wireshark_extcap/build/extcap_uart

all: confirm_paths build_extcap install_extcap install_lua install_config
	@echo "All components installed succesfully!"
	@echo "Wireshark directory: $(WIRESHARK_PATH)"
	@echo "Lua dissector path: $(WIRESHARK_PATH)/plugins/spi_dissector.lua"

$(EXTCAP_TARGET): $(EXTCAP_SRC)
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

install_extcap: $(EXTCAP_TARGET)
	@echo "1: Installing extcap interface"
	@mkdir -p $(WIRESHARK_PATH)/extcap
	@cp $(EXTCAP_TARGET) $(WIRESHARK_PATH)/extcap/
	@echo "   Extcap interface installed succesfully"
#	sudo chmod +x /usr/lib/x86_64-linux-gnu/wireshark/extcap/$(notdir $(EXTCAP_TARGET))

install_lua:
	@echo "2: Installing Lua dissector"
	@mkdir -p $(WIRESHARK_PATH)/plugins
	@cp $(SRC_DISSECTOR) $(WIRESHARK_PATH)/plugins/
	@echo "   Lua dissector installed"

install_config:
	@echo "3: Installing configuration profile"
	@mkdir -p $(CONFIG_DIR)
	@cp -r wireshark_dissector/SPI_Config $(CONFIG_DIR)/
	@echo "   Configuration profile installed."

confirm_paths:
	@echo "Wireshark directory: $(WIRESHARK_PATH)"
	@echo "Lua dissector path: $(WIRESHARK_PATH)/plugins/spi_dissector.lua"
	@echo "Configuration profile path: $(CONFIG_DIR)/SPI_Config"
	@echo "Extcap interface path: $(WIRESHARK_PATH)/extcap/extcap_uart"
	@read -p "Are these paths correct? (y/n): " confirm && [ "$$confirm" = "y" ] || (echo "Aborted by user." && exit 1)

.PHONY: all install_lua install_config install_extcap build_extcap comfirm_paths