# ESP32 Medicine Dispenser (prototype)

A Flutter tablet UI prototype for assigning medicines to slots, configuring daily/weekly schedules, tracking counts, sending USB-serial dispense commands, and recording confirmations locally.

> **Safety:** This is a hobby/prototyping example, not a medical device. Do not rely on it for medication adherence or connect it to a mechanism that can dispense medication unsupervised. Validate the entire mechanism, safeguards, power-loss behavior, firmware, and schedules with qualified people before any real-world use. The foreground timer is not a reliable background alarm; Android may suspend the app.

## Project contents

- `lib/main.dart` – app entry point and theme
- `lib/models/medication_slot.dart` – slot and recurrence model
- `lib/services/usb_serial_service.dart` – USB-OTG serial connection and command writer
- `lib/controllers/dispenser_controller.dart` – local persistence, schedule checks, alert/log state
- `lib/screens/home_screen.dart` – responsive tablet UI and slot editor

## Create a runnable Flutter platform project

This repository contains the Flutter app source. Generate Flutter's native Android/iOS scaffolding on your development laptop:

```bash
# Install Flutter and Android Studio/Android SDK first.
flutter create --platforms=android esp32_medicine_dispenser
cd esp32_medicine_dispenser
```

Copy this repository's `lib/` and `pubspec.yaml` into that generated folder (replace the generated `pubspec.yaml`), then:

```bash
flutter pub get
flutter analyze
flutter run
```

Use a physical Android tablet for USB host/OTG testing; an emulator cannot test a physical USB-serial adapter.

## Android USB host setup

In `android/app/src/main/AndroidManifest.xml`, add under `<manifest>`:

```xml
<uses-feature android:name="android.hardware.usb.host" android:required="false" />
```

`usb_serial` requests access to the attached USB device at runtime. USB host support, a data-capable OTG adapter, and a compatible USB-serial interface are required. Follow the current `usb_serial` package instructions if your device or plugin version requires additional native configuration. Do not add a generic receiver copied from unrelated examples without checking the package's current Android requirements.

## Alert sound (optional)

The app tries to load `assets/audio/medicine_alert.mp3`. Add a licensed alert sound at that path and declare it under `flutter: assets:` in `pubspec.yaml`, then run `flutter pub get`. If the file is absent, the app logs the audio failure; visual alert and confirmation UI still work.

## USB protocol

The app sends one newline-terminated command per dispense:

```text
DISPENSE|slot=2|qty=1\n
```

The ESP32 firmware must use the same baud rate (115200) and protocol. This app treats a successful serial write as a sent command, **not proof** that the mechanism dispensed medicine. Add a firmware acknowledgment and a physical sensor/verification strategy before relying on operation. Do not connect a motor or solenoid directly to an ESP32 GPIO; use a correctly rated driver and external supply.

## Schedule and logs

Schedules are checked while the app process is active and in the foreground. They are not guaranteed to fire if the app is closed, the tablet sleeps, or Android kills the process. Logs and slot settings are stored locally using SharedPreferences. “Taken” means the user confirmed it in the UI; it does not verify ingestion.
