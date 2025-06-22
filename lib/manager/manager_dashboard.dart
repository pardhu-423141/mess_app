import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../login_page.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  int _selectedIndex = 0;

  Future<void> _signOut(BuildContext context) async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Widget _buildHomePage(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('extra_menu')
          .orderBy('startTime')
          .snapshots(),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final docs = snapshot.data?.docs ?? [];

        // Filter by current time in [start, end] and status not "booking closed"
        final activeMenus = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final start = (data['startTime'] as Timestamp?)?.toDate();
          final end = (data['endTime'] as Timestamp?)?.toDate();
          final status = data['status'] ?? '';

          return start != null &&
              end != null &&
              now.isAfter(start) &&
              now.isBefore(end) &&
              status != 'booking closed';
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Action Buttons
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Add Extra Menu"),
                    onPressed: () => Navigator.pushNamed(context, '/add_extra_menu'),
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
                  child: Center(
                    child: Text(
                      "No active menus for current time.",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
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
                      final imageUrl = data['imageUrl'] ?? '';
                      final startTime = (data['startTime'] as Timestamp?)?.toDate();
                      final endTime = (data['endTime'] as Timestamp?)?.toDate();

                      return Card(
                        elevation: 3,
                        child: ListTile(
                          leading: imageUrl.isNotEmpty
                              ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                              : const Icon(Icons.fastfood, size: 40),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Price: ₹$price"),
                              if (startTime != null && endTime != null)
                                Text(
                                  "Time: ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('extra_menu')
                                  .doc(docId)
                                  .update({'status': 'booking closed'});

                              // Refresh manually since stream will auto update
                              if (mounted) setState(() {});
                            },
                            child: const Text("Deactivate", style: TextStyle(color: Colors.orange)),
                          ),
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

  Widget _buildAnalyticsPage() => const Center(child: Text("Analytics Page"));

  Widget _buildProfilePage() {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Manager';
    final email = user?.email ?? '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Welcome, $name!', style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 10),
          Text(email, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text("Sign Out"),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraMenuPage() {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text("Add Extra Menu"),
        onPressed: () => Navigator.pushNamed(context, '/add_extra_menu'),
      ),
    );
  }

  Widget _buildGeneralMenuPage() {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.edit),
        label: const Text("Update General Menu"),
        onPressed: () => Navigator.pushNamed(context, '/update_general_menu'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomePage(context),
      _buildExtraMenuPage(),
      _buildGeneralMenuPage(),
      _buildAnalyticsPage(),
      _buildProfilePage(),
      
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Manager Dashboard')),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fastfood), label: 'Extra Menu'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'General Menu'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          
        ],
      ),
    );
  }
}
