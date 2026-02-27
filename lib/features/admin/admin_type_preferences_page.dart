import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/type_preference.dart';
import 'package:purpose/core/models/strategy_type.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';

/// Stream provider for all strategy types (for dropdown selection)
final strategyTypesStreamProvider = StreamProvider<List<StrategyType>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.strategyTypesStream();
});

/// State provider for selected strategy type ID
final selectedStrategyTypeProvider = StateProvider<String?>((ref) => null);

/// Stream provider for type preferences of selected strategy type
final typePreferencesForSelectedTypeProvider = StreamProvider<List<TypePreference>>((ref) {
  final selectedTypeId = ref.watch(selectedStrategyTypeProvider);
  if (selectedTypeId == null) {
    return Stream.value([]);
  }
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.typePreferencesStream(selectedTypeId);
});

/// Admin page for managing type preferences (preference templates for strategy types)
class AdminTypePreferencesPage extends ConsumerWidget {
  const AdminTypePreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strategyTypesAsync = ref.watch(strategyTypesStreamProvider);
    final selectedTypeId = ref.watch(selectedStrategyTypeProvider);
    final typePreferencesAsync = ref.watch(typePreferencesForSelectedTypeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Type Preferences Management'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: Column(
        children: [
          // Strategy Type Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.background,
            child: strategyTypesAsync.when(
              data: (types) => _buildTypeSelector(context, ref, types, selectedTypeId),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('Error loading types: $error'),
            ),
          ),

          // Type Preferences List
          Expanded(
            child: selectedTypeId == null
                ? _buildEmptyState()
                : typePreferencesAsync.when(
                    data: (preferences) => _buildPreferencesList(context, ref, preferences),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error loading preferences: $error'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(typePreferencesForSelectedTypeProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: selectedTypeId != null
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref, selectedTypeId),
              icon: const Icon(Icons.add),
              label: const Text('Add Preference'),
            )
          : null,
    );
  }

  Widget _buildTypeSelector(
      BuildContext context, WidgetRef ref, List<StrategyType> types, String? selectedTypeId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Strategy Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedTypeId,
              decoration: InputDecoration(
                hintText: 'Choose a strategy type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: types.map((type) {
                return DropdownMenuItem(
                  value: type.id,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Color(type.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(type.name),
                      if (type.isDefault) ...[
                        const SizedBox(width: 8),
                        const Chip(
                          label: Text('Default', style: TextStyle(fontSize: 10)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                ref.read(selectedStrategyTypeProvider.notifier).state = value;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.settings_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Select a strategy type',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Choose a strategy type to manage its preference templates',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesList(
      BuildContext context, WidgetRef ref, List<TypePreference> preferences) {
    if (preferences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.list_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No preference templates found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Click the + button to create one',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: preferences.length,
      onReorder: (oldIndex, newIndex) => _handleReorder(ref, preferences, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final preference = preferences[index];
        return Card(
          key: ValueKey(preference.id),
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.drag_handle, color: Colors.grey),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: preference.enabled ? AppTheme.primary : Colors.grey,
                  foregroundColor: Colors.white,
                  child: Text('${preference.order}'),
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    preference.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTintLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    preference.shortLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.primary),
                  onPressed: () => _showEditDialog(context, ref, preference),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteDialog(context, ref, preference),
                  tooltip: 'Delete',
                ),
                const SizedBox(width: 8),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Description:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(preference.description),
                    const SizedBox(height: 12),
                    Chip(
                      label: Text(
                        preference.enabled ? 'Enabled' : 'Disabled',
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: preference.enabled ? Colors.green.shade100 : Colors.grey.shade300,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleReorder(WidgetRef ref, List<TypePreference> preferences, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final updatedPreferences = List<TypePreference>.from(preferences);
    final item = updatedPreferences.removeAt(oldIndex);
    updatedPreferences.insert(newIndex, item);

    // Update orders
    final reorderedPreferences = updatedPreferences.asMap().entries.map((entry) {
      return entry.value.copyWith(order: entry.key);
    }).toList();

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.updateTypePreferenceOrders(reorderedPreferences);
    } catch (e) {
      // Error is already logged in the service layer
      debugPrint('Error reordering preferences: $e');
    }
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref, String strategyTypeId) {
    showDialog(
      context: context,
      builder: (context) => _TypePreferenceDialog(
        strategyTypeId: strategyTypeId,
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, TypePreference preference) {
    showDialog(
      context: context,
      builder: (context) => _TypePreferenceDialog(
        strategyTypeId: preference.strategyTypeId,
        existingPreference: preference,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, TypePreference preference) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preference Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${preference.name}"?'),
            const SizedBox(height: 16),
            const Text(
              'This will not affect existing strategy preferences that were created from this template.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final firestoreService = ref.read(firestoreServiceProvider);
                await firestoreService.deleteTypePreference(preference.id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Preference template deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting preference: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Dialog for creating or editing a type preference
class _TypePreferenceDialog extends ConsumerStatefulWidget {
  final String strategyTypeId;
  final TypePreference? existingPreference;

  const _TypePreferenceDialog({
    required this.strategyTypeId,
    this.existingPreference,
  });

  @override
  ConsumerState<_TypePreferenceDialog> createState() => _TypePreferenceDialogState();
}

class _TypePreferenceDialogState extends ConsumerState<_TypePreferenceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _shortLabelController;
  late final TextEditingController _descriptionController;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pref = widget.existingPreference;
    _nameController = TextEditingController(text: pref?.name ?? '');
    _shortLabelController = TextEditingController(text: pref?.shortLabel ?? '');
    _descriptionController = TextEditingController(text: pref?.description ?? '');
    _enabled = pref?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortLabelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPreference != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Preference Template' : 'Create Preference Template'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'e.g., Work-Life Balance',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _shortLabelController,
                decoration: const InputDecoration(
                  labelText: 'Short Label *',
                  hintText: 'e.g., Balance',
                  border: OutlineInputBorder(),
                  helperText: 'Used in compact displays',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Short label is required';
                  }
                  if (value.length > 20) {
                    return 'Short label should be 20 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Describe this preference...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enabled'),
                subtitle: const Text('Available for selection in strategies'),
                value: _enabled,
                onChanged: (value) {
                  setState(() {
                    _enabled = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _savePreference,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _savePreference() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final now = DateTime.now();

      if (widget.existingPreference != null) {
        // Update existing
        final updated = widget.existingPreference!.copyWith(
          name: _nameController.text.trim(),
          shortLabel: _shortLabelController.text.trim(),
          description: _descriptionController.text.trim(),
          enabled: _enabled,
          updatedAt: now,
        );
        await firestoreService.updateTypePreference(updated);
      } else {
        // Create new - get current count for order
        final existingPrefs = await firestoreService.getAllTypePreferences(widget.strategyTypeId);
        final newPreference = TypePreference(
          id: '',
          strategyTypeId: widget.strategyTypeId,
          name: _nameController.text.trim(),
          shortLabel: _shortLabelController.text.trim(),
          description: _descriptionController.text.trim(),
          order: existingPrefs.length,
          enabled: _enabled,
          createdAt: now,
          updatedAt: now,
        );
        await firestoreService.createTypePreference(newPreference);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingPreference != null
                  ? 'Preference template updated successfully'
                  : 'Preference template created successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preference: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
}
