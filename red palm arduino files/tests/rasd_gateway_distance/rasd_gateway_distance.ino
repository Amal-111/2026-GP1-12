/* Rasd Gateway - DISTANCE TEST version (Heltec WiFi LoRa 32 V4)
 * Receives LoRa readings from the sensor node and prints them with RSSI and SNR.
 * Wi-Fi and backend sending are disabled so no messages are missed during the test.
 */
#include "LoRaWan_APP.h"
#include "Arduino.h"

#define RF_FREQUENCY            868000000
#define TX_OUTPUT_POWER         14
#define LORA_BANDWIDTH          0
#define LORA_SPREADING_FACTOR   9
#define LORA_CODINGRATE         1
#define LORA_PREAMBLE_LENGTH    12
#define LORA_SYMBOL_TIMEOUT     0
#define LORA_FIX_LENGTH_PAYLOAD_ON false
#define LORA_IQ_INVERSION_ON    false

static RadioEvents_t RadioEvents;
bool lora_idle = true;
int msgCount = 0;   // number of messages received since start/reset

void OnRxDone(uint8_t *payload, uint16_t size, int16_t rssi, int8_t snr);

void setup() {
  Serial.begin(115200);
  Mcu.begin(HELTEC_BOARD, SLOW_CLK_TPYE);   // keep this line exactly as in the Heltec example

  RadioEvents.RxDone = OnRxDone;
  Radio.Init(&RadioEvents);
  Radio.SetChannel(RF_FREQUENCY);
  Radio.SetRxConfig(MODEM_LORA, LORA_BANDWIDTH, LORA_SPREADING_FACTOR,
                    LORA_CODINGRATE, 0, LORA_PREAMBLE_LENGTH,
                    LORA_SYMBOL_TIMEOUT, LORA_FIX_LENGTH_PAYLOAD_ON,
                    0, true, 0, 0, LORA_IQ_INVERSION_ON, true);
  Serial.println("Distance test started - waiting for LoRa messages...");
}

void loop() {
  if (lora_idle) {
    lora_idle = false;
    Radio.Rx(0);
  }
  Radio.IrqProcess();
}

void OnRxDone(uint8_t *payload, uint16_t size, int16_t rssi, int8_t snr) {
  Radio.Sleep();

  // Skip the 5-byte header added by the RYLR998
  String data = "";
  for (int i = 5; i < size; i++) data += (char)payload[i];

  msgCount++;
  Serial.println("#" + String(msgCount) +
                 "  time: " + String(millis() / 1000) + " s" +
                 "  data: " + data +
                 "  RSSI: " + String(rssi) + " dBm" +
                 "  SNR: " + String(snr) + " dB");
  lora_idle = true;
}