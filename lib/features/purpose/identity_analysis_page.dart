import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/identity_synthesis_result.dart';
import 'package:purpose/core/models/tier_analysis.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/identity_synthesis_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';

/// Provider for identity synthesis result
/// Uses autoDispose to ensure fresh data on each page visit
final identitySynthesisResultProvider = FutureProvider.autoDispose<IdentitySynthesisResult?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return null;
  
  final activeStrategy = ref.watch(activeStrategyProvider);
  if (activeStrategy == null) return null;
  
  print('=== IDENTITY SYNTHESIS PROVIDER TRIGGERED ===');
  print('User ID: ${user.uid}');
  print('Strategy ID: ${activeStrategy.id}');
  print('Timestamp: ${DateTime.now().toIso8601String()}');
  
  final synthesisService = await ref.watch(identitySynthesisServiceProvider.future);
  final result = await synthesisService.getOrSynthesize(user.uid, activeStrategy.id);
  
  print('Provider result ID: ${result.id}');
  return result;
});

class IdentityAnalysisPage extends ConsumerStatefulWidget {
  const IdentityAnalysisPage({super.key});

  @override
  ConsumerState<IdentityAnalysisPage> createState() => _IdentityAnalysisPageState();
}

class _IdentityAnalysisPageState extends ConsumerState<IdentityAnalysisPage> {
  int? _selectedOptionIndex;
  String? _editedStatement;
  final _statementController = TextEditingController();
  bool _isEditing = false;
  bool _isPromoting = false;
  bool _isRerunning = false;
  bool _hasInitialized = false;

  @override
  void dispose() {
    _statementController.dispose();
    super.dispose();
  }

