import 'dart:io';
import 'package:flutter/cupertino.dart';
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
  File? _imageFile;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() != true ||
        _startTime == null ||
        _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select time.')),
      );
      return;
    }

    final now = DateTime.now();
    final dateStr = "${now.day.toString().padLeft(2, '0')}"
        "${now.month.toString().padLeft(2, '0')}"
        "${now.year}";

    final snapshot =
        await FirebaseFirestore.instance.collection('extra_menu').get();
    final count = snapshot.docs.length + 1;
    final docId = "$dateStr${count.toString().padLeft(2, '0')}";

    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    final endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    await FirebaseFirestore.instance.collection('extra_menu').doc(docId).set({
      'name': _nameController.text.trim(),
      'price': _priceController.text.trim(),
      'startTime': Timestamp.fromDate(startDateTime),
      'endTime': Timestamp.fromDate(endDateTime),
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menu item added successfully!')),
    );
    Navigator.pop(context);
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

  Future<void> _pickTime({required bool isStart}) async {
    int selectedHour = 12;
    int selectedMinute = 0;

    await showModalBottomSheet(
      context: context,
      builder: (_) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Select Time", style: TextStyle(fontSize: 16)),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 32,
                        scrollController:
                            FixedExtentScrollController(initialItem: 12),
                        onSelectedItemChanged: (index) {
                          selectedHour = index;
                        },
                        children:
                            List.generate(24, (i) => Text(i.toString().padLeft(2, '0'))),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 32,
                        scrollController:
                            FixedExtentScrollController(initialItem: 0),
                        onSelectedItemChanged: (index) {
                          selectedMinute = [0, 15, 30, 45][index];
                        },
                        children: const [
                          Text('00'),
                          Text('15'),
                          Text('30'),
                          Text('45'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    if (isStart) {
                      _startTime = TimeOfDay(hour: selectedHour, minute: selectedMinute);
                    } else {
                      _endTime = TimeOfDay(hour: selectedHour, minute: selectedMinute);
                    }
                  });
                },
                child: const Text("Set Time"),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String formatTime(TimeOfDay? time) {
      if (time == null) return "Not selected";
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return "$hour:$minute";
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add Extra Menu')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Item Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),

              // Price
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter price' : null,
              ),
              const SizedBox(height: 12),

              // Status Dropdown
              

              // Image Picker
              Row(
                children: [
                  _imageFile != null
                      ? Image.file(_imageFile!, height: 80, width: 80, fit: BoxFit.cover)
                      : const Text("No image selected"),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text("Pick Image"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date Picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Date: ${_selectedDate.day.toString().padLeft(2, '0')}-"
                    "${_selectedDate.month.toString().padLeft(2, '0')}-"
                    "${_selectedDate.year}",
                  ),
                  IconButton(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Start Time Picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Start Time: ${formatTime(_startTime)}"),
                  ElevatedButton(
                    onPressed: () => _pickTime(isStart: true),
                    child: const Text("Pick Start Time"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // End Time Picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("End Time: ${formatTime(_endTime)}"),
                  ElevatedButton(
                    onPressed: () => _pickTime(isStart: false),
                    child: const Text("Pick End Time"),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.save),
                label: const Text("Submit"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
