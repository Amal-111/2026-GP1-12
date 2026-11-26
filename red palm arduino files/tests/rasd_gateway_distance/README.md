# Rasd – Gateway Distance Test

This version of the gateway code is used to test the LoRa range between the sensor node and the gateway. It receives the messages sent by the sensor node and prints each one with its signal quality, so the team can find the maximum distance at which messages still arrive.

Wi-Fi and backend communication are disabled in this version, so the gateway only listens and does not miss any messages during the test.

## Hardware

| Device | Model |
|---|---|
| Gateway (runs this code) | Heltec WiFi LoRa 32 V4 |
| Sensor node (sends the messages) | ESP32-S3 with REYAX RYLR998, running the sensor node code |


## LoRa settings

These settings match the sensor node, so the two devices can communicate.

| Setting | Value |
|---|---|
| Frequency | 868 MHz |
| Bandwidth | 125 kHz |
| Spreading factor | 9 |
| Coding rate | 4/5 |
| Preamble length | 12 |

## Requirements

- Arduino IDE 2.x
- Heltec ESP32 Series board package (3.3.8), added through this board manager URL:
  `https://github.com/Heltec-Aaron-Lee/WiFi_Kit_series/releases/download/3.0.0/package_heltec_esp32_index.json`
- Heltec ESP32 Dev-Boards library (2.1.6)

## Upload

1. Open `rasd_gateway_distance.ino` in the Arduino IDE.
2. Select **Tools → Board → WiFi LoRa 32(V4)** and choose the correct port.
3. Click **Upload**. If the upload fails, hold **PRG**, press and release **RST**, then release **PRG** and try again.
4. Open the **Serial Monitor** at **115200 baud**.

## Output

Each received message is printed on one line:

```
#12  time: 65 s  data: 250,23.2,60.3  RSSI: -42 dBm  SNR: 9 dB
```

| Field | Meaning |
|---|---|
| `#12` | Number of messages received since the gateway started |
| `time` | Seconds since the gateway started |
| `data` | Readings sent by the node: vibration, temperature, humidity |
| `RSSI` | Signal strength in dBm (closer to 0 means a stronger signal) |
| `SNR` | Signal clarity compared with the background noise, in dB. Negative values are normal in LoRa; with these settings, messages start to fail at about −12 dB |

## How to run the test

1. Power the sensor node next to the gateway and check that a new line appears every 5 seconds.
2. Move the sensor node away step by step (for example 10, 25, 50, 100 m and further).
3. At each distance, wait one minute and record the RSSI, the SNR, and the number of messages received. The node sends 12 messages per minute, so 12 received means no messages were lost.
4. The last distance with reliable reception is the LoRa range at that location.
