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
    String period = 'AM';

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
                    // Hour picker (1 to 12)
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 32,
                        scrollController: FixedExtentScrollController(
                          initialItem: 11,
                        ),
                        onSelectedItemChanged: (index) {
                          selectedHour = index + 1; // 1 to 12
                        },
                        children: List.generate(12, (i) => Text("${i + 1}")),
                      ),
                    ),
                    // Minute picker (0 to 59)
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 32,
                        scrollController: FixedExtentScrollController(
                          initialItem: 0,
                        ),
                        onSelectedItemChanged: (index) {
                          selectedMinute = index;
                        },
                        children: List.generate(
                          60,
                          (i) => Text(i.toString().padLeft(2, '0')),
                        ),
                      ),
                    ),
                    // AM/PM picker
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 32,
                        onSelectedItemChanged: (index) {
                          period = index == 0 ? 'AM' : 'PM';
                        },
                        children: const [Text('AM'), Text('PM')],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);

                  // Convert to 24-hour format
                  int hour = selectedHour % 12;
                  if (period == 'PM') hour += 12;

                  setState(() {
                    final pickedTime = TimeOfDay(
                      hour: hour,
                      minute: selectedMinute,
                    );
                    if (isStart) {
                      _startTime = pickedTime;
                    } else {
                      _endTime = pickedTime;
                    }
                  });
                },
                child: const Text("Set Time"),
              ),
            ],
          ),
        );
      },
    );
  }

  String formatTime(TimeOfDay? time) {
    if (time == null) return "Not selected";

    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return "$hour:$minute $period";
  }

  // Dropdown for Hostel selection (Boys/Girls)
  int _selectedHostel = 1; // default Boys = 1

  @override
  Widget build(BuildContext context) {
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

              // Hostel Dropdown
              DropdownButtonFormField<int>(
                value: _selectedHostel,
                decoration: const InputDecoration(labelText: 'Hostel'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Boys')),
                  DropdownMenuItem(value: 0, child: Text('Girls')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedHostel = val;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              // Image Picker
              Row(
                children: [
                  _imageFile != null
                      ? Image.file(
                          _imageFile!,
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                        )
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
                onPressed: () async {
                  if (_formKey.currentState?.validate() != true ||
                      _startTime == null ||
                      _endTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please fill all fields and select time.',
                        ),
                      ),
                    );
                    return;
                  }

                  final now = DateTime.now();
                  final dateStr =
                      "${now.day.toString().padLeft(2, '0')}"
                      "${now.month.toString().padLeft(2, '0')}"
                      "${now.year}";

                  final snapshot = await FirebaseFirestore.instance
                      .collection('extra_menu')
                      .get();
                  final count = snapshot.docs.length + 1;

                  final docId =
                      "$dateStr${count.toString().padLeft(2, '0')}${_selectedHostel}";

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
                  int rating = 0;

                  await FirebaseFirestore.instance
                      .collection('extra_menu')
                      .doc(docId)
                      .set({
                        'name': _nameController.text.trim(),
                        'price': _priceController.text.trim(),
                        'startTime': Timestamp.fromDate(startDateTime),
                        'endTime': Timestamp.fromDate(endDateTime),
                        'createdAt': FieldValue.serverTimestamp(),
                        'hostel': _selectedHostel,
                        'rating':rating,
                      });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Menu item added successfully!'),
                    ),
                  );
                  Navigator.pop(context);
                },
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
