import 'package:flutter/material.dart';
import 'updateUserInFirestore.dart';
import 'student_dashboard.dart';

class MessSwitcherButton extends StatefulWidget {
  const MessSwitcherButton({super.key});

  @override
  State<MessSwitcherButton> createState() => _MessSwitcherButtonState();
}

class _MessSwitcherButtonState extends State<MessSwitcherButton> {
  int _selectedGender = 1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserGender();
  }

  Future<void> _loadUserGender() async {
    final gender = await MessService.getUserMessGender();
    setState(() {
      _selectedGender = gender;
      _loading = false;
    });
  }

  Future<void> _switchMess() async {
    final newGender = _selectedGender == 0 ? 1 : 0;
    setState(() {
      _selectedGender = newGender;
    });

    try {
      await MessService.updateUserMessGender(newGender);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mess updated to ${MessService.getGenderString(newGender)}!'),
            backgroundColor: Colors.green,
          ),
        );
        // ✅ Navigate to HomePage after short delay to let user see the snackbar
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentDashboard()), // Replace with your HomePage widget
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update mess: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CircularProgressIndicator();
    }

    return ElevatedButton.icon(
      icon: const Icon(Icons.swap_horiz, color: Color(0xFF4A148C)), // Soft purple
      label: Text(
        "Switch to ${MessService.getGenderString(_selectedGender == 0 ? 1 : 0)} Mess",
        style: const TextStyle(color: Color(0xFF4A148C)),
      ),
      onPressed: _switchMess,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEDE7F6), // Light purple tone
        foregroundColor: const Color(0xFF4A148C), // Dark purple
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0, // Flat look
      ),
    );

  }
}
