# Rasd – IoT Hardware

This folder contains the Rasd IoT code. A sensor node attached to the palm trunk measures vibrations, temperature and humidity, and sends the readings over LoRa to a gateway. The gateway forwards them over Wi-Fi to the Rasd backend, where they are stored and displayed in the mobile application.

## Folders

| Folder | Contents |
|---|---|
| `sensor_node` | Final code of the sensor node: reads the sensors and sends the readings over LoRa |
| `rasd_gateway_wifi` | Final code of the gateway: receives the readings over LoRa and sends them to the backend over Wi-Fi |
| `tests` | Test programs used during development |

Each folder has its own README with the wiring, settings and steps to upload and run its code.

### Tests

| Folder | Contents |
|---|---|
| `tests/sensor_check` | Small programs that check each component on its own: the ESP32-S3, the DHT22, the piezo with the amplifier, the RYLR998 and the Heltec board |
| `tests/sensor_test_usb` | First test of the sensors together, with the readings sent to the computer over USB |
| `tests/rasd_gateway_distance` | Gateway version used to test the LoRa range between the sensor node and the gateway |

## Hardware

| Part | Model |
|---|---|
| Microcontroller | ESP32-S3 N16R8 development board |
| Vibration sensor | Piezoelectric disc with an MCP602 amplifier circuit |
| Temperature and humidity sensor | DHT22 (AM2302) |
| LoRa module (sensor node) | REYAX RYLR998 |
| Gateway | Heltec WiFi LoRa 32 V4 |

## Requirements

- Arduino IDE 2.x
- **Sensor node:** ESP32 board package by Espressif (3.3.12) and the DHT sensor library by Adafruit (1.4.7)
- **Gateway:** Heltec ESP32 Series board package (3.3.8) and the Heltec ESP32 Dev-Boards library (2.1.6)

## Running the full system

1. Start the Rasd backend.
2. In the mobile app, add a farm and a palm, and connect the sensor to the palm.
3. Fill in the Wi-Fi name, password, server address and gateway key in the gateway code, then upload it to the Heltec board. See `rasd_gateway_wifi/README.md`.
4. Upload the sensor node code to the ESP32-S3. See `sensor_node/README.md`.
5. Power on the sensor node and the gateway.
6. Check that the system is working:
   - The gateway's Serial Monitor shows `Server response: 200` for each reading.
   - The palm's temperature, humidity and sensor status appear in the app.

The gateway and the computer running the backend must be on the same Wi-Fi network.

## Notes

- The node sends one reading every 5 seconds.
- The gateway currently sends a fixed placeholder result (`"Healthy"`) until the detection model is added in Release 2.
