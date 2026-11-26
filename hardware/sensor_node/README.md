# Rasd – Sensor Node

The sensor node is attached to the palm trunk. It measures vibrations inside the trunk and the temperature and humidity around the tree, and sends the readings to the gateway over LoRa every 5 seconds.

## Hardware

| Component | Model |
|---|---|
| Microcontroller | ESP32-S3 N16R8 development board |
| Vibration sensor | Piezoelectric disc with an MCP602 amplifier circuit |
| Temperature and humidity sensor | DHT22 (AM2302) |
| LoRa module | REYAX RYLR998 |

## Wiring

All components are powered from the **3.3 V** and **GND** pins of the ESP32-S3.

| Component pin | ESP32-S3 pin |
|---|---|
| MCP602 output (pin 1) | GPIO 4 |
| DHT22 data | GPIO 5 |
| RYLR998 TXD | GPIO 18 (RX) |
| RYLR998 RXD | GPIO 17 (TX) |


## How it works

1. **Vibration:** the piezo signal is read continuously in 100 ms windows, and the peak-to-peak value (highest minus lowest reading) is calculated. The node keeps the highest value until the next message, so short vibrations are not missed. The value is a raw ADC number (0–4095).
2. **Temperature and humidity:** the DHT22 is read every 5 seconds. If a reading fails, the last valid value is used.
3. **Sending:** every 5 seconds the node sends one LoRa message in the format:
   ```
   vibration,temperature,humidity
   ```
   Example: `250,23.2,60.3`

## LoRa settings

The gateway uses the same settings, so the two devices can communicate.

| Setting | Value |
|---|---|
| Frequency | 868 MHz |
| Bandwidth | 125 kHz |
| Spreading factor | 9 |
| Coding rate | 4/5 |
| Preamble length | 12 |
| Network ID | 18 |

## Requirements

- Arduino IDE 2.x
- ESP32 board package by Espressif (3.3.12)
- DHT sensor library by Adafruit (1.4.7)

## Upload and run

1. Open `sensor_node.ino` in the Arduino IDE.
2. Select **Tools → Board → ESP32S3 Dev Module**, set **USB CDC On Boot → Enabled**, and choose the correct port.
3. Click **Upload**.
4. Open the **Serial Monitor** at **115200 baud**. A line such as `Sent: 250,23.2,60.3` should appear every 5 seconds.

After uploading, the code is stored on the board, so the node starts sending as soon as it is powered (from a laptop, a power bank, or any USB-C power source).
