#include <SPI.h>

#define SPI_SS 10 // Chip Select Pin

void setup() {
    Serial.begin(115200); // USB Serial for Wireshark
    SPI.begin();          // Initialize SPI
    pinMode(SPI_SS, OUTPUT);
    digitalWrite(SPI_SS, HIGH);
}

void loop() {
    byte spiDataOut = random(0x00, 0xFF);  // Test byte to send, random
    byte spiDataIn = random(0x00, 0xFF);   // Random too
    String outboundData;

    // Randomly set SS to HIGH or LOW
    int ssState = random(0, 2); // Generate random state (0 or 1)
    digitalWrite(SPI_SS, ssState); // Set SS pin to the random state

    // Format the SPI data for Wireshark

    spiDataOutString = String(spiDataOut, HEX);
    spiDataInString = String(spiDataIn, HEX);
    // Convert to uppercase and add leading zeros
    spiDataOutString.toUpperCase();
    spiDataInString.toUpperCase();

    outboundData = "SPI_OUT: " + spiDataOutString + ", " +
                   "SPI_IN: " + spiDataInString + ", " +
                   "SPI_SS: " + (ssState == 0 ? "0" : "1");

    // Send the formatted data over Serial
    Serial.println(outboundData);

    // Slow down the loop for readability
    delay(100);
}