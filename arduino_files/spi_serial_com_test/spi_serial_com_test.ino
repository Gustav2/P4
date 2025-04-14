#include <SPI.h>

#define SPI_SS 10 // Chip Select Pin

void setup() {
    Serial.begin(115200); // USB Serial for Wireshark
    SPI.begin();          // Initialize SPI
    pinMode(SPI_SS, OUTPUT);
    digitalWrite(SPI_SS, HIGH);
}

void loop() {
    byte spiDataOut = 0xA5;  // Test byte to send
    byte spiDataIn;
    String outboundData;

    // Select slave
    digitalWrite(SPI_SS, LOW);

    // Send & receive data
    spiDataIn = SPI.transfer(spiDataOut);

    // Deselect slave
    digitalWrite(SPI_SS, HIGH);

    // Format the SPI data for Wireshark
    outboundData = "SPI_OUT: " + String(spiDataOut, HEX).toUpperCase() + ", " +
                   "SPI_IN: " + String(spiDataIn, HEX).toUpperCase() + ", " +
                   "SPI_SS: " + (digitalRead(SPI_SS) == LOW ? "LOW" : "HIGH");

    // Send the formatted data over Serial
    Serial.println(outboundData);

    // Slow down the loop for readability
    delay(100);
}