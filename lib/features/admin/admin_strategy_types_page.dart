import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/strategy_type.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';

/// Stream provider for all strategy types
final strategyTypesStreamProvider = StreamProvider<List<StrategyType>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.strategyTypesStream();
});

/// Admin page for managing strategy types
class AdminStrategyTypesPage extends ConsumerWidget {
  const AdminStrategyTypesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strategyTypesAsync = ref.watch(strategyTypesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Strategy Types Management'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: strategyTypesAsync.when(
        data: (types) => _buildTypesList(context, ref, types),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading strategy types: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(strategyTypesStreamProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Type'),
      ),
    );
  }

  Widget _buildTypesList(
      BuildContext context, WidgetRef ref, List<StrategyType> types) {
    if (types.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.category_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No strategy types found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Click the + button to create one',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = types[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: type.enabled ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
              child: Text('${type.order}'),
            ),
            title: Row(
              children: [
                Text(
                  type.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (type.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary),
                    ),
                    child: const Text(
                      'DEFAULT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (type.description != null) ...[
                  const SizedBox(height: 4),
                  Text(type.description!),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: type.enabled
                            ? Colors.green.shade100
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        type.enabled ? 'ENABLED' : 'DISABLED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: type.enabled ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FutureBuilder<int>(
                      future: ref
                          .read(firestoreServiceProvider)
                          .countStrategiesByType(type.id),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return Text(
                          '$count active ${count == 1 ? 'strategy' : 'strategies'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Enable/Disable toggle
                Switch(
                  value: type.enabled,
                  onChanged: type.isDefault
                      ? null // Cannot disable default type
                      : (value) => _toggleEnabled(context, ref, type, value),
                  activeColor: Colors.green,
                ),
                const SizedBox(width: 8),
                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditDialog(context, ref, type),
                  tooltip: 'Edit',
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: type.isDefault ? Colors.grey : Colors.red,
                  onPressed: type.isDefault
                      ? null // Cannot delete default type
                      : () => _confirmDelete(context, ref, type),
                  tooltip: type.isDefault
                      ? 'Cannot delete default type'
                      : 'Delete',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    int order = 1;
    Color selectedColor = const Color(0xFF2196F3); // Default blue

    // Predefined color options
    final colorOptions = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFF44336), // Red
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFF795548), // Brown
      const Color(0xFF607D8B), // Blue Grey
      const Color(0xFFE91E63), // Pink
    ];

    // Get current max order
    final typesAsync = ref.read(strategyTypesStreamProvider);
    if (typesAsync.hasValue) {
      final types = typesAsync.value!;
      if (types.isNotEmpty) {
        order = types.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Strategy Type'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Type Name',
                    hintText: 'e.g., Personal, Career, Financial',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Brief description of this type',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text('Color:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colorOptions.map((color) {
                    final isSelected = color.value == selectedColor.value;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.grey.shade300,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Display Order: $order',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final firestoreService = ref.read(firestoreServiceProvider);
        final now = DateTime.now();

        final newType = StrategyType(
          id: '', // Will be set by Firestore
          name: nameController.text.trim(),
          enabled: true,
          isDefault: false,
          order: order,
          color: selectedColor.value,
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );

        await firestoreService.createStrategyType(newType);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Strategy type "${newType.name}" created'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating type: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, StrategyType type) async {
    final nameController = TextEditingController(text: type.name);
    final descriptionController =
        TextEditingController(text: type.description ?? '');
    int order = type.order;
    Color selectedColor = Color(type.color);

    // Predefined color options
    final colorOptions = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFF44336), // Red
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFF795548), // Brown
      const Color(0xFF607D8B), // Blue Grey
      const Color(0xFFE91E63), // Pink
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Strategy Type'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Type Name',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !type.isDefault, // Cannot rename default type
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text('Color:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colorOptions.map((color) {
                    final isSelected = color.value == selectedColor.value;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.grey.shade300,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Display Order:'),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: order > 1
                          ? () => setState(() => order--)
                          : null,
                    ),
                    Text('$order',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => order++),
                    ),
                  ],
                ),
                if (type.isDefault)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTint,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryLight),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppTheme.primary, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This is the default type and cannot be renamed or disabled.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final firestoreService = ref.read(firestoreServiceProvider);

        final updatedType = type.copyWith(
          name: nameController.text.trim(),
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
          order: order,
          color: selectedColor.value,
          updatedAt: DateTime.now(),
        );

        await firestoreService.updateStrategyType(updatedType);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Strategy type "${updatedType.name}" updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating type: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleEnabled(BuildContext context, WidgetRef ref,
      StrategyType type, bool enabled) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // If disabling, check for active strategies
      if (!enabled) {
        final canDisable = await firestoreService.canDisableStrategyType(type.id);
        if (!canDisable) {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cannot Disable Type'),
                content: Text(
                  'Strategy type "${type.name}" has active strategies. '
                  'Please archive or delete them first.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      final updatedType = type.copyWith(
        enabled: enabled,
        updatedAt: DateTime.now(),
      );

      await firestoreService.updateStrategyType(updatedType);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Strategy type "${type.name}" ${enabled ? 'enabled' : 'disabled'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling type: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, StrategyType type) async {
    final firestoreService = ref.read(firestoreServiceProvider);

    // Check if type can be deleted
    final count = await firestoreService.countStrategiesByType(type.id);
    
    if (!context.mounted) return;

    if (count > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Type'),
          content: Text(
            'Strategy type "${type.name}" has $count active ${count == 1 ? 'strategy' : 'strategies'}. '
            'Please archive or delete them first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Strategy Type'),
        content: Text(
          'Are you sure you want to delete strategy type "${type.name}"?\n\n'
          'This action cannot be undone.',
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
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await firestoreService.deleteStrategyType(type.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Strategy type "${type.name}" deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting type: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
