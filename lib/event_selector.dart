// lib/event_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_picker_plus/flutter_picker_plus.dart';

class EventSelector extends StatelessWidget {
  const EventSelector({super.key});

  void _showDateTimePicker(BuildContext context) {
    Picker(
      adapter: DateTimePickerAdapter(
        type: PickerDateTimeType.kYMDHM,
        value: DateTime.now(),
        minValue: DateTime(1950),
        maxValue: DateTime(2050),
      ),
      title: const Text('Select Date & Time'),
      onConfirm: (Picker picker, List<int> value) {
        final dateTime = (picker.adapter as DateTimePickerAdapter).value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected: $dateTime')),
        );
      },
    ).showModal(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Selector')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _showDateTimePicker(context),
          child: const Text('Add Event'),
        ),
      ),
    );
  }
}
