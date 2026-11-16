void setup() {
  Serial.begin(115200);
  analogReadResolution(12);
}

void loop() {
  long sum = 0;
  for (int i = 0; i < 100; i++) sum += analogRead(4);
  Serial.print("middle: ");
  Serial.println(sum / 100);
  delay(500);
}