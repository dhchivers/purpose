import 'package:flutter/material.dart';
import 'package:purpose/core/services/mission_migration_script.dart';

/// Simple UI to test the migration
/// 
/// Add this to your app temporarily for testing:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => MigrationTestPage(),
/// ));
/// ```
class MigrationTestPage extends StatefulWidget {
  const MigrationTestPage({super.key});

  @override
  State<MigrationTestPage> createState() => _MigrationTestPageState();
}

class _MigrationTestPageState extends State<MigrationTestPage> {
  final _migrator = MissionMigrationScript();
  String _log = '';
  bool _isRunning = false;

  void _addLog(String message) {
    setState(() {
      _log += '$message\n';
    });
    print(message);
  }

  Future<void> _runDryRun() async {
    setState(() {
      _log = '';
      _isRunning = true;
    });

    try {
      _addLog('🔍 Starting dry run...\n');
      await _migrator.runMigration(dryRun: true);
      _addLog('\n✅ Dry run completed successfully!');
      _addLog('\n📥 BACKUP INFO:');
      _addLog('   • JSON file downloaded to your Downloads folder');
      _addLog('   • Backup also stored in browser localStorage');
      _addLog('   • Keep the downloaded file for rollback if needed');
    } catch (e, stackTrace) {
      _addLog('\n❌ Error: $e');
      _addLog('Stack trace: $stackTrace');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _runMigration() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirm Migration'),
        content: const Text(
          'This will modify your Firestore database!\n\n'
          'Make sure you have reviewed the dry run results.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes, Migrate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _log = '';
      _isRunning = true;
    });

    try {
      _addLog('🚀 Starting migration...\n');
      await _migrator.runMigration(dryRun: false);
      _addLog('\n✅ Migration completed successfully!');
    } catch (e, stackTrace) {
      _addLog('\n❌ Error: $e');
      _addLog('Stack trace: $stackTrace');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission Data Migration'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '⚠️ Migration Test Tool',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will migrate user_mission_maps to the new structure:\n'
                  '• mission_maps (metadata)\n'
                  '• missions (individual documents)\n\n'
                  '🔒 Safety: Creates backup JSON file (auto-downloaded)',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _runDryRun,
                  icon: const Icon(Icons.preview),
                  label: const Text('1. Run Dry Run (Preview)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _runMigration,
                  icon: const Icon(Icons.upload),
                  label: const Text('2. Run Actual Migration'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isRunning)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: SelectableText(
                  _log.isEmpty ? 'Output will appear here...' : _log,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
