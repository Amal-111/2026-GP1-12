// Rasd - Sensor Node (ESP32-S3)
// Piezo vibration sensor (via MCP602 amplifier) + DHT22 temperature & humidity
#include <DHT.h>

#define PIEZO_PIN   4      // MCP602 output (pin 1) -> GPIO4 (ADC1)
#define DHT_PIN     5      // DHT22 data -> GPIO5
#define DHT_TYPE    DHT22
#define WINDOW_MS   100    // vibration sampling window
#define DHT_PERIOD  2000   // DHT22 minimum reading interval

DHT dht(DHT_PIN, DHT_TYPE);

int   middle = 0, vibration = 0;
float temperature = 0, humidity = 0;
unsigned long lastDht = 0;

void setupSensors() {
  Serial.begin(115200);
  analogReadResolution(12);          // ADC range 0..4095
  dht.begin();
}

void readVibration() {
  int mn = 4095, mx = 0;
  long sum = 0;
  int n = 0;
  unsigned long start = millis();
  while (millis() - start < WINDOW_MS) {
    int v = analogRead(PIEZO_PIN);
    if (v < mn) mn = v;
    if (v > mx) mx = v;
    sum += v;
    n++;
  }
  middle    = sum / n;               // signal bias level (~Vref)
  vibration = mx - mn;               // peak-to-peak amplitude
}

void readTemperatureHumidity() {
  if (millis() - lastDht < DHT_PERIOD) return;
  lastDht = millis();
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  if (!isnan(h) && !isnan(t)) {      // discard invalid readings
    humidity = h;
    temperature = t;
  }
}

void printReadings() {
  Serial.print("middle:");       Serial.print(middle);
  Serial.print(" vibration:");   Serial.print(vibration);
  Serial.print(" temp:");        Serial.print(temperature);
  Serial.print(" hum:");         Serial.println(humidity);
}

void setup() {
  setupSensors();
}

void loop() {
  readVibration();
  readTemperatureHumidity();
  printReadings();
}
