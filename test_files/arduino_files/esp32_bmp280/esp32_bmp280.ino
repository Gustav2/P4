#include <SPI.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BMP280.h>

// Define SPI pins (optional if using hardware SPI pins)
// CS pin for BMP280
#define BMP_CS 10
int BUTTON_PIN=17;

// Create BMP280 object using SPI
Adafruit_BMP280 bmp(BMP_CS);

void setup() {
  Serial.begin(115200);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  while (!Serial);  // Wait for serial monitor

  if (!bmp.begin(BMP_CS)) {
    Serial.println(F("Could not find a valid BMP280 sensor, check wiring!"));
    while (1);
  }

  // Optionally set sensor settings
  bmp.setSampling(Adafruit_BMP280::MODE_NORMAL,     /* Operating Mode. */
                  Adafruit_BMP280::SAMPLING_X2,     /* Temp. oversampling */
                  Adafruit_BMP280::SAMPLING_X16,    /* Pressure oversampling */
                  Adafruit_BMP280::FILTER_X16,      /* Filtering. */
                  Adafruit_BMP280::STANDBY_MS_500); /* Standby time. */
}

void loop() {
  if (digitalRead(BUTTON_PIN) == LOW) {
    Serial.print(F("Temperature = "));
    Serial.print(bmp.readTemperature());
    Serial.println(" *C");

    Serial.print(F("Pressure = "));
    Serial.print(bmp.readPressure() / 100.0F); // Convert Pa to hPa
    Serial.println(" hPa");

    delay(1000);
  }
}