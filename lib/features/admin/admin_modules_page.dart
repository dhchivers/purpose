import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/question_module.dart';
import 'package:purpose/core/models/module_type.dart';
import 'package:purpose/core/models/strategy_type.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';

/// Provider for streaming all question modules
final allQuestionModulesProvider = StreamProvider<List<QuestionModule>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.allQuestionModulesStream();
});

/// Provider for streaming all strategy types
final strategyTypesStreamProvider = StreamProvider<List<StrategyType>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.strategyTypesStream();
});

class AdminModulesPage extends ConsumerWidget {
  const AdminModulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final modulesAsync = ref.watch(allQuestionModulesProvider);
    final strategyTypesAsync = ref.watch(strategyTypesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Purpose Question Modules'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: currentUserAsync.when(
        data: (user) {
          if (user == null || !user.isAdmin) {
            return const Center(
              child: Text('Access Denied'),
            );
          }

          return modulesAsync.when(
            data: (modules) {
              return strategyTypesAsync.when(
                data: (strategyTypes) {
                  if (modules.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.question_answer_outlined,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Question Modules',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create your first question module to get started',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _showCreateModuleDialog(context, ref, strategyTypes),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Module'),
                          ),
                        ],
                      ),
                    );
                  }

                  return _buildExpandableModuleList(context, ref, modules, strategyTypes);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error loading strategy types: $error')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              print('=== FIRESTORE ERROR (Modules) ===');
              print('Error: $error');
              final errorStr = error.toString();
              if (errorStr.contains('requires an index')) {
                final urlMatch = RegExp(r'https://[^\s\]]+').firstMatch(errorStr);
                if (urlMatch != null) {
                  print('\n🔗 INDEX CREATION LINK:\n${urlMatch.group(0)}\n');
                }
              }
              return Center(child: Text('Error: $error'));
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          print('=== FIRESTORE ERROR (User Check) ===');
          print('Error: $error');
          final errorStr = error.toString();
          if (errorStr.contains('requires an index')) {
            final urlMatch = RegExp(r'https://[^\s\]]+').firstMatch(errorStr);
            if (urlMatch != null) {
              print('\n🔗 INDEX CREATION LINK:\n${urlMatch.group(0)}\n');
            }
          }
          return Center(child: Text('Error: $error'));
        },
      ),
      floatingActionButton: currentUserAsync.maybeWhen(
        data: (user) {
          if (user?.isAdmin == true) {
            return strategyTypesAsync.maybeWhen(
              data: (strategyTypes) => FloatingActionButton.extended(
                onPressed: () => _showCreateModuleDialog(context, ref, strategyTypes),
                icon: const Icon(Icons.add),
                label: const Text('New Module'),
              ),
              orElse: () => null,
            );
          }
          return null;
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildExpandableModuleList(
    BuildContext context,
    WidgetRef ref,
    List<QuestionModule> modules,
    List<StrategyType> strategyTypes,
  ) {
    // Group modules by strategy type
    final groupedModules = <String, List<QuestionModule>>{};
    
    // Add modules to their strategy type groups
    for (final module in modules) {
      final typeId = module.strategyTypeId ?? 'unassigned';
      groupedModules.putIfAbsent(typeId, () => []).add(module);
    }
    
    // Sort modules within each group by order
    for (final moduleList in groupedModules.values) {
      moduleList.sort((a, b) => a.order.compareTo(b.order));
    }
    
    // Sort strategy types by order
    final sortedTypes = List<StrategyType>.from(strategyTypes)
      ..sort((a, b) => a.order.compareTo(b.order));
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Show strategy type sections
        for (final strategyType in sortedTypes)
          if (groupedModules.containsKey(strategyType.id))
            _buildStrategyTypeSection(
              context, 
              ref, 
              strategyType, 
              groupedModules[strategyType.id]!,
              strategyTypes,
            ),
        // Show unassigned modules if any
        if (groupedModules.containsKey('unassigned'))
          _buildUnassignedSection(
            context,
            ref,
            groupedModules['unassigned']!,
            strategyTypes,
          ),
      ],
    );
  }

