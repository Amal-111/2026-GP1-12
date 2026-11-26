# Sensor and Board Checks

This folder contains small test programs used before building the full sensor node. Each program checks one component on its own, to make sure it is connected correctly and working. These programs are not part of the final system.

## Checks

| Folder | Board | What it checks | Expected result |
|---|---|---|---|
| `esp-check` | ESP32-S3 | The board can be programmed and communicate with the computer | `ESP32 OK` is printed every second |
| `only-DHT-check` | ESP32-S3 | The DHT22 sensor on GPIO 5 | Realistic temperature (°C) and humidity (%) values that change when the sensor is held by hand |
| `middle-check` | ESP32-S3 | The piezo sensor through the MCP602 amplifier on GPIO 4 | `middle` stays near 2000 at rest, and `vibration` increases when the sensor is tapped |
| `LoraRylr998-check` | ESP32-S3 | The RYLR998 LoRa module (TXD → GPIO 18, RXD → GPIO 17) | The module replies `+OK` to AT commands |
| `heltec-check` | Heltec WiFi LoRa 32 V4 | The Heltec board and its LoRa radio | Messages sent by the sensor node appear in the Serial Monitor |

## How to use

1. Connect only the component you want to test (see the wiring in the main hardware README).
2. Open the check program in the Arduino IDE, select the correct board and port, and upload it.
3. Open the Serial Monitor at 115200 baud and compare the output with the expected result.

> ⚠️ Connect the LoRa antennas before powering the RYLR998 or the Heltec board.
