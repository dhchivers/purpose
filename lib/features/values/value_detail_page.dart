import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/models/user_value.dart';
import 'package:purpose/core/models/value_creation_session.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/features/values/values_page.dart';

/// Page for viewing and editing a specific value
class ValueDetailPage extends ConsumerStatefulWidget {
  final String valueId;

  const ValueDetailPage({
    super.key,
    required this.valueId,
  });

  @override
  ConsumerState<ValueDetailPage> createState() => _ValueDetailPageState();
}

class _ValueDetailPageState extends ConsumerState<ValueDetailPage> {
  bool _isEditing = false;
  late TextEditingController _labelController;
  late TextEditingController _statementController;
  UserValue? _currentValue;
  ValueCreationSession? _session;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _statementController = TextEditingController();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _statementController.dispose();
    super.dispose();
  }

  Future<void> _loadValue() async {
    final firestoreService = ref.read(firestoreServiceProvider);
    final value = await firestoreService.getUserValue(widget.valueId);
    if (value != null && mounted) {
      setState(() {
        _currentValue = value;
        _labelController.text = value.refinedLabel;
        _statementController.text = value.statement;
      });
      
      // Load the creation session if available
      if (value.sessionId != null) {
        final session = await firestoreService.getValueCreationSession(value.sessionId!);
        if (session != null && mounted) {
          setState(() {
            _session = session;
          });
        }
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_currentValue == null) return;

    final updatedLabel = _labelController.text.trim();
    final updatedStatement = _statementController.text.trim();
    
    if (updatedLabel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Value title cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (updatedStatement.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Statement cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final updatedValue = _currentValue!.copyWith(
        refinedLabel: updatedLabel,
        statement: updatedStatement,
        updatedAt: DateTime.now(),
      );

      await firestoreService.updateUserValue(updatedValue);

      if (mounted) {
        // Invalidate the values list to refresh it
        ref.invalidate(userValuesProvider(updatedValue.userId));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Value updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back to values page
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/values');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating value: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteValue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Value?'),
        content: Text(
          'Are you sure you want to delete "${_currentValue?.refinedLabel}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.deleteUserValue(widget.valueId, _currentValue!.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Value deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to values list
        context.go('/values');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting value: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: Text(_currentValue?.refinedLabel ?? 'Value Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/values'),
        ),
        actions: [
          if (_currentValue != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Edit',
            ),
          if (_currentValue != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteValue,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _currentValue == null ? _loadValue() : null,
        builder: (context, snapshot) {
          if (_currentValue == null) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading value: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() => _loadValue()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            return const Center(child: Text('Value not found'));
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.diamond,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      if (_isEditing)
                        TextField(
                          controller: _labelController,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Value title...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white, width: 2),
                            ),
                          ),
                        )
                      else
                        Text(
                          _currentValue!.refinedLabel,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Based on: ${_currentValue!.seedValue}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                // Value Statement Section
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _isEditing ? 'Edit Value' : 'Value Statement',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isEditing) ...[
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _labelController.text = _currentValue!.refinedLabel;
                                  _statementController.text = _currentValue!.statement;
                                });
                              },
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _saveChanges,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                              ),
                              child: const Text('Save'),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isEditing) ...[
                        const Text(
                          'Value Statement',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.graphite,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _statementController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'Enter your value statement...',
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                        ),
                      ] else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTintLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                          ),
                          child: Text(
                            _currentValue!.statement,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const Divider(),

                // Metadata Section
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.calendar_today,
                        label: 'Created',
                        value: DateFormat('MMM d, yyyy').format(_currentValue!.createdAt),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.update,
                        label: 'Last Updated',
                        value: DateFormat('MMM d, yyyy').format(_currentValue!.updatedAt ?? _currentValue!.createdAt),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.label,
                        label: 'Original Seed',
                        value: _currentValue!.seedValue,
                      ),
                      if (_currentValue!.creationContext != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.info_outline,
                          label: 'Statement Style',
                          value: _currentValue!.creationContext!['selectedOptionLabel'] ?? 'Custom',
                        ),
                        if (_currentValue!.creationContext!['wasEdited'] == true) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            icon: Icons.edit_note,
                            label: 'Customized',
                            value: 'Yes - statement was edited',
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                // Value Summary Section (if available)
                if (_session?.valueSummary != null) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            const Text(
                              'Value Insight',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI-generated summary of your value and its personal application',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTintLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                          ),
                          child: Text(
                            _session!.valueSummary!,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Refinement Journey Section (if session available)
                if (_session != null) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timeline, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            const Text(
                              'Refinement Journey',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'How this value evolved through the AI-guided process',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildRefinementStep(
                          stepNumber: 1,
                          label: 'Starting Point',
                          value: _session!.seedValue,
                          icon: Icons.flag,
                        ),
                        if (_session!.refinedValuePhase3 != null) ...[
                          const SizedBox(height: 12),
                          _buildRefinementStep(
                            stepNumber: 2,
                            label: 'After Scope Narrowing',
                            value: _session!.refinedValuePhase3!,
                            icon: Icons.center_focus_strong,
                          ),
                        ],
                        if (_session!.refinedValuePhase4 != null) ...[
                          const SizedBox(height: 12),
                          _buildRefinementStep(
                            stepNumber: 3,
                            label: 'After Friction & Sacrifice',
                            value: _session!.refinedValuePhase4!,
                            icon: Icons.balance,
                          ),
                        ],
                        if (_session!.refinedValuePhase5 != null) ...[
                          const SizedBox(height: 12),
                          _buildRefinementStep(
                            stepNumber: 4,
                            label: 'After Operationalization',
                            value: _session!.refinedValuePhase5!,
                            icon: Icons.check_circle,
                            isFinal: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Alternative Statements Section (if available)
                if (_session?.finalValueOptions != null && _session!.finalValueOptions!.length > 1) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            const Text(
                              'Alternative Statements',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Other AI-generated statement options from your session',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._session!.finalValueOptions!.asMap().entries.map((entry) {
                          final index = entry.key;
                          final option = entry.value;
                          final isSelected = _session!.selectedOptionIndex == index;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? AppTheme.primary.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected 
                                      ? AppTheme.primary
                                      : Colors.grey.withOpacity(0.2),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isSelected) ...[
                                        const Icon(
                                          Icons.check_circle,
                                          color: AppTheme.primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        option.label,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? AppTheme.primary : AppTheme.graphite,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'SELECTED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    option.statement,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRefinementStep({
    required int stepNumber,
    required String label,
    required String value,
    required IconData icon,
    bool isFinal = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isFinal ? AppTheme.primary : AppTheme.primaryTintLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$stepNumber',
              style: TextStyle(
                color: isFinal ? Colors.white : AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isFinal ? FontWeight.bold : FontWeight.normal,
                  color: isFinal ? AppTheme.primary : AppTheme.graphite,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