  Widget _buildStrategyTypeSection(
    BuildContext context,
    WidgetRef ref,
    StrategyType strategyType,
    List<QuestionModule> modules,
    List<StrategyType> allStrategyTypes,
  ) {
    final totalQuestions = modules.fold<int>(0, (sum, m) => sum + m.totalQuestions);
    final activeModules = modules.where((m) => m.isActive).length;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Color(strategyType.color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              Icons.category,
              color: Color(strategyType.color),
              size: 28,
            ),
          ),
        ),
        title: Text(
          strategyType.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$activeModules module${activeModules != 1 ? 's' : ''} • $totalQuestions questions',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        initiallyExpanded: true,
        children: modules.map((module) => _buildModuleListItem(context, ref, module, allStrategyTypes)).toList(),
      ),
    );
  }

  Widget _buildUnassignedSection(
    BuildContext context,
    WidgetRef ref,
    List<QuestionModule> modules,
    List<StrategyType> strategyTypes,
  ) {
    final totalQuestions = modules.fold<int>(0, (sum, m) => sum + m.totalQuestions);
    final activeModules = modules.where((m) => m.isActive).length;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(
              Icons.help_outline,
              color: Colors.grey,
              size: 28,
            ),
          ),
        ),
        title: const Text(
          'Unassigned',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$activeModules module${activeModules != 1 ? 's' : ''} • $totalQuestions questions',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        initiallyExpanded: false,
        children: modules.map((module) => _buildModuleListItem(context, ref, module, strategyTypes)).toList(),
      ),
    );
  }

  Widget _buildModuleListItem(
    BuildContext context,
    WidgetRef ref,
    QuestionModule module,
    List<StrategyType> strategyTypes,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${module.order}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(
        module.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            module.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.quiz_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${module.totalQuestions} questions',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (!module.isActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'Inactive',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _showEditModuleDialog(context, ref, module, strategyTypes),
            tooltip: 'Edit module',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _confirmDeleteModule(context, ref, module),
            tooltip: 'Delete module',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, size: 20),
            onPressed: () => context.go('/admin/modules/${module.id}'),
            tooltip: 'View details',
          ),
        ],
      ),
      onTap: () => context.go('/admin/modules/${module.id}'),
    );
  }
  void _showCreateModuleDialog(BuildContext context, WidgetRef ref, List<StrategyType> strategyTypes) {
    showDialog(
      context: context,
      builder: (context) => _CreateModuleDialog(ref: ref, strategyTypes: strategyTypes),
    );
  }

  void _showEditModuleDialog(
    BuildContext context,
    WidgetRef ref,
    QuestionModule module,
    List<StrategyType> strategyTypes,
  ) {
    showDialog(
      context: context,
      builder: (context) => _EditModuleDialog(
        ref: ref,
        module: module,
        strategyTypes: strategyTypes,
      ),
    );
  }

  void _confirmDeleteModule(
    BuildContext context,
    WidgetRef ref,
    QuestionModule module,
  ) async {
    // Check if module has questions
    if (module.totalQuestions > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Module'),
          content: Text(
            'This module contains ${module.totalQuestions} question(s). '
            'Please delete all questions before deleting the module.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Module'),
        content: Text(
          'Are you sure you want to delete "${module.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                final firestoreService = ref.read(firestoreServiceProvider);
                await firestoreService.deleteQuestionModule(module.id);

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Module deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting module: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _CreateModuleDialog extends StatefulWidget {
  final WidgetRef ref;
  final List<StrategyType> strategyTypes;

  const _CreateModuleDialog({
    required this.ref,
    required this.strategyTypes,
  });

  @override
  State<_CreateModuleDialog> createState() => _CreateModuleDialogState();
}

class _CreateModuleDialogState extends State<_CreateModuleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _orderController = TextEditingController(text: '1');
  final _agentPromptController = TextEditingController();
  ModuleType _selectedModuleType = ModuleType.purpose;
  StrategyType? _selectedStrategyType;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default to first strategy type (should be Personal)
    if (widget.strategyTypes.isNotEmpty) {
      _selectedStrategyType = widget.strategyTypes.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    _agentPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Question Module'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Module Name',
                  hintText: 'e.g., Core Values Discovery',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What this module covers...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<StrategyType>(
                value: _selectedStrategyType,
                decoration: const InputDecoration(
                  labelText: 'Strategy Type',
                  border: OutlineInputBorder(),
                ),
                items: widget.strategyTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
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
                        const SizedBox(width: 8),
                        Text(type.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedStrategyType = value);
                  }
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a strategy type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ModuleType>(
                value: _selectedModuleType,
                decoration: const InputDecoration(
                  labelText: 'Parent Module',
                  border: OutlineInputBorder(),
                ),
                items: ModuleType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedModuleType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _orderController,
                decoration: const InputDecoration(
                  labelText: 'Order',
                  hintText: 'Display order (1, 2, 3...)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an order number';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _agentPromptController,
                decoration: const InputDecoration(
                  labelText: 'AI Agent Prompt (Optional)',
                  hintText: 'Instructions for AI to process answers...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Module visible to users'),
                value: _isActive,
                onChanged: (value) {
                  setState(() => _isActive = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createModule,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createModule() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firestoreService = widget.ref.read(firestoreServiceProvider);
      final now = DateTime.now();

      final module = QuestionModule(
        id: '', // Firestore will generate
        parentModule: _selectedModuleType,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        order: int.parse(_orderController.text),
        totalQuestions: 0, // Will be updated as questions are added
        isActive: _isActive,
        strategyTypeId: _selectedStrategyType?.id,
        agentPrompt: _agentPromptController.text.trim().isEmpty
            ? null
            : _agentPromptController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await firestoreService.createQuestionModule(module);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Module created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating module: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _EditModuleDialog extends StatefulWidget {
  final WidgetRef ref;
  final QuestionModule module;
  final List<StrategyType> strategyTypes;

  const _EditModuleDialog({
    required this.ref,
    required this.module,
    required this.strategyTypes,
  });

  @override
  State<_EditModuleDialog> createState() => _EditModuleDialogState();
}

class _EditModuleDialogState extends State<_EditModuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _orderController;
  late final TextEditingController _agentPromptController;
  late ModuleType _selectedModuleType;
  StrategyType? _selectedStrategyType;
  late bool _isActive;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields with existing module data
    _nameController = TextEditingController(text: widget.module.name);
    _descriptionController = TextEditingController(text: widget.module.description);
    _orderController = TextEditingController(text: widget.module.order.toString());
    _agentPromptController = TextEditingController(text: widget.module.agentPrompt ?? '');
    _selectedModuleType = widget.module.parentModule;
    _isActive = widget.module.isActive;
    
    // Initialize strategy type - find current or default to first
    if (widget.module.strategyTypeId != null) {
      _selectedStrategyType = widget.strategyTypes.firstWhere(
        (type) => type.id == widget.module.strategyTypeId,
        orElse: () => widget.strategyTypes.first,
      );
    } else {
      _selectedStrategyType = widget.strategyTypes.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    _agentPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Question Module'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Module Name',
                  hintText: 'e.g., Core Values Discovery',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What this module covers...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<StrategyType>(
                value: _selectedStrategyType,
                decoration: const InputDecoration(
                  labelText: 'Strategy Type',
                  border: OutlineInputBorder(),
                ),
                items: widget.strategyTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
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
                        const SizedBox(width: 8),
                        Text(type.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedStrategyType = value);
                  }
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a strategy type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ModuleType>(
                value: _selectedModuleType,
                decoration: const InputDecoration(
                  labelText: 'Parent Module',
                  border: OutlineInputBorder(),
                ),
                items: ModuleType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedModuleType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _orderController,
                decoration: const InputDecoration(
                  labelText: 'Order',
                  hintText: 'Display order (1, 2, 3...)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an order number';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _agentPromptController,
                decoration: const InputDecoration(
                  labelText: 'AI Agent Prompt (Optional)',
                  hintText: 'Instructions for AI to process answers...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Module visible to users'),
                value: _isActive,
                onChanged: (value) {
                  setState(() => _isActive = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateModule,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  Future<void> _updateModule() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firestoreService = widget.ref.read(firestoreServiceProvider);

      final updatedModule = widget.module.copyWith(
        parentModule: _selectedModuleType,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        order: int.parse(_orderController.text),
        isActive: _isActive,
        strategyTypeId: _selectedStrategyType?.id,
        agentPrompt: _agentPromptController.text.trim().isEmpty
            ? null
            : _agentPromptController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await firestoreService.updateQuestionModule(updatedModule);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Module updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating module: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
