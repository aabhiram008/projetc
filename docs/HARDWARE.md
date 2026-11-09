# Hardware and firmware integration notes

## USB serial

Use a data-capable USB OTG connection from the Android tablet to an ESP32 USB serial interface. The app expects 115200 baud, 8 data bits, no parity, one stop bit. Its dispense command is newline terminated:

```text
DISPENSE|slot=1|qty=1
```

During initial testing, connect only the ESP32 and observe serial output. Do not connect a medicine mechanism until serial parsing and a safe, supervised bench test are complete. Add command validation, limits, timeout behavior, an acknowledgment protocol, and independent physical safeguards in firmware.

## Driver and power

Never power a motor, solenoid, or relay coil directly from an ESP32 GPIO. Use a properly rated motor/solenoid driver or relay module and a separate supply rated for the load. Follow the driver manufacturer's wiring diagram, add inductive-load suppression where required, and keep wiring insulated and secured. Verify that ESP32 and driver logic grounds are connected only as required by the selected isolated/non-isolated interface. Check component voltage/current ratings and fail-safe behavior before powering the mechanism.

GPIO 25 was used as an example in earlier discussion; the Flutter application does not configure GPIOs. Select a safe pin for your specific ESP32 board and driver, and ensure the pin's boot behavior cannot unexpectedly activate the mechanism.

## Verification

A serial `write()` does not prove a dose was physically dispensed, and a UI confirmation does not prove it was taken. Prefer a request/acknowledgment transaction plus a physical sensor and a fault state. Test disconnection, reboot, duplicate commands, empty inventory, motor stall, and power interruption with a non-medication test load.
