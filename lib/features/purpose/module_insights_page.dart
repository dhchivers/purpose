import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/question_module.dart';
import 'package:purpose/core/services/ai_processor_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/auth_provider.dart';

/// Page to display AI-generated insights for a completed module
class ModuleInsightsPage extends ConsumerStatefulWidget {
  final String moduleId;

  const ModuleInsightsPage({
    super.key,
    required this.moduleId,
  });

  @override
  ConsumerState<ModuleInsightsPage> createState() => _ModuleInsightsPageState();
}

class _ModuleInsightsPageState extends ConsumerState<ModuleInsightsPage> {
  bool _isProcessing = false;
  String? _insights;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrGenerateInsights();
  }

  Future<void> _loadOrGenerateInsights() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final aiProcessor = await ref.read(aiProcessorServiceProvider.future);
      final firestoreService = ref.read(firestoreServiceProvider);
      
      // Get the module first
      final module = await firestoreService.getQuestionModule(widget.moduleId);
      
      if (module == null) {
        throw Exception('Module not found');
      }
      
      // Generate module analysis
      final insights = await aiProcessor.generateModuleAnalysis(
        userId: user.uid,
        module: module,
      );

      setState(() {
        _insights = insights;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final firestoreService = ref.watch(firestoreServiceProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return FutureBuilder<QuestionModule?>(
      future: firestoreService.getQuestionModule(widget.moduleId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final module = snapshot.data;
        if (module == null) {
          return const Scaffold(
            body: Center(child: Text('Module not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            title: Text('${module.name} - Insights'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/purpose'),
            ),
            actions: [
              if (!_isProcessing)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadOrGenerateInsights,
                  tooltip: 'Regenerate insights',
                ),
            ],
          ),
          body: _buildBody(module),
        );
      },
    );
  }

  Widget _buildBody(QuestionModule module) {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Analyzing your responses...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Our AI is carefully reviewing your answers to provide personalized insights.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error Generating Insights',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadOrGenerateInsights,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_insights == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade700, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.psychology,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Insights',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Based on your ${module.name} responses',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These insights are generated by AI to help you reflect on your responses. Use them as a guide for deeper self-discovery.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Insights content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                  _insights!,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/purpose/module/${widget.moduleId}'),
                    icon: const Icon(Icons.edit),
                    label: const Text('Review Answers'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/purpose'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
