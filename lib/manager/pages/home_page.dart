import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../add_extra_menu.dart';
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  String formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('extra_menu')
          .orderBy('startTime')
          .snapshots(),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final docs = snapshot.data?.docs ?? [];

        final activeMenus = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final start = (data['startTime'] as Timestamp?)?.toDate();
          final end = (data['endTime'] as Timestamp?)?.toDate();
          final status = data['status'] ?? '';
          return start != null &&
              end != null &&
              now.isAfter(start) &&
              now.isBefore(end) &&
              status != 'inactive';
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Add Extra Menu"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddExtraMenuPage()),
                      );
                    },

                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text("Update General Menu"),
                    onPressed: () => Navigator.pushNamed(context, '/update_general_menu'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (activeMenus.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: Center(child: Text("No active menus for current time.")),
                ),
              if (activeMenus.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: activeMenus.length,
                    itemBuilder: (context, index) {
                      final doc = activeMenus[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final docId = doc.id;
                      final name = data['name'] ?? 'Unnamed';
                      final price = data['price'] ?? 'N/A';
                      final description = data['description'] ?? 'No description';
                      final bookingsLeft = data['availableOrders'] ?? 'N/A';
                      final imageUrl = data['imageUrl'] ?? '';
                      final startTime = (data['startTime'] as Timestamp?)?.toDate();
                      final endTime = (data['endTime'] as Timestamp?)?.toDate();

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ListTile(
                                contentPadding: const EdgeInsets.only(right: 90),
                                leading: imageUrl.isNotEmpty
                                    ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                                    : const Icon(Icons.fastfood),
                                title: Text(name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Price: ₹$price"),
                                    Text("Remaining Bookings: $bookingsLeft"),
                                    Text("Description: $description"),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        if (startTime != null && endTime != null)
                                          Text(
                                            "Time: ${formatTime(startTime)} - ${formatTime(endTime)}",
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                        const SizedBox(width: 10),
                                        OutlinedButton(
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text("Confirm Deactivation"),
                                                content: const Text("Are you sure you want to deactivate this item?"),
                                                actions: [
                                                  TextButton(
                                                    child: const Text("Cancel"),
                                                    onPressed: () => Navigator.pop(context, false),
                                                  ),
                                                  ElevatedButton(
                                                    child: const Text("Confirm"),
                                                    onPressed: () => Navigator.pop(context, true),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await FirebaseFirestore.instance
                                                  .collection('extra_menu')
                                                  .doc(docId)
                                                  .update({'status': 'inactive'});
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.orange,
                                            side: const BorderSide(color: Colors.orange),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          ),
                                          child: const Text("Deactivate"),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => EditDialog(docId: docId, data: data),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class EditDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditDialog({super.key, required this.docId, required this.data});

  @override
  State<EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<EditDialog> {
  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController descriptionController;
  late TextEditingController bookingsController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.data['name']);
    priceController = TextEditingController(text: widget.data['price'].toString());
    descriptionController = TextEditingController(text: widget.data['description'] ?? '');
    bookingsController = TextEditingController(text: widget.data['availableOrders'].toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Menu Item"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Item Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bookingsController,
              decoration: const InputDecoration(labelText: 'Remaining Bookings'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Cancel"),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: const Text("Save"),
          onPressed: () async {
            await FirebaseFirestore.instance
                .collection('extra_menu')
                .doc(widget.docId)
                .update({
              'name': nameController.text,
              'price': double.tryParse(priceController.text) ?? 0,
              'description': descriptionController.text,
              'availableOrders': int.tryParse(bookingsController.text) ?? 0,
            });

            if (mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
