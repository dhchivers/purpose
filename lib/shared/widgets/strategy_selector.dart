import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/models/user_strategy.dart';
import 'package:purpose/core/models/strategy_type.dart';
import 'package:purpose/core/services/strategy_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';

/// Stream provider for all strategy types
final strategyTypesStreamProvider = StreamProvider<List<StrategyType>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.strategyTypesStream();
});

/// Widget for selecting and switching between strategies
class StrategySelector extends ConsumerWidget {
  final bool showCreateButton;
  final bool compact;

  const StrategySelector({
    super.key,
    this.showCreateButton = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    final activeStrategy = ref.watch(activeStrategyProvider);
    final strategiesAsync = ref.watch(currentUserStrategiesProvider);
    final strategyTypesAsync = ref.watch(strategyTypesStreamProvider);

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return strategiesAsync.when(
      data: (strategies) {
        if (strategies.isEmpty) {
          return _buildNoStrategiesState(context, ref);
        }

        // Pass strategy types to builders
        final strategyTypes = strategyTypesAsync.valueOrNull ?? [];

        if (compact) {
          return _buildCompactSelector(context, ref, strategies, activeStrategy, strategyTypes);
        }

        return _buildFullSelector(context, ref, strategies, activeStrategy, strategyTypes);
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) {
        print('❌ Error loading strategies in StrategySelector: $error');
        print('Stack trace: $stack');
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'Failed to load strategies',
                style: TextStyle(color: Colors.red[700], fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoStrategiesState(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.rocket_launch_outlined, size: 48, color: Colors.blue),
          const SizedBox(height: 12),
          const Text(
            'No strategies yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first strategy to start defining your purpose, values, vision, and mission.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          if (showCreateButton) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _createNewStrategy(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create Strategy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactSelector(
    BuildContext context,
    WidgetRef ref,
    List<UserStrategy> strategies,
    UserStrategy? activeStrategy,
    List<StrategyType> strategyTypes,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dashboard_outlined, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: activeStrategy?.id,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: [
              ...strategies.map((strategy) {
                final strategyType = strategyTypes.firstWhere(
                  (type) => type.id == strategy.strategyTypeId,
                  orElse: () => StrategyType(
                    id: '',
                    name: 'Unknown',
                    enabled: true,
                    order: 0,
                    color: 0xFF2196F3,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );
                return DropdownMenuItem(
                  value: strategy.id,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(strategyType.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        strategy.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                );
              }),
              if (showCreateButton)
                const DropdownMenuItem(
                  value: '__create__',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Create New Strategy',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (String? strategyId) {
              if (strategyId == '__create__') {
                _createNewStrategy(context, ref);
              } else if (strategyId != null) {
                final selected = strategies.firstWhere((s) => s.id == strategyId);
                ref.read(strategyContextProvider.notifier).setStrategy(selected);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFullSelector(
    BuildContext context,
    WidgetRef ref,
    List<UserStrategy> strategies,
    UserStrategy? activeStrategy,
    List<StrategyType> strategyTypes,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dashboard_outlined, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Strategies',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (showCreateButton)
                TextButton.icon(
                  onPressed: () => _createNewStrategy(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStrategyGrid(context, ref, strategies, activeStrategy, strategyTypes),
        ],
      ),
    );
  }

  Widget _buildStrategyGrid(
    BuildContext context,
    WidgetRef ref,
    List<UserStrategy> strategies,
    UserStrategy? activeStrategy,
    List<StrategyType> strategyTypes,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate number of columns (max 3)
        int columns = 3;
        if (constraints.maxWidth < 900) columns = 2;
        if (constraints.maxWidth < 600) columns = 1;

        final cardWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(strategies.length, (index) {
            final strategy = strategies[index];
            final isActive = activeStrategy?.id == strategy.id;
            
            return DragTarget<UserStrategy>(
              onWillAccept: (draggedStrategy) {
                // Accept if it's a different strategy
                return draggedStrategy != null && draggedStrategy.id != strategy.id;
              },
              onAccept: (draggedStrategy) {
                final oldIndex = strategies.indexOf(draggedStrategy);
                final newIndex = index;
                if (oldIndex != -1 && newIndex != -1 && oldIndex != newIndex) {
                  _onReorder(context, ref, strategies, oldIndex, newIndex);
                }
              },
              builder: (context, candidateData, rejectedData) {
                final isHovering = candidateData.isNotEmpty;
                
                return Container(
                  decoration: isHovering
                      ? BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 3),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: Draggable<UserStrategy>(
                    data: strategy,
                    feedback: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: cardWidth,
                        child: Opacity(
                          opacity: 0.8,
                          child: _buildStrategyCardContent(context, ref, strategy, isActive, cardWidth, strategyTypes),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _buildStrategyCardContent(context, ref, strategy, isActive, cardWidth, strategyTypes),
                    ),
                    child: _buildStrategyCardContent(context, ref, strategy, isActive, cardWidth, strategyTypes),
                  ),
                );
              },
            );
          }),
        );
      },
    );
  }

  Widget _buildStrategyCardContent(
    BuildContext context,
    WidgetRef ref,
    UserStrategy strategy,
    bool isActive,
    double cardWidth,
    List<StrategyType> strategyTypes,
  ) {
    // Find the strategy type for this strategy
    final strategyType = strategyTypes.firstWhere(
      (type) => type.id == strategy.strategyTypeId,
      orElse: () => StrategyType(
        id: '',
        name: 'Unknown',
        enabled: true,
        order: 0,
        color: 0xFF2196F3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: () {
          ref.read(strategyContextProvider.notifier).setStrategy(strategy);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? Colors.blue : Colors.grey[300]!,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(
                      strategyType.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Color(strategyType.color),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.grey[600],
                    onPressed: () => _editStrategy(context, ref, strategy),
                    tooltip: 'Edit Strategy',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.grey[600],
                    onPressed: () => _deleteStrategy(context, ref, strategy),
                    tooltip: 'Delete Strategy',
                  ),
                  const SizedBox(width: 8),
                  if (isActive)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.blue,
                      size: 20,
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.drag_indicator,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                strategy.name,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (strategy.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  strategy.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onReorder(
    BuildContext context,
    WidgetRef ref,
    List<UserStrategy> strategies,
    int oldIndex,
    int newIndex,
  ) async {
    print('🔄 Reordering: moving index $oldIndex to $newIndex');
    
    // Create a new list with the reordered items
    final reorderedStrategies = List<UserStrategy>.from(strategies);
    final item = reorderedStrategies.removeAt(oldIndex);
    reorderedStrategies.insert(newIndex, item);

    // Create a map of strategy IDs to new display orders
    final orderUpdates = <String, int>{};
    for (int i = 0; i < reorderedStrategies.length; i++) {
      orderUpdates[reorderedStrategies[i].id] = i;
      print('  Strategy "${reorderedStrategies[i].name}" -> displayOrder: $i');
    }

    // Delay the Firestore update to allow drag operation to complete
    // This prevents the StreamProvider from rebuilding while the feedback widget is still active
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.updateStrategyDisplayOrders(orderUpdates);
      print('✅ Successfully updated strategy display orders');
    } catch (e) {
      print('❌ Error updating strategy order: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reorder strategies: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createNewStrategy(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    final firestoreService = ref.read(firestoreServiceProvider);
    final strategyTypes = await firestoreService.getEnabledStrategyTypes();
    
    if (strategyTypes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No strategy types available. Please contact admin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    StrategyType? selectedType = strategyTypes.first;
    bool setAsDefault = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Strategy'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Strategy Name',
                    hintText: 'e.g., Professional Growth 2026',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<StrategyType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Strategy Type',
                    border: OutlineInputBorder(),
                  ),
                  items: strategyTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedType = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Brief description of this strategy',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: setAsDefault,
                  onChanged: (value) {
                    setState(() {
                      setAsDefault = value ?? false;
                    });
                  },
                  title: const Text('Set as default strategy'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
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
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.isNotEmpty && selectedType != null) {
      try {
        // Create the new strategy
        final newStrategy = await firestoreService.createStrategy(
          userId: currentUser.uid,
          name: nameController.text.trim(),
          strategyTypeId: selectedType!.id,
          description: descriptionController.text.trim().isEmpty 
              ? null 
              : descriptionController.text.trim(),
          isDefault: setAsDefault,
        );

        // Set as active strategy
        ref.read(strategyContextProvider.notifier).setStrategy(newStrategy);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Strategy "${newStrategy.name}" created!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create strategy: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editStrategy(BuildContext context, WidgetRef ref, UserStrategy strategy) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    final firestoreService = ref.read(firestoreServiceProvider);
    final strategyTypes = await firestoreService.getEnabledStrategyTypes();
    
    if (strategyTypes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No strategy types available. Please contact admin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final nameController = TextEditingController(text: strategy.name);
    final descriptionController = TextEditingController(text: strategy.description ?? '');
    StrategyType? selectedType = strategyTypes.firstWhere(
      (type) => type.id == strategy.strategyTypeId,
      orElse: () => strategyTypes.first,
    );
    bool setAsDefault = strategy.isDefault;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Strategy'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Strategy Name',
                    hintText: 'e.g., Professional Growth 2026',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<StrategyType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Strategy Type',
                    border: OutlineInputBorder(),
                  ),
                  items: strategyTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedType = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Brief description of this strategy',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: setAsDefault,
                  onChanged: (value) {
                    setState(() {
                      setAsDefault = value ?? false;
                    });
                  },
                  title: const Text('Set as default strategy'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
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
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.isNotEmpty && selectedType != null) {
      try {
        // Update the strategy
        final updatedStrategy = strategy.copyWith(
          name: nameController.text.trim(),
          strategyTypeId: selectedType!.id,
          description: descriptionController.text.trim().isEmpty 
              ? null 
              : descriptionController.text.trim(),
          isDefault: setAsDefault,
        );

        await firestoreService.updateStrategy(updatedStrategy);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Strategy "${updatedStrategy.name}" updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update strategy: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteStrategy(BuildContext context, WidgetRef ref, UserStrategy strategy) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Strategy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${strategy.name}"?'),
            const SizedBox(height: 16),
            const Text(
              'This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('• All values'),
            const Text('• All visions'),
            const Text('• All mission maps'),
            const Text('• All creation sessions'),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
        final firestoreService = ref.read(firestoreServiceProvider);
        await firestoreService.deleteStrategy(strategy.id, currentUser.uid);

        // If the deleted strategy was active, clear active strategy
        final activeStrategy = ref.read(activeStrategyProvider);
        if (activeStrategy?.id == strategy.id) {
          ref.read(strategyContextProvider.notifier).clearStrategy();
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Strategy "${strategy.name}" deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete strategy: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