  void _initializeFromResult(IdentitySynthesisResult result) {
    if (_hasInitialized) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      bool needsUpdate = false;
      
      if (_selectedOptionIndex == null && result.selectedOptionIndex != null) {
        _selectedOptionIndex = result.selectedOptionIndex;
        _statementController.text = result.purposeOptions[result.selectedOptionIndex!].statement;
        needsUpdate = true;
      }
      if (_editedStatement == null && result.editedStatement != null) {
        _editedStatement = result.editedStatement;
        _statementController.text = result.editedStatement!;
        needsUpdate = true;
      }
      
      if (needsUpdate && mounted) {
        setState(() {
          _hasInitialized = true;
        });
      } else {
        _hasInitialized = true;
      }
    });
  }

  Future<void> _rerunAnalysis() async {
    setState(() {
      _isRerunning = true;
      _hasInitialized = false; // Reset to allow re-initialization
    });
    
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not logged in');
      
      final activeStrategy = ref.read(activeStrategyProvider);
      if (activeStrategy == null) throw Exception('No active strategy');
      
      final synthesisService = await ref.read(identitySynthesisServiceProvider.future);
      await synthesisService.synthesizeAndSave(user.uid, activeStrategy.id);
      
      // Refresh the provider
      ref.invalidate(identitySynthesisResultProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analysis refreshed successfully')),
        );
      }
    } catch (e, stackTrace) {
      print('=== IDENTITY ANALYSIS RE-RUN ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRerunning = false);
      }
    }
  }

  Future<void> _selectOption(IdentitySynthesisResult result, int index) async {
    setState(() {
      _selectedOptionIndex = index;
      _editedStatement = null;
      _isEditing = false;
      _statementController.text = result.purposeOptions[index].statement;
    });
    
    final synthesisService = await ref.read(identitySynthesisServiceProvider.future);
    await synthesisService.selectPurposeOption(
      result: result,
      optionIndex: index,
    );
  }

  Future<void> _saveEdit(IdentitySynthesisResult result) async {
    setState(() => _isEditing = false);
    
    if (_statementController.text.isEmpty) return;
    
    setState(() => _editedStatement = _statementController.text);
    
    final synthesisService = await ref.read(identitySynthesisServiceProvider.future);
    await synthesisService.editPurposeStatement(
      result: result,
      editedStatement: _statementController.text,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purpose statement saved')),
      );
    }
  }

  Future<void> _promoteToPurpose(IdentitySynthesisResult result) async {
    if (_selectedOptionIndex == null && _editedStatement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or edit a purpose statement first')),
      );
      return;
    }
    
    setState(() => _isPromoting = true);
    
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not logged in');
      
      final activeStrategy = ref.read(activeStrategyProvider);
      if (activeStrategy == null) throw Exception('No active strategy');
      
      // Create updated result with local selection/edit
      final updatedResult = result.copyWith(
        selectedOptionIndex: _selectedOptionIndex,
        editedStatement: _editedStatement,
      );
      
      final synthesisService = await ref.read(identitySynthesisServiceProvider.future);
      await synthesisService.promotePurposeToProfile(
        userId: user.uid,
        strategyId: activeStrategy.id,
        result: updatedResult,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purpose statement promoted to your profile!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to purpose modules
        context.go('/purpose');
      }
    } catch (e, stackTrace) {
      print('=== IDENTITY ANALYSIS PROMOTION ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPromoting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultAsync = ref.watch(identitySynthesisResultProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Identity Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/purpose'),
        ),
        actions: [
          IconButton(
            icon: _isRerunning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Re-run Analysis',
            onPressed: _isRerunning ? null : _rerunAnalysis,
          ),
        ],
      ),
      body: resultAsync.when(
        data: (result) {
          if (result == null) {
            return const Center(
              child: Text('No analysis available'),
            );
          }

          // Initialize selection from result (scheduled for after build)
          _initializeFromResult(result);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Edit Your Purpose Statement
                _buildEditStatementSection(result),
                const SizedBox(height: 24),
                
                // Purpose Statement Options
                _buildPurposeOptionsSection(result),
                const SizedBox(height: 24),
                
                // Integrated Identity Section
                _buildIntegratedIdentitySection(result),
                const SizedBox(height: 24),
                
                // Tier Analysis Section
                _buildTierAnalysisSection(result),
                const SizedBox(height: 24),
                
                // Action Buttons
                _buildActionButtons(result),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Synthesizing your identity...'),
              SizedBox(height: 8),
              Text(
                'This may take a minute',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        error: (error, stack) {
          print('=== IDENTITY ANALYSIS LOAD ERROR ===');
          print('Error: $error');
          print('Stack trace: $stack');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(identitySynthesisResultProvider),
                child: const Text('Retry'),
              ),
            ],
          ));
        },
      ),
    );
  }

  Widget _buildIntegratedIdentitySection(IdentitySynthesisResult result) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Integrated Identity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              result.integratedIdentity.summary,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Key Patterns:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...result.integratedIdentity.keyPatterns.map((pattern) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(child: Text(pattern)),
                ],
              ),
            )),
            if (result.integratedIdentity.tensions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Tensions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...result.integratedIdentity.tensions.map((tension) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Expanded(child: Text(tension)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTierAnalysisSection(IdentitySynthesisResult result) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Tier Analysis',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...result.tierAnalysis.map((tier) => _buildTierCard(tier)),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(TierAnalysis tier) {
    return ExpansionTile(
      title: Text(
        tier.tierName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Row(
        children: [
          _getSignalChip(tier.signalStrength),
          const SizedBox(width: 8),
          Text('Confidence: ${(tier.confidenceScore * 100).toStringAsFixed(0)}%'),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tier.summary, style: const TextStyle(height: 1.5)),
              if (tier.dominantFeatures.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Dominant Features:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...tier.dominantFeatures.map((f) => Text('• $f')),
              ],
              if (tier.secondaryFeatures.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Secondary Features:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...tier.secondaryFeatures.map((f) => Text('• $f')),
              ],
              if (tier.tensionsDetected.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Tensions:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                const SizedBox(height: 4),
                ...tier.tensionsDetected.map((t) => Text('• $t', style: const TextStyle(color: Colors.orange))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _getSignalChip(String strength) {
    Color color;
    Color textColor;
    switch (strength.toLowerCase()) {
      case 'high':
        color = Colors.green;
        textColor = Colors.green.shade800;
        break;
      case 'moderate':
        color = Colors.orange;
        textColor = Colors.orange.shade800;
        break;
      default:
        color = Colors.grey;
        textColor = Colors.grey.shade800;
    }
    
    return Chip(
      label: Text(strength, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: textColor),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEditStatementSection(IdentitySynthesisResult result) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Edit Your Purpose Statement',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _statementController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Customize your purpose statement...',
                border: const OutlineInputBorder(),
                suffixIcon: _isEditing
                    ? IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () => _saveEdit(result),
                      )
                    : null,
              ),
              onChanged: (value) {
                if (!_isEditing) {
                  setState(() => _isEditing = true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurposeOptionsSection(IdentitySynthesisResult result) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Purpose Statement Options',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...result.purposeOptions.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = _selectedOptionIndex == index;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _selectOption(result, index),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected ? AppTheme.primaryTintLight : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isSelected)
                              const Icon(Icons.check_circle, color: AppTheme.primary, size: 20)
                            else
                              Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              option.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          option.statement,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: isSelected ? AppTheme.graphite : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(IdentitySynthesisResult result) {
    final hasSelection = _selectedOptionIndex != null || _editedStatement != null;
    
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: (hasSelection && !_isPromoting) 
                ? () => _promoteToPurpose(result)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: Colors.grey[300],
            ),
            icon: _isPromoting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload),
            label: Text(_isPromoting ? 'Promoting...' : 'Load to Purpose'),
          ),
        ),
      ],
    );
  }
}
