import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medication_slot.dart';
import '../services/usb_serial_service.dart';

class DispenserController extends ChangeNotifier with WidgetsBindingObserver {
  static const _slotsKey = 'dispenser_slots_v1';
  static const _logsKey = 'dispenser_logs_v1';

  final slots = <MedicationSlot>[];
  final logs = <String>[];
  final serial = UsbSerialService();
  final _audio = AudioPlayer();
  Timer? _timer;
  int selectedIndex = 0;
  int? activeSlotNumber;
  bool busy = false;
  bool get alertActive => activeSlotNumber != null;
  MedicationSlot? get selectedSlot => slots.isEmpty ? null : slots[selectedIndex];
  MedicationSlot? get activeSlot => slots.where((s) => s.number == activeSlotNumber).firstOrNull;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    serial.onMessage = (message) => _addLog('ESP32: $message');
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_slotsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        slots.addAll(list.map((item) => MedicationSlot.fromJson(Map<String, dynamic>.from(item as Map))));
      }
      logs.addAll(prefs.getStringList(_logsKey) ?? const []);
    } catch (_) {
      slots.clear();
      logs.clear();
    }
    if (slots.isEmpty) {
      slots.addAll(List.generate(8, (i) => MedicationSlot(number: i + 1)));
      await _saveSlots();
    }
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _checkSchedule());
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkSchedule();
  }

  void select(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  Future<void> saveSlot(MedicationSlot slot) async {
    final index = slots.indexWhere((item) => item.number == slot.number);
    if (index >= 0) slots[index] = slot;
    await _saveSlots();
    _addLog('Updated slot ${slot.number}.');
    notifyListeners();
  }

  Future<void> clearSlot(MedicationSlot slot) async {
    final index = slots.indexWhere((item) => item.number == slot.number);
    if (index < 0) return;
    slots[index] = MedicationSlot(number: slot.number);
    await _saveSlots();
    _addLog('Cleared slot ${slot.number}.');
    notifyListeners();
  }

  Future<String> connectUsb() async {
    final result = await serial.connect();
    notifyListeners();
    return result;
  }

  Future<void> dispense(MedicationSlot slot, {bool scheduled = false}) async {
    if (busy || !slot.assigned || slot.inventory < slot.quantity) {
      _addLog('Dispense blocked for slot ${slot.number}: check assignment/inventory.');
      return;
    }
    busy = true;
    notifyListeners();
    final sent = await serial.send('DISPENSE|slot=${slot.number}|qty=${slot.quantity}');
    if (!sent) {
      _addLog('Command not sent for slot ${slot.number}; USB is not connected.');
      busy = false;
      notifyListeners();
      return;
    }
    slot.inventory -= slot.quantity;
    slot.lastDispensedAt = DateTime.now();
    activeSlotNumber = slot.number;
    _addLog('${scheduled ? 'Scheduled' : 'Manual'} command sent for slot ${slot.number} (${slot.name}).');
    await _saveSlots();
    await _startAlert();
    busy = false;
    notifyListeners();
  }

  Future<void> confirmTaken() async {
    final number = activeSlotNumber;
    if (number == null) return;
    await _stopAlert();
    activeSlotNumber = null;
    _addLog('User confirmed slot $number as taken (not independently verified).');
    notifyListeners();
  }

  void _checkSchedule() {
    if (alertActive || busy) return;
    final now = DateTime.now();
    for (final slot in slots) {
      if (!slot.assigned || slot.time != _clock(now) || !_recursToday(slot, now)) continue;
      final last = slot.lastDispensedAt;
      final alreadyToday = last != null && last.year == now.year && last.month == now.month && last.day == now.day;
      if (!alreadyToday) {
        unawaited(dispense(slot, scheduled: true));
        break;
      }
    }
  }

  bool _recursToday(MedicationSlot slot, DateTime date) {
    switch (slot.recurrence) {
      case Recurrence.daily: return true;
      case Recurrence.weekdays: return date.weekday <= DateTime.friday;
      case Recurrence.selectedDays: return slot.weekdays.contains(date.weekday);
    }
  }

  String _clock(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> _startAlert() async {
    try {
      await _audio.setAsset('assets/audio/medicine_alert.mp3');
      await _audio.setLoopMode(LoopMode.one);
      await _audio.setVolume(1);
      unawaited(_audio.play());
    } catch (_) {
      _addLog('Alert audio unavailable; add assets/audio/medicine_alert.mp3.');
    }
    try { await ScreenBrightness().setApplicationScreenBrightness(1); } catch (_) {}
  }

  Future<void> _stopAlert() async {
    try { await _audio.stop(); } catch (_) {}
    try { await ScreenBrightness().resetApplicationScreenBrightness(); } catch (_) {}
  }

  void _addLog(String message) {
    logs.insert(0, '${DateTime.now().toLocal().toString().substring(0, 16)}  $message');
    if (logs.length > 100) logs.removeLast();
    unawaited(_saveLogs());
    notifyListeners();
  }

  Future<void> _saveSlots() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_slotsKey, jsonEncode(slots.map((slot) => slot.toJson()).toList()));
  }

  Future<void> _saveLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_logsKey, logs);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(serial.disconnect());
    unawaited(_audio.dispose());
    super.dispose();
  }
}
