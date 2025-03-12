SRC_DIR := $(shell find / -type d -name "wireshark_extcap" 2>/dev/null | head -n 1)
DEST_DIR := $(shell find / -type d -name "extcap" 2>/dev/null | head -n 1)
FILE := spi_sniffer
VENV := $(SRC_DIR)/.venv

build:
	@echo "Building $(FILE)..."
	@echo "Creating virtual environment and installing dependencies..."
	python3 -m venv $(VENV)
	$(VENV)/bin/python -m pip install --upgrade pip
	$(VENV)/bin/python -m pip install -r $(SRC_DIR)/requirements.txt
	@echo "Building executable..."
	$(VENV)/bin/pyinstaller --onefile $(SRC_DIR)/$(FILE).py
	mv $(SRC_DIR)/dist/$(FILE) $(SRC_DIR)/$(FILE)

copy:
	@echo "Requesting sudo access for copying the file to $(DEST_DIR)"
	sudo cp $(SRC_DIR)/$(FILE) $(DEST_DIR)/
	sudo chmod +x $(DEST_DIR)/$(FILE) 
	rm -rf $(SRC_DIR)/$(FILE)
	rm -rf $(SRC_DIR)/dist
	rm -rf $(SRC_DIR)/build
	rm -rf $(SRC_DIR)/$(FILE).spec
	@echo "Cleaning up..."
	@echo "Done!"

all: build copy

.PHONY: all build copy