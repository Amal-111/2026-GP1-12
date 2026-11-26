# Rasd – Sensor Test over USB

This was the first test of the sensor node, before LoRa was added. It reads the piezoelectric vibration sensor and the DHT22 together, and sends the readings to the computer over the USB cable, where they can be checked in the Serial Monitor and the Serial Plotter.

## Hardware

| Component | Model |
|---|---|
| Microcontroller | ESP32-S3 N16R8 development board |
| Vibration sensor | Piezoelectric disc with an MCP602 amplifier circuit |
| Temperature and humidity sensor | DHT22 (AM2302) |

## Wiring

All components are powered from the **3.3 V** and **GND** pins of the ESP32-S3.

| Component pin | Connected to |
|---|---|
| Piezoelectric disc | MCP602 input (pin 3), through a 10 kΩ resistor |
| MCP602 output (pin 1) | ESP32-S3 GPIO 4 |
| DHT22 data | ESP32-S3 GPIO 5 |

The piezo is not connected to the ESP32-S3 directly: its signal first passes through the MCP602 amplifier circuit, which centers it at 1.65 V and amplifies it about 11 times.

## How it works

The program is divided into four functions:

| Function | What it does |
|---|---|
| `setupSensors()` | Runs once at start-up: opens the serial connection, sets the ADC to 12-bit (0–4095) and starts the DHT22 |
| `readVibration()` | Reads the piezo for 100 ms and calculates `middle` (the average reading) and `vibration` (highest minus lowest reading) |
| `readTemperatureHumidity()` | Reads the DHT22 every 2 seconds, the fastest rate the sensor allows, and ignores failed readings |
| `printReadings()` | Sends the four values to the computer |

## Output

```
middle:... vibration:... temp:... hum:...
```

| Value | Meaning |
|---|---|
| `middle` | Average level of the piezo signal. It should stay near 2000, which shows the signal is centered correctly |
| `vibration` | Strength of the vibration in the last 100 ms. It increases when the sensor is tapped |
| `temp` | Air temperature in °C |
| `hum` | Relative humidity in % |

## Requirements

- Arduino IDE 2.x
- ESP32 board package by Espressif (3.3.12)
- DHT sensor library by Adafruit (1.4.7)

## Upload and run

1. Open `sensor_test_usb.ino` in the Arduino IDE.
2. Select **Tools → Board → ESP32S3 Dev Module**, set **USB CDC On Boot → Enabled**, and choose the correct port.
3. Click **Upload**.
4. Open the **Serial Monitor** or the **Serial Plotter** at **115200 baud**.
