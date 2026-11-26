/* Rasd - Sensor Node (ESP32-S3 N16R8)
 * Reads the piezoelectric vibration sensor (through the MCP602 amplifier)
 * and the DHT22 temperature/humidity sensor, then sends one LoRa message
 * every 5 seconds through the REYAX RYLR998 module.
 *
 * Message format: "vibration,temperature,humidity"
 * vibration = highest peak-to-peak value measured since the previous message.
 *
 * Board: ESP32S3 Dev Module (USB CDC On Boot: Enabled)
 * Library: DHT sensor library (Adafruit) 1.4.7
 */
#include <DHT.h>

#define PIEZO_PIN 4    // MCP602 output (pin 1) -> GPIO 4 (ADC1)
#define DHT_PIN   5    // DHT22 data -> GPIO 5
#define LORA_RX   18   // RYLR998 TXD -> GPIO 18
#define LORA_TX   17   // RYLR998 RXD -> GPIO 17

DHT dht(DHT_PIN, DHT22);

float temp = 0, hum = 0;
int maxVibration = 0;
unsigned long lastSend = 0;

// Send an AT command to the RYLR998 and print its reply
void sendAT(String cmd) {
  Serial1.print(cmd + "\r\n");
  delay(300);
  while (Serial1.available()) Serial.write(Serial1.read());
}

void setup() {
  Serial.begin(115200);
  Serial1.begin(115200, SERIAL_8N1, LORA_RX, LORA_TX);
  analogReadResolution(12);   // ADC range 0..4095
  dht.begin();
  delay(1000);

  sendAT("AT");
  sendAT("AT+BAND=868000000");       // 868 MHz
  sendAT("AT+PARAMETER=9,7,1,12");   // SF9, BW 125 kHz, CR 4/5, preamble 12
  sendAT("AT+NETWORKID=18");
}

void loop() {
  // Read the piezo for 100 ms and measure the peak-to-peak amplitude
  int mn = 4095, mx = 0;
  unsigned long t = millis();
  while (millis() - t < 100) {
    int v = analogRead(PIEZO_PIN);
    if (v < mn) mn = v;
    if (v > mx) mx = v;
  }
  int vibration = mx - mn;
  if (vibration > maxVibration) maxVibration = vibration;

  // Every 5 seconds: read the DHT22 and send one LoRa message
  if (millis() - lastSend >= 5000) {
    lastSend = millis();
    float h = dht.readHumidity();
    float c = dht.readTemperature();
    if (!isnan(h) && !isnan(c)) { hum = h; temp = c; }

    String msg = String(maxVibration) + "," + String(temp, 1) + "," + String(hum, 1);
    sendAT("AT+SEND=0," + String(msg.length()) + "," + msg);
    Serial.println("Sent: " + msg);
    maxVibration = 0;
  }
}
