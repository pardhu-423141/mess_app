import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddExtraMenuPage extends StatefulWidget {
  const AddExtraMenuPage({super.key});

  @override
  State<AddExtraMenuPage> createState() => _AddExtraMenuPageState();
}

class _AddExtraMenuPageState extends State<AddExtraMenuPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _orderLimitController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _imageFile;
  DateTime _selectedDate = DateTime.now();

  final picker = ImagePicker();
  int? selectedGender; // 1 = Boys, 0 = Girls
  String selectedMeal = '';

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealCodes = getMealCodes();
    
    return Scaffold(
      appBar: AppBar(title: const Text('Add Extra Menu')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter price' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _orderLimitController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Max Orders Allowed'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter order limit' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter description' : null,
              ),
              const SizedBox(height: 16),
              const Text("Hostel", style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text("Boys"),
                    selected: selectedGender == 1,
                    onSelected: (_) => setState(() => selectedGender = 1),
                  ),
                  ChoiceChip(
                    label: const Text("Girls"),
                    selected: selectedGender == 0,
                    onSelected: (_) => setState(() => selectedGender = 0),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text("Meal Type", style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: mealCodes.keys.map((meal) {
                  return ChoiceChip(
                    label: Text(meal),
                    selected: selectedMeal == meal,
                    onSelected: (_) => setState(() => selectedMeal = meal),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _imageFile != null
                      ? Image.file(_imageFile!,
                          height: 80, width: 80, fit: BoxFit.cover)
                      : Container(
                          height: 80,
                          width: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 30),
                        ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image, size: 18),
                        label:
                            const Text("Pick Image", style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Date: ${_selectedDate.day.toString().padLeft(2, '0')}-"
                      "${_selectedDate.month.toString().padLeft(2, '0')}-"
                      "${_selectedDate.year}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label:
                        const Text("Pick Date", style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_formKey.currentState?.validate() != true) return;
                    if (selectedMeal.isEmpty || selectedGender == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Select meal type and hostel"),
                        ),
                      );
                      return;
                    }

                    final dateStr = "${_selectedDate.day.toString().padLeft(2, '0')}"
                        "${_selectedDate.month.toString().padLeft(2, '0')}"
                        "${_selectedDate.year}";
                    final docPrefix = "$dateStr";

                    final allDocs = await FirebaseFirestore.instance
                        .collection('extra_menu')
                        .get();

                    final matchingDocs = allDocs.docs
                        .where((doc) => doc.id.startsWith(docPrefix))
                        .toList();

                    final paddedCount = (matchingDocs.length + 1).toString().padLeft(2, '0');
                    final docId = "$docPrefix$paddedCount";

                    final timeRange = getMealTimeRange(selectedMeal);
                    final startTime = DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                      timeRange.start.hour,
                      timeRange.start.minute,
                    );
                    final endTime = DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                      timeRange.end.hour,
                      timeRange.end.minute,
                    );

                    final now = DateTime.now();
                    final status = now.isAfter(startTime) && now.isBefore(endTime)
                        ? 'active'
                        : 'inactive';

                    await FirebaseFirestore.instance
                        .collection('extra_menu')
                        .doc(docId)
                        .set({
                          'name': _nameController.text.trim(),
                          'price': _priceController.text.trim(),
                          'description': _descriptionController.text.trim(),
                          'startTime': Timestamp.fromDate(startTime),
                          'endTime': Timestamp.fromDate(endTime),
                          'availableOrders': int.parse(_orderLimitController.text.trim()),
                          'rating': 0,
                          'mealType': selectedMeal,
                          'gender' : selectedGender,
                          'status': status,
                        });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Menu item added successfully!')),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save),
                  label: const Text("Submit"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;
  TimeOfDayRange({required this.start, required this.end});
}

/// Reusable meal code mappings
Map<String, int> getMealCodes() {
  return {
    'Breakfast': 1,
    'Lunch': 2,
    'Snacks': 3,
    'Dinner': 4,
  };
}

/// Reusable meal time ranges
Map<String, TimeOfDayRange> getMealTimings() {
  return {
    'Breakfast': TimeOfDayRange(
      start: const TimeOfDay(hour: 5, minute: 0),
      end: const TimeOfDay(hour: 10, minute: 0),
    ),
    'Lunch': TimeOfDayRange(
      start: const TimeOfDay(hour: 10, minute: 30),
      end: const TimeOfDay(hour: 15, minute: 30),
    ),
    'Snacks': TimeOfDayRange(
      start: const TimeOfDay(hour: 15, minute: 30),
      end: const TimeOfDay(hour: 17, minute: 45),
    ),
    'Dinner': TimeOfDayRange(
      start: const TimeOfDay(hour: 18, minute: 15),
      end: const TimeOfDay(hour: 22, minute: 00),
    ),
  };
}

/// Get specific time range from meal type
TimeOfDayRange getMealTimeRange(String meal) {
  return getMealTimings()[meal]!;
}
