#include <DHT.h>

#define PIEZO_PIN 4
#define DHT_PIN   5
DHT dht(DHT_PIN, DHT22);

float temp = 0, hum = 0;
unsigned long lastDht = 0;

void setup() {
  Serial.begin(115200);
  analogReadResolution(12);
  dht.begin();
}

void loop() {
  int mn = 4095, mx = 0;
  long sum = 0;
  int n = 0;
  unsigned long t = millis();
  while (millis() - t < 100) {
    int v = analogRead(PIEZO_PIN);
    if (v < mn) mn = v;
    if (v > mx) mx = v;
    sum += v;
    n++;
  }
  int middle = sum / n;
  int vibration = mx - mn;

  if (millis() - lastDht >= 2000) {
    lastDht = millis();
    float h = dht.readHumidity();
    float c = dht.readTemperature();
    if (!isnan(h) && !isnan(c)) {
      hum = h;
      temp = c;
    }
  }
  Serial.print("middle:");    Serial.print(middle);
  Serial.print(" vibration:"); Serial.print(vibration);
  Serial.print(" temp:");      Serial.print(temp);
  Serial.print(" hum:");       Serial.println(hum);
}