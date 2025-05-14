#include <SPI.h>

#define BUTTON_PIN  9
#define CS_PIN      7

void setup() {
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(CS_PIN, OUTPUT);
  SPI.begin();
  digitalWrite(CS_PIN, HIGH);
}

const char* msg = "Hej med dig!";

void loop() {

  if (digitalRead(BUTTON_PIN) == LOW) {
    digitalWrite(CS_PIN, LOW);
    SPI.beginTransaction(SPISettings(50000000, MSBFIRST, SPI_MODE0));
    
    for (size_t i = 0; i < strlen(msg); i++) {
      SPI.transfer(msg[i]);
    }

    SPI.endTransaction();
    digitalWrite(CS_PIN, HIGH);
    delay(500);
  }
}