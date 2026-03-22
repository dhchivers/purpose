import 'package:flutter/material.dart';

/// Stub for MigrationTestPage on non-web platforms
/// The migration script is web-only, so this provides a placeholder
class MigrationTestPage extends StatelessWidget {
  const MigrationTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migration Test'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.web,
                size: 80,
                color: Colors.grey,
              ),
              SizedBox(height: 24),
              Text(
                'Migration Tool',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'This migration tool is only available on the web platform.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please access it from a web browser.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
