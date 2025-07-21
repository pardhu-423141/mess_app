import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cloudinary_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/meal_utils.dart';

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
  String? _uploadedImageUrl;
  DateTime _selectedDate = DateTime.now();
  User? user = FirebaseAuth.instance.currentUser;
  final picker = ImagePicker();
  int? selectedGender; // 1 = Boys, 0 = Girls
  String selectedMeal = '';

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() => _imageFile = file);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading image...')),
      );

      final imageUrl = await CloudinaryService.uploadImage(file);

      if (imageUrl != null) {
        setState(() => _uploadedImageUrl = imageUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully')),
        );
      } else {
        setState(() => _uploadedImageUrl = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload failed')),
        );
      }
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
                decoration: const InputDecoration(labelText: 'Max Orders Allowed'),
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
                      ? Image.file(_imageFile!, height: 80, width: 80, fit: BoxFit.cover)
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
                        label: const Text("Pick Image", style: TextStyle(fontSize: 14)),
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
                    label: const Text("Pick Date", style: TextStyle(fontSize: 14)),
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
                        const SnackBar(content: Text("Select meal type and hostel")),
                      );
                      return;
                    }

                    if (_uploadedImageUrl == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please upload an image")),
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

                    final paddedCount =
                        (matchingDocs.length + 1).toString().padLeft(2, '0');
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
                    final doc=await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
                    final info = doc.data();
                    if (info != null && info.containsKey('mess')) {
                      selectedGender = info['mess'];
                    }
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
                          'gender': selectedGender,
                          'status': status,
                          'imageUrl': _uploadedImageUrl, // ✅ Image URL saved
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

