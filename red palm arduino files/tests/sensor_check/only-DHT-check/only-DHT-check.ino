#include <DHT.h>
DHT dht(5, DHT22);

void setup() {
  Serial.begin(115200);
  dht.begin();
}

void loop() {
  delay(2000);
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  if (isnan(h) || isnan(t)) {
    Serial.println("Read failed - check wiring");
  } else {
    Serial.print("Temp: "); Serial.print(t); Serial.print(" C   ");
    Serial.print("Humidity: "); Serial.print(h); Serial.println(" %");
  }
}