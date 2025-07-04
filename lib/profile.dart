import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:image_picker/image_picker.dart'; // Import Image Picker
import 'dart:io'; // Required for File

// Import the CloudinaryService from its new location
import 'services/cloudinary_service.dart';

// Assuming LoginPage is in '../../login_page.dart'
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Image Picker instance
  final ImagePicker _picker = ImagePicker();

  // User data from Firestore
  Map<String, dynamic>? _userData;
  bool _isLoadingUserData = true;
  bool _isUploadingImage = false;

  // State for editing user name
  bool _isEditingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Fetches user details from the 'users' collection in Firestore.
  /// The user document ID is assumed to be the Firebase Auth UID.
  Future<void> _fetchUserData() async {
    setState(() {
      _isLoadingUserData = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>?;
            _nameController.text = _userData?['name'] ?? user.displayName ?? 'Manager';
          });
        } else {
          // Handle case where user document doesn't exist (e.g., new user)
          debugPrint('User document does not exist for UID: ${user.uid}');
          setState(() {
            _userData = {
              'name': user.displayName ?? 'Manager',
              'email': user.email ?? '',
              'role': 'User', // Default role if not found
              'profile': null, // Default profile picture
            };
            _nameController.text = _userData?['name'] ?? 'Manager';
          });
        }
      } catch (e) {
        debugPrint('Error fetching user data: $e');
        // Fallback to Firebase Auth details if Firestore fetch fails
        setState(() {
          _userData = {
            'name': user.displayName ?? 'Manager',
            'email': user.email ?? '',
            'role': 'User', // Default role on error
            'profile': null, // Default profile picture on error
          };
          _nameController.text = _userData?['name'] ?? 'Manager';
        });
        _showSnackBar('Error fetching user data. Please try again.');
      }
    }
    setState(() {
      _isLoadingUserData = false;
    });
  }

  /// Handles user sign out from Google and Firebase Auth.
  Future<void> _signOut(BuildContext context) async {
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Error signing out: $e');
      _showSnackBar('Error signing out. Please try again.');
    }
  }

  /// Allows the user to pick an image and uploads it as their profile photo using Cloudinary.
  Future<void> _pickAndUploadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('You must be logged in to upload a profile picture.');
      return;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _isUploadingImage = true;
        });

        File imageFile = File(pickedFile.path);
        // Use the CloudinaryService to upload the image
        String? imageUrl = await CloudinaryService.uploadImage(imageFile, folder: 'user_profiles');

        if (imageUrl != null) {
          // Update the 'profile' field in the user's Firestore document
          await _firestore.collection('users').doc(user.uid).set(
            {'profile': imageUrl},
            SetOptions(merge: true), // Use merge to only update the 'profile' field
          );
          _showSnackBar('Profile picture updated successfully!');
          // Refresh user data to reflect the new profile picture
          _fetchUserData();
        } else {
          _showSnackBar('Failed to upload image to Cloudinary. Check Cloudinary credentials and network.');
        }
      }
    } catch (e) {
      debugPrint('Error picking or uploading image: $e');
      _showSnackBar('An error occurred while updating profile picture. Check your network connection.');
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  /// Updates the user's name in Firestore.
  Future<void> _updateUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('You must be logged in to update your name.');
      return;
    }

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      _showSnackBar('Name cannot be empty.');
      return;
    }

    if (newName == (_userData?['name'] ?? user.displayName ?? 'Manager')) {
      setState(() {
        _isEditingName = false; // No change, just exit edit mode
      });
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).set(
        {'name': newName},
        SetOptions(merge: true), // Merge to only update the 'name' field
      );
      _showSnackBar('Name updated successfully!');
      setState(() {
        _userData?['name'] = newName; // Update local state immediately
        _isEditingName = false;
      });
    } catch (e) {
      debugPrint('Error updating user name: $e');
      _showSnackBar('Error updating name. Please try again.');
    }
  }

  /// Displays the profile image in a full-screen dialog.
  void _showProfileImageFullScreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: GestureDetector(
            onTap: () => Navigator.pop(context), // Dismiss dialog on tap
            child: Stack(
              children: [
                Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 100,
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the profile photo widget (circular avatar with image or initial).
  Widget _buildProfilePhoto(String? imageUrl, String? name) {
    final String initial = (name != null && name.isNotEmpty) ? name[0].toUpperCase() : '?';
    return Stack(
      children: [
        // Main profile image (tappable to view full screen)
        InkWell(
          onTap: imageUrl != null && imageUrl.isNotEmpty
              ? () => _showProfileImageFullScreen(imageUrl)
              : null, // Only tap if there's an image
          borderRadius: BorderRadius.circular(80), // Match avatar radius for ripple effect
          child: CircleAvatar(
            radius: 80, // Increased size
            backgroundColor: Colors.deepPurple.shade100, // Light purple background
            backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                ? NetworkImage(imageUrl) as ImageProvider
                : null,
            child: imageUrl == null || imageUrl.isEmpty
                ? Text(
                    initial,
                    style: TextStyle(fontSize: 50, color: Colors.deepPurple), // Darker purple text
                  )
                : null,
          ),
        ),
        if (_isUploadingImage)
          const Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        // Camera icon (tappable to upload image)
        Positioned(
          bottom: 0,
          right: 0,
          child: InkWell(
            onTap: _pickAndUploadProfileImage,
            borderRadius: BorderRadius.circular(25), // Match avatar radius
            child: CircleAvatar(
              radius: 25, // Slightly larger camera icon
              backgroundColor: Colors.deepPurple, // Deep purple camera icon background
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  /// Shows a SnackBar message at the bottom of the screen.
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String userName = _userData?['name'] ?? user?.displayName ?? 'Manager';
    final String userEmail = _userData?['email'] ?? user?.email ?? '';
    final String userRole = _userData?['role'] ?? 'User'; // Default role
    final String? profileImageUrl = _userData?['profile'];

    return Scaffold( // Use Scaffold for a proper app bar and body structure
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.white, // AppBar color changed to white
        foregroundColor: Colors.black, // Text and icon color changed to black
        elevation: 1, // Subtle shadow for AppBar
      ),
      body: LayoutBuilder( // Use LayoutBuilder to get the available height
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox( // Constrain the Column's height to at least the available viewport height
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight( // Ensure the column takes only the height it needs, but allows centering
                child: Column( // Inner Column for profile content
                  mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                  crossAxisAlignment: CrossAxisAlignment.center, // Center content horizontally
                  children: [
                    _isLoadingUserData
                        ? const CircularProgressIndicator()
                        : Column( // This column holds the actual profile details
                            children: [
                              _buildProfilePhoto(profileImageUrl, userName),
                              const SizedBox(height: 20),
                              // User Name with Edit Option
                              Padding( // Added padding specifically around the name/email/role section
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: _isEditingName
                                          ? TextFormField(
                                              controller: _nameController,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple), // Text color
                                              decoration: InputDecoration(
                                                border: const OutlineInputBorder(),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                focusedBorder: OutlineInputBorder( // Focused border color
                                                  borderSide: BorderSide(color: Colors.deepPurple.shade700, width: 2.0),
                                                ),
                                              ),
                                              onFieldSubmitted: (_) => _updateUserName(), // Save on submit
                                            )
                                          : Text(
                                              userName,
                                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple), // Text color
                                              textAlign: TextAlign.center,
                                            ),
                                    ),
                                    IconButton(
                                      icon: Icon(_isEditingName ? Icons.check : Icons.edit, color: Colors.deepPurple), // Icon color
                                      onPressed: () {
                                        if (_isEditingName) {
                                          _updateUserName();
                                        } else {
                                          setState(() {
                                            _isEditingName = true;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                userEmail,
                                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Role: $userRole',
                                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 30),
                              ElevatedButton.icon(
                                onPressed: () => _signOut(context),
                                icon: const Icon(Icons.logout),
                                label: const Text("Sign Out"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepOrange, // Warm, inviting color for sign out
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                  textStyle: const TextStyle(fontSize: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 3,
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
