#define LORA_RX 18   
#define LORA_TX 17 
void setup() {
  Serial.begin(115200);
  Serial1.begin(115200, SERIAL_8N1, LORA_RX, LORA_TX);
  delay(1000);
  Serial.println("Type AT commands:");
}

void loop() {
  if (Serial.available())  Serial1.write(Serial.read());
  if (Serial1.available()) Serial.write(Serial1.read());
}