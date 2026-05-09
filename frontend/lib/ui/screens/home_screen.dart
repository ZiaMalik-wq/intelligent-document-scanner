import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doc_scanner/providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Documents"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open_outlined, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              "Welcome, ${auth.user?.name ?? auth.user?.email.split('@')[0] ?? 'User'}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text("Your scanned documents will appear here."),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Future: Open Camera
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
