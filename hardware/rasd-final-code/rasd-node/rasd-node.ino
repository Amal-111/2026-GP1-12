#include <DHT.h>

#define PIEZO_PIN 4
#define DHT_PIN   5
#define LORA_RX   18
#define LORA_TX   17

DHT dht(DHT_PIN, DHT22);

float temp = 0, hum = 0;
int maxVibration = 0;
unsigned long lastSend = 0;

void sendAT(String cmd) {
  Serial1.print(cmd + "\r\n");
  delay(300);
  while (Serial1.available()) Serial.write(Serial1.read());
}

void setup() {
  Serial.begin(115200);
  Serial1.begin(115200, SERIAL_8N1, LORA_RX, LORA_TX);
  analogReadResolution(12);
  dht.begin();
  delay(1000);
  sendAT("AT");
  sendAT("AT+BAND=868000000");
  sendAT("AT+PARAMETER=9,7,1,12");
  sendAT("AT+NETWORKID=18");
}

void loop() {
  // البيزو: نقرا 100 ملي ثانية ونحفظ أعلى اهتزاز
  int mn = 4095, mx = 0;
  unsigned long t = millis();
  while (millis() - t < 100) {
    int v = analogRead(PIEZO_PIN);
    if (v < mn) mn = v;
    if (v > mx) mx = v;
  }
  int vibration = mx - mn;
  if (vibration > maxVibration) maxVibration = vibration;

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