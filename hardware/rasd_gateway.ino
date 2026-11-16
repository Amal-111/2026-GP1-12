
#include "LoRaWan_APP.h"
#include "Arduino.h"
#include <WiFi.h>
#include <HTTPClient.h>

// ======== Fill these in ========
const char* WIFI_SSID     = "********";          // 2.4 GHz WiFi
const char* WIFI_PASSWORD = "********";
const char* SERVER_URL    = "http://192.168.101.29:5001/rasd-6a036/us-central1/receiveSensorData";
const char* GATEWAY_KEY   = "********";
const char* DEVICE_ID     = "********";               // the sensor ID paired in the app
// ===============================

#define RF_FREQUENCY            868000000
#define TX_OUTPUT_POWER         14
#define LORA_BANDWIDTH          0
#define LORA_SPREADING_FACTOR   9
#define LORA_CODINGRATE         1
#define LORA_PREAMBLE_LENGTH    12
#define LORA_SYMBOL_TIMEOUT     0
#define LORA_FIX_LENGTH_PAYLOAD_ON false
#define LORA_IQ_INVERSION_ON    false
#define BUFFER_SIZE             100

static RadioEvents_t RadioEvents;
bool lora_idle = true;

// Latest reading, filled by OnRxDone and sent from loop()
volatile bool newReading = false;
int   rxVibration = 0;
float rxTemp = 0, rxHum = 0;
int16_t rxRssi = 0;

void OnRxDone(uint8_t *payload, uint16_t size, int16_t rssi, int8_t snr);

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
    delay(500);
    Serial.print(".");
  }
  Serial.println(WiFi.status() == WL_CONNECTED
                 ? "\nWiFi connected, IP: " + WiFi.localIP().toString()
                 : "\nWiFi failed");
}

void sendToServer() {
  connectWiFi();
  if (WiFi.status() != WL_CONNECTED) return;

  String json = "{\"deviceId\":\"" + String(DEVICE_ID) + "\"," +
                "\"temperature\":" + String(rxTemp, 1) + "," +
                "\"humidity\":" + String(rxHum, 1) + "," +
                "\"result\":\"Healthy\"," +              // placeholder until the AI model is added
                "\"vibrationData\":[" + String(rxVibration) + "]}";

  HTTPClient http;
  http.begin(SERVER_URL);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-rasd-gateway-key", GATEWAY_KEY);
  int code = http.POST(json);
  Serial.println("Sent: " + json);
  Serial.println("Server response: " + String(code) + " " + http.getString());
  http.end();
}

void setup() {
  Serial.begin(115200);
  Mcu.begin(HELTEC_BOARD, SLOW_CLK_TPYE);   // keep this line exactly as in the Heltec example

  connectWiFi();

  RadioEvents.RxDone = OnRxDone;
  Radio.Init(&RadioEvents);
  Radio.SetChannel(RF_FREQUENCY);
  Radio.SetRxConfig(MODEM_LORA, LORA_BANDWIDTH, LORA_SPREADING_FACTOR,
                    LORA_CODINGRATE, 0, LORA_PREAMBLE_LENGTH,
                    LORA_SYMBOL_TIMEOUT, LORA_FIX_LENGTH_PAYLOAD_ON,
                    0, true, 0, 0, LORA_IQ_INVERSION_ON, true);
}

void loop() {
  if (lora_idle) {
    lora_idle = false;
    Radio.Rx(0);
  }
  Radio.IrqProcess();

  if (newReading) {
    newReading = false;
    sendToServer();
  }
}

void OnRxDone(uint8_t *payload, uint16_t size, int16_t rssi, int8_t snr) {
  Radio.Sleep();

  // Skip the 5-byte header added by the RYLR998
  String data = "";
  for (int i = 5; i < size; i++) data += (char)payload[i];

  int c1 = data.indexOf(',');
  int c2 = data.indexOf(',', c1 + 1);
  if (c1 > 0 && c2 > c1) {
    rxVibration = data.substring(0, c1).toInt();
    rxTemp      = data.substring(c1 + 1, c2).toFloat();
    rxHum       = data.substring(c2 + 1).toFloat();
    rxRssi      = rssi;
    Serial.println("\nLoRa received: " + data + "  RSSI: " + String(rssi));
    newReading = true;
  }
  lora_idle = true;
}
