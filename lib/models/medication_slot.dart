enum Recurrence { daily, weekdays, selectedDays }

class MedicationSlot {
  MedicationSlot({
    required this.number,
    this.name = '',
    this.time = '08:00',
    this.quantity = 1,
    this.inventory = 0,
    this.recurrence = Recurrence.daily,
    List<int>? weekdays,
    this.lastDispensedAt,
  }) : weekdays = weekdays ?? <int>[];

  final int number;
  String name;
  String time;
  int quantity;
  int inventory;
  Recurrence recurrence;
  List<int> weekdays; // DateTime weekday values: Monday=1 ... Sunday=7.
  DateTime? lastDispensedAt;

  bool get assigned => name.trim().isNotEmpty;
  bool get lowInventory => assigned && inventory <= 2;

  Map<String, Object?> toJson() => {
        'number': number,
        'name': name,
        'time': time,
        'quantity': quantity,
        'inventory': inventory,
        'recurrence': recurrence.name,
        'weekdays': weekdays,
        'lastDispensedAt': lastDispensedAt?.toIso8601String(),
      };

  factory MedicationSlot.fromJson(Map<String, dynamic> json) {
    final recurrenceName = json['recurrence'] as String?;
    return MedicationSlot(
      number: json['number'] as int? ?? 1,
      name: json['name'] as String? ?? '',
      time: json['time'] as String? ?? '08:00',
      quantity: json['quantity'] as int? ?? 1,
      inventory: json['inventory'] as int? ?? 0,
      recurrence: Recurrence.values.firstWhere(
        (value) => value.name == recurrenceName,
        orElse: () => Recurrence.daily,
      ),
      weekdays: List<int>.from(json['weekdays'] as List? ?? const <int>[]),
      lastDispensedAt: DateTime.tryParse(json['lastDispensedAt'] as String? ?? ''),
    );
  }
}
