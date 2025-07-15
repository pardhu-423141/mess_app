import 'package:flutter/material.dart';

class CartItemTile extends StatelessWidget {
  final Map<String, dynamic> itemData;
  final int quantity;
  final VoidCallback onRemove;
  final VoidCallback onAdd;
  final VoidCallback onDelete;

  const CartItemTile({
    super.key,
    required this.itemData,
    required this.quantity,
    required this.onRemove,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final price = itemData['price'] is String
        ? double.tryParse(itemData['price']) ?? 0.0
        : (itemData['price'] as num).toDouble();
    final total = price * quantity;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: itemData['imageUrl'] != null
                  ? Image.network(itemData['imageUrl'], width: 60, height: 60, fit: BoxFit.cover)
                  : const Icon(Icons.fastfood, size: 60),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemData['name'] ?? itemData['description'] ?? 'Unnamed Item',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('₹$price each'),
                  if (itemData['rating'] != null)
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        Text(' ${itemData['rating']}'),
                      ],
                    ),
                  Text('Total: ₹${total.toStringAsFixed(2)}'),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete, color: Colors.red)),
                Row(
                  children: [
                    IconButton(onPressed: onRemove, icon: const Icon(Icons.remove)),
                    Text(quantity.toString()),
                    IconButton(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
