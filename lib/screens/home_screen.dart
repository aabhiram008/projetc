import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/dispenser_controller.dart';
import '../models/medication_slot.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DispenserController>();
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Dispenser', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text(controller.serial.status)),
          ),
          IconButton(
            tooltip: 'Connect USB device',
            onPressed: () async {
              final result = await context.read<DispenserController>().connectUsb();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
            },
            icon: Icon(controller.serial.connected ? Icons.usb : Icons.usb_off),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: controller.slots.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(flex: 3, child: _slotGrid(context, controller)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _details(context, controller)),
                    ])
                  : Column(children: [
                      Expanded(flex: 3, child: _slotGrid(context, controller)),
                      const SizedBox(height: 12),
                      Expanded(flex: 2, child: _details(context, controller)),
                    ]),
            ),
      floatingActionButton: controller.selectedSlot?.assigned == true
          ? FloatingActionButton.extended(
              onPressed: controller.busy ? null : () => context.read<DispenserController>().dispense(controller.selectedSlot!),
              icon: const Icon(Icons.medication),
              label: const Text('Test dispense'),
            )
          : null,
    );
  }

  Widget _slotGrid(BuildContext context, DispenserController controller) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Medicine slots', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(child: GridView.builder(
              itemCount: controller.slots.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.45,
              ),
              itemBuilder: (context, index) {
                final slot = controller.slots[index];
                final selected = controller.selectedIndex == index;
                final color = !slot.assigned ? Colors.blueGrey : slot.lowInventory ? Colors.deepOrange : Colors.teal;
                return Semantics(
                  button: true,
                  label: 'Slot ${slot.number}, ${slot.assigned ? slot.name : 'empty'}${slot.lowInventory ? ', low inventory' : ''}',
                  child: Card(
                    color: selected ? color.withValues(alpha: .14) : Colors.white,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: selected ? color : Colors.black12, width: selected ? 2 : 1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => controller.select(index),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [Expanded(child: Text('Slot ${slot.number}', style: const TextStyle(fontWeight: FontWeight.bold))), Icon(slot.assigned ? Icons.medication : Icons.add_box_outlined, color: color)]),
                          Text(slot.assigned ? slot.name : 'Empty — tap to assign', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          Text(slot.assigned ? '${slot.time}  •  ${slot.inventory} left  •  ${slot.lowInventory ? 'LOW STOCK' : 'Assigned'}' : 'Empty', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            )),
          ]),
        ),
      );

  Widget _details(BuildContext context, DispenserController controller) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Expanded(child: Text('Slot details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))), TextButton.icon(onPressed: controller.selectedSlot == null ? null : () => _editSlot(context, controller.selectedSlot!), icon: const Icon(Icons.edit), label: const Text('Edit'))]),
            if (controller.selectedSlot case final slot?) ...[
              Text(slot.assigned ? slot.name : 'Slot ${slot.number} is empty', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(slot.assigned ? 'Dose ${slot.quantity} • ${slot.time} • ${_recurrenceText(slot)}' : 'Assign a medicine and schedule to get started.'),
              const SizedBox(height: 8),
              Text('Inventory: ${slot.inventory}${slot.lowInventory ? '  •  Low stock' : ''}'),
              const Divider(height: 24),
            ],
            Text('Recent activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Expanded(child: controller.logs.isEmpty
                ? const Center(child: Text('No activity yet'))
                : ListView.builder(itemCount: controller.logs.length.clamp(0, 30), itemBuilder: (_, i) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(controller.logs[i], style: const TextStyle(fontSize: 12))))),
          ]),
        ),
      );

  String _recurrenceText(MedicationSlot slot) => switch (slot.recurrence) {
        Recurrence.daily => 'Daily',
        Recurrence.weekdays => 'Weekdays',
        Recurrence.selectedDays => 'Selected days',
      };

  Future<void> _editSlot(BuildContext context, MedicationSlot source) async {
    final name = TextEditingController(text: source.name);
    final quantity = TextEditingController(text: source.quantity.toString());
    final inventory = TextEditingController(text: source.inventory.toString());
    var time = source.time;
    var recurrence = source.recurrence;
    final weekdays = [...source.weekdays];
    final saved = await showDialog<MedicationSlot>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: Text('Edit slot ${source.number}'),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Medicine name')),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Dose quantity'))), const SizedBox(width: 12), Expanded(child: TextField(controller: inventory, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Inventory count')))]),
          const SizedBox(height: 12),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('Dispense time'), subtitle: Text(time), trailing: const Icon(Icons.schedule), onTap: () async { final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(time.split(':')[0]), minute: int.parse(time.split(':')[1]))); if (t != null) setState(() => time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'); }),
          DropdownButtonFormField<Recurrence>(value: recurrence, decoration: const InputDecoration(labelText: 'Recurrence'), items: const [DropdownMenuItem(value: Recurrence.daily, child: Text('Daily')), DropdownMenuItem(value: Recurrence.weekdays, child: Text('Weekdays')), DropdownMenuItem(value: Recurrence.selectedDays, child: Text('Choose days'))], onChanged: (v) { if (v != null) setState(() => recurrence = v); }),
          if (recurrence == Recurrence.selectedDays) Wrap(spacing: 4, children: List.generate(7, (i) { final day = i + 1; const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S']; return FilterChip(label: Text(labels[i]), selected: weekdays.contains(day), onSelected: (yes) => setState(() { yes ? weekdays.add(day) : weekdays.remove(day); })); })),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { final qty = int.tryParse(quantity.text); final stock = int.tryParse(inventory.text); if (name.text.trim().isEmpty || qty == null || qty < 1 || stock == null || stock < 0 || (recurrence == Recurrence.selectedDays && weekdays.isEmpty)) return; Navigator.pop(dialogContext, MedicationSlot(number: source.number, name: name.text.trim(), quantity: qty, inventory: stock, time: time, recurrence: recurrence, weekdays: weekdays, lastDispensedAt: source.lastDispensedAt)); }, child: const Text('Save')),
          if (source.assigned) TextButton(onPressed: () => Navigator.pop(dialogContext, MedicationSlot(number: -source.number)), child: const Text('Clear slot')),
        ],
      )),
    );
    name.dispose(); quantity.dispose(); inventory.dispose();
    if (saved == null || !context.mounted) return;
    if (saved.number < 0) {
      await context.read<DispenserController>().clearSlot(source);
    } else {
      await context.read<DispenserController>().saveSlot(saved);
    }
  }
}
