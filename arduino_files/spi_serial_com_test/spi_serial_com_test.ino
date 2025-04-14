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

    digitalWrite(SP_SS, LOW); // Select slave
    spiDataIn = SPI.transfer(spiDataOut); // Send & receive data
    digitalWrite(SPI_SS, HIGH); // Deselect slave

    // Output the SPI data in a format Wireshark can read
    Serial.print("SPI_OUT: ");
    Serial.print(spiDataOut, HEX);
    Serial.print(" SPI_IN: ");
    Serial.println(spiDataIn, HEX);
    Serial.println(" SPI_SS: ")
    Serial.println(digitalRead(SPI_SS) == LOW ? "LOW" : "HIGH");

    delay(100); // Slow down the loop for readability
}
I