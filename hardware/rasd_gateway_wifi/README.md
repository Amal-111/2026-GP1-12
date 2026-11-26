# Rasd – Gateway

The gateway receives the readings sent by the sensor node over LoRa and forwards them over Wi-Fi to the Rasd backend, where they are stored and displayed in the mobile application.

The code is based on Heltec's LoRaReceiver example and was modified for this project.

## Hardware

| Device | Model |
|---|---|
| Gateway (runs this code) | Heltec WiFi LoRa 32 V4 |
| Sensor node (sends the readings) | ESP32-S3 with REYAX RYLR998, running the sensor node code |

> 

## How it works

1. **Receive:** the gateway listens for LoRa messages from the sensor node. It removes the 5-byte header added by the RYLR998 and splits the message into vibration, temperature and humidity.
2. **Connect:** the gateway connects to the configured Wi-Fi network.
3. **Send:** each reading is sent to the backend as a JSON message using an HTTP POST request:
   ```json
   {"deviceId":"D001","temperature":23.2,"humidity":60.3,"result":"Healthy","vibrationData":[250]}
   ```
   The gateway key is added to the request header (`x-rasd-gateway-key`) so the backend accepts data only from the project's gateway.

> The `result` field is currently a fixed placeholder (`"Healthy"`) until the detection model is added in Release 2.

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
- The Rasd backend running on Firebase, with the sensor paired to a palm in the mobile app

## Configuration

Before uploading, edit these values at the top of `rasd_gateway_wifi.ino`:

| Setting | Value |
|---|---|
| `WIFI_SSID` | Wi-Fi network name (2.4 GHz) |
| `WIFI_PASSWORD` | Wi-Fi password |
| `SERVER_URL` | Replace the IP address with the IPv4 address of the computer running the backend |
| `GATEWAY_KEY` | Must match `RASD_GATEWAY_KEY` in `backend/functions/.secret.local` |
| `DEVICE_ID` | Sensor ID paired with the palm in the app (for example `D001`) |

The computer running the backend and the gateway must be on the same Wi-Fi network.

## Upload and run

1. Open `rasd_gateway_wifi.ino` in the Arduino IDE.
2. Select **Tools → Board → WiFi LoRa 32(V4)** and choose the correct port.
3. Click **Upload**. If the upload fails, hold **PRG**, press and release **RST**, then release **PRG** and try again.
4. Open the **Serial Monitor** at **115200 baud**. For each reading, the output should end with:
   ```
   Server response: 200 {"success":true}
   ```

## Server responses

| Code | Meaning |
|---|---|
| `200` | Reading accepted and stored |
| `401` | Wrong gateway key |
| `409` | The sensor is not paired with a palm in the app |
| Negative value (for example `-1` or `-11`) | No response from the server: check that the backend is running, the IP address is correct, and the firewall allows the connection |
