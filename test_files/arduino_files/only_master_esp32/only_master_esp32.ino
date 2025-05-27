#include <SPI.h>

#define BUTTON_PIN  9
#define CS_PIN      7

void setup() {
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(CS_PIN, OUTPUT);
  SPI.begin();
  digitalWrite(CS_PIN, HIGH);
}

const char* msg = "SPI TEST1234";

void loop() {

    digitalWrite(CS_PIN, LOW);
    SPI.beginTransaction(SPISettings(150000000, MSBFIRST, SPI_MODE0));
    
    for (size_t i = 0; i < strlen(msg); i++) {
      SPI.transfer(msg[i]);
    }

    SPI.endTransaction();
    digitalWrite(CS_PIN, HIGH);
    delay(2000);
  
}
