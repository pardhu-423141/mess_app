import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateGeneralMenuPage extends StatefulWidget {
  const UpdateGeneralMenuPage({super.key});

  @override
  State<UpdateGeneralMenuPage> createState() => _UpdateGeneralMenuPageState();
}

class _UpdateGeneralMenuPageState extends State<UpdateGeneralMenuPage> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();

  String _selectedDay = 'Monday';
  String _selectedMeal = 'Breakfast';
  String _selectedHostel = 'Boys';

  final Map<String, String> dayMap = {
    "Monday": "1",
    "Tuesday": "2",
    "Wednesday": "3",
    "Thursday": "4",
    "Friday": "5",
    "Saturday": "6",
    "Sunday": "7",
  };

  final Map<String, String> mealMap = {
    "Breakfast": "1",
    "Lunch": "2",
    "Snacks": "3",
    "Dinner": "4",
  };

  final Map<String, String> hostelMap = {
  "Boys": "1",
  "Girls": "0",
};


  static const String defaultFoodImage =
      'https://cdn-icons-png.flaticon.com/512/1046/1046784.png';

Future<void> _submitData() async {
  final String description = _descriptionController.text.trim();
  final String priceText = _priceController.text.trim();
  String imageUrl = _imageUrlController.text.trim();

  if (description.isEmpty || priceText.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please fill all fields")),
    );
    return;
  }

  // Updated: generate ID based on day + meal + hostel
  final String id = "${dayMap[_selectedDay]}${mealMap[_selectedMeal]}${hostelMap[_selectedHostel]}";
  final double price = double.tryParse(priceText) ?? 0;
  final String hostel = hostelMap[_selectedHostel]!;

  // Validate image URL or use default
  if (!Uri.parse(imageUrl).isAbsolute || !imageUrl.startsWith("http")) {
    imageUrl = defaultFoodImage;
  }

  await FirebaseFirestore.instance.collection('general_menu').doc(id).set({
    'ID': id,
    'description': description,
    'hostel': hostel,
    'imageUrl': imageUrl,
    'price': price,
    'rating': 0,
    'status' : 'active',
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Menu added successfully!")),
  );

  _descriptionController.clear();
  _priceController.clear();
  _imageUrlController.clear();

  setState(() {
    _selectedDay = 'Monday';
    _selectedMeal = 'Breakfast';
    _selectedHostel = 'Boys';
  });
}


  @override
  Widget build(BuildContext context) {
    final imagePreviewUrl = _imageUrlController.text.trim().isEmpty
        ? defaultFoodImage
        : _imageUrlController.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Update General Menu')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedDay,
                decoration: const InputDecoration(labelText: "Select Day"),
                items: dayMap.keys
                    .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedDay = val!),
              ),
              DropdownButtonFormField<String>(
                value: _selectedMeal,
                decoration: const InputDecoration(labelText: "Select Meal Time"),
                items: mealMap.keys
                    .map((meal) => DropdownMenuItem(value: meal, child: Text(meal)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedMeal = val!),
              ),
              DropdownButtonFormField<String>(
                value: _selectedHostel,
                decoration: const InputDecoration(labelText: "Select Hostel"),
                items: hostelMap.keys
                    .map((hostel) => DropdownMenuItem(value: hostel, child: Text(hostel)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedHostel = val!),
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                decoration: InputDecoration(
                  labelText: 'Enter Image URL',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.preview),
                    onPressed: () {
                      final url = _imageUrlController.text.trim();
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Image Preview"),
                          content: Image.network(
                            url.isEmpty ? defaultFoodImage : url,
                            height: 200,
                            errorBuilder: (context, error, stackTrace) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.network(defaultFoodImage, height: 200),
                                  const SizedBox(height: 8),
                                  const Text('Invalid URL. Showing default image.'),
                                ],
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                onChanged: (val) {
                  setState(() {}); 
                },
              ),
              const SizedBox(height: 16),
              Text(
                "Image Preview:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imagePreviewUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.network(
                      defaultFoodImage,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _submitData,
                  child: const Text("Submit Menu"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
