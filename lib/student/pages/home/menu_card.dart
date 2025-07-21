import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MenuItemCard extends StatelessWidget {
  final String itemName;
  final String itemActualName;
  final String itemPrice;
  final String? imageUrl;
  final int itemCount;
  final bool isActive;
  final bool isAvailableInStock;
  final bool canAddToCart;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final String description;
  final DateTime? bookingClosingTime;
  final double cardHeight;
  final double cardWidth;
  final bool isGeneralMenuItem;
  final double? rating;

  const MenuItemCard({
    required this.itemName,
    required this.itemActualName,
    required this.itemPrice,
    this.imageUrl,
    required this.itemCount,
    required this.isActive,
    required this.isAvailableInStock,
    required this.canAddToCart,
    required this.onAdd,
    required this.onRemove,
    required this.description,
    this.bookingClosingTime,
    required this.cardHeight, // Crucial for sizing
    required this.cardWidth,  // Crucial for sizing
    required this.isGeneralMenuItem,
    this.rating,
  });

  void _showDetailsPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          contentPadding: EdgeInsets.zero,
          titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 0),
          title: Text(
            isGeneralMenuItem ? itemActualName : itemName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(0),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).primaryColor,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 150,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.fastfood, size: 80, color: Colors.grey)),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Price: ₹$itemPrice",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      
                      const Text(
                        "Description:",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        description,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      if (bookingClosingTime != null)
                        Text(
                          "Booking Closes At: ${DateFormat('h:mm a').format(bookingClosingTime!)}",
                          style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic),
                        ),
                      const SizedBox(height: 20),
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define min/max font sizes to control scaling.
    const double minItemNameFontSize = 10.0;
    const double maxItemNameFontSize = 13.0;
    const double minDetailsFontSize = 7.0;
    const double maxDetailsFontSize = 9.0;
    const double minPriceFontSize = 9.0;
    const double maxPriceFontSize = 12.0;
    const double minAddButtonTextSize = 9.0;
    const double maxAddButtonTextSize = 12.0;
    const double minIconSize = 13.0;
    const double maxIconSize = 16.0;
    const double minCounterTextSize = 11.0;
    const double maxCounterTextSize = 13.0;

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showDetailsPopup(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section (takes 60% of the card's vertical space)
              Expanded(
                flex: 6,
                child: Stack(
                  children: [
                    // Background Image
                    Positioned.fill(
                      child: imageUrl != null && imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Theme.of(context).primaryColor,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                    child: Icon(Icons.fastfood, size: 50, color: Colors.grey)),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Center(
                                  child: Icon(Icons.fastfood, size: 50, color: Colors.grey)),
                            ),
                    ),

                    // Rating Badge (top-right corner)
                    if (rating != null && rating! > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                rating!.toStringAsFixed(1),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Text Content Section + Cart Controls (takes 40% of the card's vertical space)
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space between children
                    mainAxisSize: MainAxisSize.max, // Take all available space within Expanded
                    children: [
                      // Item Name
                      Text(
                        isGeneralMenuItem ? itemName : itemActualName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: cardWidth * 0.1 > maxItemNameFontSize
                              ? maxItemNameFontSize
                              : (cardWidth * 0.1 < minItemNameFontSize ? minItemNameFontSize : cardWidth * 0.1),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Item Price
                      Text(
                        "₹$itemPrice",
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: cardWidth * 0.08 > maxPriceFontSize
                              ? maxPriceFontSize
                              : (cardWidth * 0.08 < minPriceFontSize ? minPriceFontSize : cardWidth * 0.08),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),

                      
                      // Spacer to push cart controls to the bottom
                      const Spacer(),

                      // Cart Controls
                      _buildCartControls(
                        context,
                        itemCount,
                        isActive,
                        isAvailableInStock,
                        canAddToCart,
                        onAdd,
                        onRemove,
                        cardWidth,
                        minAddButtonTextSize,
                        maxAddButtonTextSize,
                        minIconSize,
                        maxIconSize,
                        minCounterTextSize,
                        maxCounterTextSize,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartControls(
    BuildContext context,
    int itemCount,
    bool isActive,
    bool isAvailableInStock,
    bool canAddToCart,
    VoidCallback onAdd,
    VoidCallback onRemove,
    double cardWidth,
    double minAddButtonTextSize,
    double maxAddButtonTextSize,
    double minIconSize,
    double maxIconSize,
    double minCounterTextSize,
    double maxCounterTextSize,
  ) {
    if (!isActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          isGeneralMenuItem ? 'Booking Closed' : 'Sold out',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: cardWidth * 0.08 > maxAddButtonTextSize
                ? maxAddButtonTextSize
                : (cardWidth * 0.08 < minAddButtonTextSize ? minAddButtonTextSize : cardWidth * 0.08),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (!isAvailableInStock && !isGeneralMenuItem) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.8),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          'Out of Stock',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: cardWidth * 0.08 > maxAddButtonTextSize
                ? maxAddButtonTextSize
                : (cardWidth * 0.08 < minAddButtonTextSize ? minAddButtonTextSize : cardWidth * 0.08),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (itemCount > 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionButton(
            icon: Icons.remove,
            onPressed: onRemove,
            iconSize: cardWidth * 0.09 > maxIconSize ? maxIconSize : (cardWidth * 0.09 < minIconSize ? minIconSize : cardWidth * 0.09),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              '$itemCount',
              style: TextStyle(
                fontSize: cardWidth * 0.1 > maxCounterTextSize
                    ? maxCounterTextSize
                    : (cardWidth * 0.1 < minCounterTextSize ? minCounterTextSize : cardWidth * 0.1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildActionButton(
            icon: Icons.add,
            onPressed: canAddToCart ? onAdd : null,
            iconSize: cardWidth * 0.09 > maxIconSize ? maxIconSize : (cardWidth * 0.09 < minIconSize ? minIconSize : cardWidth * 0.09),
          ),
        ],
      );
    } else {
      return SizedBox( // Use SizedBox here to ensure consistent height for the button
        width: double.infinity,
        height: cardWidth * 0.12, // Approximate height for the button to be consistent
        child: ElevatedButton(
          onPressed: canAddToCart ? onAdd : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canAddToCart ? Theme.of(context).primaryColor : Colors.grey,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            padding: EdgeInsets.zero, // Remove default padding to let content control size
          ),
          child: Text(
            'Add to Cart',
            style: TextStyle(
              fontSize: cardWidth * 0.08 > maxAddButtonTextSize
                  ? maxAddButtonTextSize
                  : (cardWidth * 0.08 < minAddButtonTextSize ? minAddButtonTextSize : cardWidth * 0.08),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required double iconSize,
  }) {
    // Ensure the button itself has a fixed size based on iconSize
    final double buttonSize = iconSize * 1.8; // A factor to make the circle larger than the icon
    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: FittedBox( // Use FittedBox to scale the IconButton if necessary
        child: IconButton(
          icon: Icon(icon, color: Colors.green),
          onPressed: onPressed,
          padding: EdgeInsets.zero, // Essential for tight spacing
          constraints: const BoxConstraints(), // Removes default minimum constraints
        ),
      ),
    );
  }
}