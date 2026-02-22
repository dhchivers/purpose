import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/question_module.dart';
import 'package:purpose/core/models/question.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/auth_provider.dart';

/// Provider for a specific question module
final questionModuleProvider =
    FutureProvider.family<QuestionModule?, String>((ref, moduleId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getQuestionModule(moduleId);
});

/// Provider for questions in a module
final moduleQuestionsProvider =
    StreamProvider.family<List<Question>, String>((ref, moduleId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.allQuestionsStream(moduleId);
});

class AdminModuleDetailPage extends ConsumerWidget {
  final String moduleId;

  const AdminModuleDetailPage({
    super.key,
    required this.moduleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final moduleAsync = ref.watch(questionModuleProvider(moduleId));
    final questionsAsync = ref.watch(moduleQuestionsProvider(moduleId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Module Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/modules'),
        ),
      ),
      body: currentUserAsync.when(
        data: (user) {
          if (user == null || !user.isAdmin) {
            return const Center(child: Text('Access Denied'));
          }

          return moduleAsync.when(
            data: (module) {
              if (module == null) {
                return const Center(child: Text('Module not found'));
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Module Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.question_answer,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      module.name,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      module.parentModule.displayName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!module.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text('Inactive'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            module.description,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildInfoChip(
                                context,
                                Icons.numbers,
                                'Order: ${module.order}',
                              ),
                              const SizedBox(width: 8),
                              _buildInfoChip(
                                context,
                                Icons.quiz,
                                '${module.totalQuestions} questions',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Questions Section
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Questions',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showCreateQuestionDialog(
                                  context,
                                  ref,
                                  module,
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Question'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          questionsAsync.when(
                            data: (questions) {
                              if (questions.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(48),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.quiz_outlined,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No questions yet',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add your first question to get started',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: questions.length,
                                itemBuilder: (context, index) {
                                  final question = questions[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text('${question.order}'),
                                      ),
                                      title: Text(
                                        question.questionText,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            _getQuestionTypeLabel(
                                                question.questionType),
                                          ),
                                          if (question.answerCharacterLimit !=
                                              null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Character limit: ${question.answerCharacterLimit}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (question.isRequired)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.only(right: 8),
                                              child: Chip(
                                                label: Text(
                                                  'Required',
                                                  style:
                                                      TextStyle(fontSize: 10),
                                                ),
                                                padding: EdgeInsets.zero,
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            ),
                                          if (!question.isActive)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.only(right: 8),
                                              child: Chip(
                                                label: Text(
                                                  'Inactive',
                                                  style:
                                                      TextStyle(fontSize: 10),
                                                ),
                                                padding: EdgeInsets.zero,
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined),
                                            onPressed: () {
                                              _showEditQuestionDialog(
                                                context,
                                                ref,
                                                module,
                                                question,
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline),
                                            onPressed: () =>
                                                _confirmDeleteQuestion(
                                              context,
                                              ref,
                                              question,
                                              module,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (error, stack) {
                              // Print error details for debugging
                              print('=== FIRESTORE ERROR ===');
                              print('Error type: ${error.runtimeType}');
                              print('Error message: $error');
                              print('Stack trace: $stack');
                              
                              // Extract and print index creation link if it's a Firestore index error
                              final errorStr = error.toString();
                              if (errorStr.contains('cloud_firestore/failed-precondition') ||
                                  errorStr.contains('requires an index')) {
                                print('');
                                print('🔗 FIRESTORE INDEX REQUIRED 🔗');
                                print('This query needs a composite index.');
                                
                                // Try to extract the URL from the error message
                                final urlMatch = RegExp(r'https://[^\s\]]+').firstMatch(errorStr);
                                if (urlMatch != null) {
                                  final url = urlMatch.group(0);
                                  print('');
                                  print('Copy and paste this link to create the index:');
                                  print(url);
                                  print('');
                                }
                                print('======================');
                              }
                              
                              return _FirestoreErrorWidget(
                                error: error,
                                title: 'Error loading questions',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error: $error'),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _getQuestionTypeLabel(QuestionType type) {
    switch (type) {
      case QuestionType.shortText:
        return 'Short Text';
      case QuestionType.longText:
        return 'Long Text';
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.scale:
        return 'Scale';
      case QuestionType.yesNo:
        return 'Yes/No';
    }
  }

  void _showCreateQuestionDialog(
    BuildContext context,
    WidgetRef ref,
    QuestionModule module,
  ) {
    showDialog(
      context: context,
      builder: (context) => _CreateQuestionDialog(
        ref: ref,
        module: module,
      ),
    );
  }

  void _showEditQuestionDialog(
    BuildContext context,
    WidgetRef ref,
    QuestionModule module,
    Question question,
  ) {
    showDialog(
      context: context,
      builder: (context) => _EditQuestionDialog(
        ref: ref,
        module: module,
        question: question,
      ),
    );
  }

  void _confirmDeleteQuestion(
    BuildContext context,
    WidgetRef ref,
    Question question,
    QuestionModule module,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: Text(
          'Are you sure you want to delete "${question.questionText}"?',
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
                await firestoreService.deleteQuestion(question.id);

                // Update module's total questions count
                final updatedModule = module.copyWith(
                  totalQuestions: module.totalQuestions - 1,
                  updatedAt: DateTime.now(),
                );
                await firestoreService.updateQuestionModule(updatedModule);

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Question deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
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

class _CreateQuestionDialog extends StatefulWidget {
  final WidgetRef ref;
  final QuestionModule module;

  const _CreateQuestionDialog({
    required this.ref,
    required this.module,
  });

  @override
  State<_CreateQuestionDialog> createState() => _CreateQuestionDialogState();
}

class _CreateQuestionDialogState extends State<_CreateQuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _questionTextController = TextEditingController();
  final _helperTextController = TextEditingController();
  final _characterLimitController = TextEditingController();
  final _scaleMinController = TextEditingController(text: '1');
  final _scaleMaxController = TextEditingController(text: '10');
  final _scaleLowLabelController = TextEditingController();
  final _scaleHighLabelController = TextEditingController();
  final _optionController = TextEditingController();
  final _bulkOptionsController = TextEditingController();
  final _orderController = TextEditingController(text: '1');
  QuestionType _selectedQuestionType = QuestionType.shortText;
  bool _isRequired = true;
  bool _isActive = true;
  bool _isLoading = false;
  final List<String> _options = [];
  bool _allowMultipleSelections = false;

  @override
  void dispose() {
    _questionTextController.dispose();
    _helperTextController.dispose();
    _characterLimitController.dispose();
    _scaleMinController.dispose();
    _scaleMaxController.dispose();
    _scaleLowLabelController.dispose();
    _scaleHighLabelController.dispose();
    _optionController.dispose();
    _bulkOptionsController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Question'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _questionTextController,
                decoration: const InputDecoration(
                  labelText: 'Question Text',
                  hintText: 'What do you want to ask?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the question text';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _helperTextController,
                decoration: const InputDecoration(
                  labelText: 'Helper Text (Optional)',
                  hintText: 'Additional context or examples',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<QuestionType>(
                value: _selectedQuestionType,
                decoration: const InputDecoration(
                  labelText: 'Question Type',
                  border: OutlineInputBorder(),
                ),
                items: QuestionType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getQuestionTypeLabel(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedQuestionType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              // Show character limit only for text question types
              if (_selectedQuestionType == QuestionType.shortText ||
                  _selectedQuestionType == QuestionType.longText) ...[  
                TextFormField(
                  controller: _characterLimitController,
                  decoration: const InputDecoration(
                    labelText: 'Character Limit (Optional)',
                    hintText: 'e.g., 500',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              // Show scale fields only for scale question type
              if (_selectedQuestionType == QuestionType.scale) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _scaleMinController,
                        decoration: const InputDecoration(
                          labelText: 'Minimum Value',
                          hintText: '1',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _scaleMaxController,
                        decoration: const InputDecoration(
                          labelText: 'Maximum Value',
                          hintText: '10',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final max = int.tryParse(value);
                          final min = int.tryParse(_scaleMinController.text);
                          if (max == null) {
                            return 'Invalid number';
                          }
                          if (min != null && max <= min) {
                            return 'Must be > min';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _scaleLowLabelController,
                  decoration: const InputDecoration(
                    labelText: 'Low Value Label (Optional)',
                    hintText: 'e.g., Not at all',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _scaleHighLabelController,
                  decoration: const InputDecoration(
                    labelText: 'High Value Label (Optional)',
                    hintText: 'e.g., Extremely',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Show multiple choice options only for multiple choice question type
              if (_selectedQuestionType == QuestionType.multipleChoice) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _optionController,
                        decoration: const InputDecoration(
                          labelText: 'Add Option',
                          hintText: 'Enter an option',
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (_) => _addOption(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _addOption,
                      tooltip: 'Add option',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bulkOptionsController,
                        decoration: const InputDecoration(
                          labelText: 'Bulk Add (comma-separated)',
                          hintText: 'Option 1, Option 2, Option 3',
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (_) => _addBulkOptions(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.playlist_add),
                      onPressed: _addBulkOptions,
                      tooltip: 'Add multiple options',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_options.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No options added yet. Add at least 2 options.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _options.asMap().entries.map((entry) {
                          final index = entry.key;
                          final option = entry.value;
                          return ListTile(
                            dense: true,
                            leading: Text('${index + 1}.'),
                            title: Text(option),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => _removeOption(index),
                              tooltip: 'Remove option',
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Allow Multiple Selections'),
                  subtitle: Text(_allowMultipleSelections
                      ? 'Checkboxes (multiple answers)'
                      : 'Radio buttons (single answer)'),
                  value: _allowMultipleSelections,
                  onChanged: (value) {
                    setState(() => _allowMultipleSelections = value);
                  },
                ),
                const SizedBox(height: 16),
              ],
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
              SwitchListTile(
                title: const Text('Required'),
                subtitle: const Text('User must answer this question'),
                value: _isRequired,
                onChanged: (value) {
                  setState(() => _isRequired = value);
                },
              ),
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Question visible to users'),
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
          onPressed: _isLoading ? null : _createQuestion,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  String _getQuestionTypeLabel(QuestionType type) {
    switch (type) {
      case QuestionType.shortText:
        return 'Short Text';
      case QuestionType.longText:
        return 'Long Text';
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.scale:
        return 'Scale';
      case QuestionType.yesNo:
        return 'Yes/No';
    }
  }

  void _addOption() {
    final option = _optionController.text.trim();
    if (option.isNotEmpty && !_options.contains(option)) {
      setState(() {
        _options.add(option);
        _optionController.clear();
      });
    }
  }

  void _addBulkOptions() {
    final bulkText = _bulkOptionsController.text.trim();
    if (bulkText.isEmpty) return;

    final newOptions = bulkText
        .split(',')
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty && !_options.contains(o))
        .toList();

    if (newOptions.isNotEmpty) {
      setState(() {
        _options.addAll(newOptions);
        _bulkOptionsController.clear();
      });
    }
  }

  void _removeOption(int index) {
    setState(() {
      _options.removeAt(index);
    });
  }

  Future<void> _createQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate multiple choice options
    if (_selectedQuestionType == QuestionType.multipleChoice && _options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 2 options for multiple choice questions')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestoreService = widget.ref.read(firestoreServiceProvider);
      final now = DateTime.now();

      // Prepare scale labels if applicable
      List<String>? scaleLabels;
      if (_selectedQuestionType == QuestionType.scale) {
        final lowLabel = _scaleLowLabelController.text.trim();
        final highLabel = _scaleHighLabelController.text.trim();
        if (lowLabel.isNotEmpty || highLabel.isNotEmpty) {
          scaleLabels = [lowLabel, highLabel];
        }
      }

      final question = Question(
        id: '', // Firestore will generate
        questionModuleId: widget.module.id,
        questionText: _questionTextController.text.trim(),
        helperText: _helperTextController.text.trim().isEmpty
            ? null
            : _helperTextController.text.trim(),
        questionType: _selectedQuestionType,
        options: _selectedQuestionType == QuestionType.multipleChoice && _options.isNotEmpty
            ? List<String>.from(_options)
            : null,
        allowMultipleSelections: _selectedQuestionType == QuestionType.multipleChoice
            ? _allowMultipleSelections
            : null,
        answerCharacterLimit: (_selectedQuestionType == QuestionType.shortText ||
                _selectedQuestionType == QuestionType.longText) &&
            _characterLimitController.text.isNotEmpty
            ? int.parse(_characterLimitController.text)
            : null,
        scaleMin: _selectedQuestionType == QuestionType.scale
            ? int.parse(_scaleMinController.text)
            : null,
        scaleMax: _selectedQuestionType == QuestionType.scale
            ? int.parse(_scaleMaxController.text)
            : null,
        scaleLabels: scaleLabels,
        order: int.parse(_orderController.text),
        isRequired: _isRequired,
        isActive: _isActive,
        createdAt: now,
        updatedAt: now,
      );

      await firestoreService.createQuestion(question);

      // Update module's total questions count
      final updatedModule = widget.module.copyWith(
        totalQuestions: widget.module.totalQuestions + 1,
        updatedAt: now,
      );
      await firestoreService.updateQuestionModule(updatedModule);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating question: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _EditQuestionDialog extends StatefulWidget {
  final WidgetRef ref;
  final QuestionModule module;
  final Question question;

  const _EditQuestionDialog({
    required this.ref,
    required this.module,
    required this.question,
  });

  @override
  State<_EditQuestionDialog> createState() => _EditQuestionDialogState();
}

class _EditQuestionDialogState extends State<_EditQuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionTextController;
  late final TextEditingController _helperTextController;
  late final TextEditingController _characterLimitController;
  late final TextEditingController _scaleMinController;
  late final TextEditingController _scaleMaxController;
  late final TextEditingController _scaleLowLabelController;
  late final TextEditingController _scaleHighLabelController;
  late final TextEditingController _optionController;
  late final TextEditingController _bulkOptionsController;
  late final TextEditingController _orderController;
  late QuestionType _selectedQuestionType;
  late bool _isRequired;
  late bool _isActive;
  late List<String> _options;
  late bool _allowMultipleSelections;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields with existing question data
    _questionTextController = TextEditingController(text: widget.question.questionText);
    _helperTextController = TextEditingController(text: widget.question.helperText ?? '');
    _characterLimitController = TextEditingController(
      text: widget.question.answerCharacterLimit?.toString() ?? '',
    );
    _scaleMinController = TextEditingController(
      text: widget.question.scaleMin?.toString() ?? '1',
    );
    _scaleMaxController = TextEditingController(
      text: widget.question.scaleMax?.toString() ?? '10',
    );
    _scaleLowLabelController = TextEditingController(
      text: widget.question.scaleLabels != null && widget.question.scaleLabels!.isNotEmpty
          ? widget.question.scaleLabels![0]
          : '',
    );
    _scaleHighLabelController = TextEditingController(
      text: widget.question.scaleLabels != null && widget.question.scaleLabels!.length > 1
          ? widget.question.scaleLabels![1]
          : '',
    );
    _optionController = TextEditingController();
    _bulkOptionsController = TextEditingController();
    _orderController = TextEditingController(text: widget.question.order.toString());
    _selectedQuestionType = widget.question.questionType;
    _isRequired = widget.question.isRequired;
    _isActive = widget.question.isActive;
    _options = widget.question.options != null ? List<String>.from(widget.question.options!) : [];
    _allowMultipleSelections = widget.question.allowMultipleSelections ?? false;
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    _helperTextController.dispose();
    _characterLimitController.dispose();
    _scaleMinController.dispose();
    _scaleMaxController.dispose();
    _scaleLowLabelController.dispose();
    _scaleHighLabelController.dispose();
    _optionController.dispose();
    _bulkOptionsController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Question'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _questionTextController,
                decoration: const InputDecoration(
                  labelText: 'Question Text',
                  hintText: 'What do you want to ask?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the question text';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _helperTextController,
                decoration: const InputDecoration(
                  labelText: 'Helper Text (Optional)',
                  hintText: 'Additional context or examples',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<QuestionType>(
                value: _selectedQuestionType,
                decoration: const InputDecoration(
                  labelText: 'Question Type',
                  border: OutlineInputBorder(),
                ),
                items: QuestionType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getQuestionTypeLabel(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedQuestionType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              // Show character limit only for text question types
              if (_selectedQuestionType == QuestionType.shortText ||
                  _selectedQuestionType == QuestionType.longText) ...[  
                TextFormField(
                  controller: _characterLimitController,
                  decoration: const InputDecoration(
                    labelText: 'Character Limit (Optional)',
                    hintText: 'e.g., 500',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              // Show scale fields only for scale question type
              if (_selectedQuestionType == QuestionType.scale) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _scaleMinController,
                        decoration: const InputDecoration(
                          labelText: 'Minimum Value',
                          hintText: '1',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _scaleMaxController,
                        decoration: const InputDecoration(
                          labelText: 'Maximum Value',
                          hintText: '10',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final max = int.tryParse(value);
                          final min = int.tryParse(_scaleMinController.text);
                          if (max == null) {
                            return 'Invalid number';
                          }
                          if (min != null && max <= min) {
                            return 'Must be > min';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _scaleLowLabelController,
                  decoration: const InputDecoration(
                    labelText: 'Low Value Label (Optional)',
                    hintText: 'e.g., Not at all',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _scaleHighLabelController,
                  decoration: const InputDecoration(
                    labelText: 'High Value Label (Optional)',
                    hintText: 'e.g., Extremely',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Show multiple choice options only for multiple choice question type
              if (_selectedQuestionType == QuestionType.multipleChoice) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _optionController,
                        decoration: const InputDecoration(
                          labelText: 'Add Option',
                          hintText: 'Enter an option',
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (_) => _addOption(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _addOption,
                      tooltip: 'Add option',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bulkOptionsController,
                        decoration: const InputDecoration(
                          labelText: 'Bulk Add (comma-separated)',
                          hintText: 'Option 1, Option 2, Option 3',
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (_) => _addBulkOptions(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.playlist_add),
                      onPressed: _addBulkOptions,
                      tooltip: 'Add multiple options',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_options.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No options added yet. Add at least 2 options.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _options.asMap().entries.map((entry) {
                          final index = entry.key;
                          final option = entry.value;
                          return ListTile(
                            dense: true,
                            leading: Text('${index + 1}.'),
                            title: Text(option),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => _removeOption(index),
                              tooltip: 'Remove option',
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Allow Multiple Selections'),
                  subtitle: Text(_allowMultipleSelections
                      ? 'Checkboxes (multiple answers)'
                      : 'Radio buttons (single answer)'),
                  value: _allowMultipleSelections,
                  onChanged: (value) {
                    setState(() => _allowMultipleSelections = value);
                  },
                ),
                const SizedBox(height: 16),
              ],
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
              SwitchListTile(
                title: const Text('Required'),
                subtitle: const Text('User must answer this question'),
                value: _isRequired,
                onChanged: (value) {
                  setState(() => _isRequired = value);
                },
              ),
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Question visible to users'),
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
          onPressed: _isLoading ? null : _updateQuestion,
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

  String _getQuestionTypeLabel(QuestionType type) {
    switch (type) {
      case QuestionType.shortText:
        return 'Short Text';
      case QuestionType.longText:
        return 'Long Text';
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.scale:
        return 'Scale';
      case QuestionType.yesNo:
        return 'Yes/No';
    }
  }

  void _addOption() {
    final option = _optionController.text.trim();
    if (option.isNotEmpty && !_options.contains(option)) {
      setState(() {
        _options.add(option);
        _optionController.clear();
      });
    }
  }

  void _addBulkOptions() {
    final bulkText = _bulkOptionsController.text.trim();
    if (bulkText.isEmpty) return;
    
    final newOptions = bulkText
        .split(',')
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty && !_options.contains(o))
        .toList();
    
    if (newOptions.isNotEmpty) {
      setState(() {
        _options.addAll(newOptions);
        _bulkOptionsController.clear();
      });
    }
  }

  void _removeOption(int index) {
    setState(() {
      _options.removeAt(index);
    });
  }

  Future<void> _updateQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate multiple choice options
    if (_selectedQuestionType == QuestionType.multipleChoice && _options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 2 options for multiple choice questions')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestoreService = widget.ref.read(firestoreServiceProvider);

      // Prepare scale labels if applicable
      List<String>? scaleLabels;
      if (_selectedQuestionType == QuestionType.scale) {
        final lowLabel = _scaleLowLabelController.text.trim();
        final highLabel = _scaleHighLabelController.text.trim();
        if (lowLabel.isNotEmpty || highLabel.isNotEmpty) {
          scaleLabels = [lowLabel, highLabel];
        }
      }

      final updatedQuestion = widget.question.copyWith(
        questionText: _questionTextController.text.trim(),
        helperText: _helperTextController.text.trim().isEmpty
            ? null
            : _helperTextController.text.trim(),
        questionType: _selectedQuestionType,
        options: _selectedQuestionType == QuestionType.multipleChoice && _options.isNotEmpty
            ? List<String>.from(_options)
            : null,
        allowMultipleSelections: _selectedQuestionType == QuestionType.multipleChoice
            ? _allowMultipleSelections
            : null,
        answerCharacterLimit: (_selectedQuestionType == QuestionType.shortText ||
                _selectedQuestionType == QuestionType.longText) &&
            _characterLimitController.text.isNotEmpty
            ? int.parse(_characterLimitController.text)
            : null,
        scaleMin: _selectedQuestionType == QuestionType.scale
            ? int.parse(_scaleMinController.text)
            : null,
        scaleMax: _selectedQuestionType == QuestionType.scale
            ? int.parse(_scaleMaxController.text)
            : null,
        scaleLabels: scaleLabels,
        order: int.parse(_orderController.text),
        isRequired: _isRequired,
        isActive: _isActive,
        updatedAt: DateTime.now(),
      );

      await firestoreService.updateQuestion(updatedQuestion);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating question: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Widget to display Firestore errors with copyable index URLs
class _FirestoreErrorWidget extends StatelessWidget {
  final Object error;
  final String title;

  const _FirestoreErrorWidget({
    required this.error,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final errorStr = error.toString();
    final isIndexError = errorStr.contains('cloud_firestore/failed-precondition') ||
        errorStr.contains('requires an index');
    
    // Extract the URL if it's an index error
    String? indexUrl;
    if (isIndexError) {
      final urlMatch = RegExp(r'https://[^\s\]]+').firstMatch(errorStr);
      if (urlMatch != null) {
        indexUrl = urlMatch.group(0);
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isIndexError
                  ? 'This query requires a Firestore composite index.'
                  : 'An error occurred while loading data.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (indexUrl != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Click the button below to create the required index:',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    SelectableText(
                      indexUrl,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: indexUrl!));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('URL copied to clipboard!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy URL'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'After clicking the URL and creating the index,\nwait a few moments and refresh this page.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ] else if (!isIndexError) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  errorStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[700],
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
