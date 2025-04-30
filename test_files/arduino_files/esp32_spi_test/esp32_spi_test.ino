int counter = 0;

void setup() {
  pinMode(5, OUTPUT);  // Clock pin
  pinMode(6, OUTPUT);  // Data or other pin
}

void loop() {
  // CLOCK (Pin 5)
  digitalWrite(5, HIGH);
  delay(1);
  digitalWrite(5, LOW);
  delay(1);

  // Update counter
  counter++;

  // DATA (Pin 6)
  if (counter % 10 == 0) { 
    // Every 10 clock cycles, toggle pin 6
    static bool pin6State = LOW;
    pin6State = !pin6State;   // Toggle state
    digitalWrite(6, pin6State);
  }
}