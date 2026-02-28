import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/type_preference.dart';
import 'package:purpose/core/models/strategy_preference.dart';
import 'package:purpose/core/models/mission_creation_session.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/services/strategy_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/features/value_profile/widgets/preference_dual_bar.dart';
import 'package:purpose/features/value_profile/widgets/dual_bar_legend.dart';
import 'package:purpose/features/value_profile/widgets/agent_panel.dart';
import 'package:purpose/features/value_profile/models/agent_session.dart';
import 'package:purpose/features/value_profile/models/agent_question.dart';
import 'package:purpose/features/value_profile/models/question_answer.dart';
import 'package:purpose/features/value_profile/models/stability_metrics.dart';
import 'package:purpose/features/value_profile/providers/agent_providers.dart';

/// State class for managing preference weights and monetary factors
class PreferenceWeight {
  final TypePreference preference;
  final double weight; // 0-100 for UI display
  final double monetary; // Monetary factor per year

  PreferenceWeight({
    required this.preference,
    this.weight = 0,
    this.monetary = 0,
  });

  PreferenceWeight copyWith({
    double? weight,
    double? monetary,
  }) {
    return PreferenceWeight(
      preference: preference,
      weight: weight ?? this.weight,
      monetary: monetary ?? this.monetary,
    );
  }
}

/// State provider for preference weights during editing
final preferenceWeightsProvider =
    StateProvider.family<List<PreferenceWeight>, String>((ref, strategyTypeId) => []);

/// State provider for selected preference (to show details)
final selectedPreferenceProvider = StateProvider<TypePreference?>((ref) => null);

/// Page for configuring value profile weights
class ValueProfilePage extends ConsumerStatefulWidget {
  const ValueProfilePage({super.key});

  @override
  ConsumerState<ValueProfilePage> createState() => _ValueProfilePageState();
}

class _ValueProfilePageState extends ConsumerState<ValueProfilePage> {
  bool _isLoading = false;
  bool _isSaving = false;
  bool _showAgent = false;
  bool _isAgentProcessing = false;
  AgentSession? _activeSession;
  List<AgentQuestion> _currentQuestions = [];
  StabilityMetrics _stability = StabilityMetrics.initial();
  String _agentFeedback = '';
  double? _missionBudget;
  String? _missionName;
  double _budgetPercentage = 10.0; // Default to 10% of mission budget

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferences();
    });
  }

  Future<void> _loadPreferences() async {
    final activeStrategy = ref.read(activeStrategyProvider);
    if (activeStrategy == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active strategy found. Please select a strategy first.'),
            backgroundColor: Colors.red,
          ),
        );
        context.go('/');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      
      // Load type preferences for this strategy's type
      final typePreferences = await firestoreService.getAllTypePreferences(
        activeStrategy.strategyTypeId,
      );

      // Load existing strategy preferences if any
      final existingPreferences = await firestoreService.getAllStrategyPreferences(
        activeStrategy.id,
      );

      // Create preference weights, using existing weights if available
      final weights = typePreferences.map((typePref) {
        final existing = existingPreferences.firstWhere(
          (sp) => sp.name == typePref.name,
          orElse: () => StrategyPreference(
            id: '',
            strategyId: activeStrategy.id,
            name: typePref.name,
            shortLabel: typePref.shortLabel,
            description: typePref.description,
            relativeWeight: 0,
            monetaryFactorPerYear: 0,
            order: typePref.order,
            enabled: typePref.enabled,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Convert from 0-1 range to 0-100 for display
        final displayWeight = existing.relativeWeight * 100;
        return PreferenceWeight(
          preference: typePref,
          weight: displayWeight,
          monetary: existing.monetaryFactorPerYear,
        );
      }).toList();

      // Sort by order
      weights.sort((a, b) => a.preference.order.compareTo(b.preference.order));

      // If all weights are 0, distribute equally
      if (weights.every((w) => w.weight == 0)) {
        final equalWeight = 100.0 / weights.length;
        for (var i = 0; i < weights.length; i++) {
          weights[i] = weights[i].copyWith(weight: equalWeight);
        }
      }

      ref.read(preferenceWeightsProvider(activeStrategy.strategyTypeId).notifier).state = weights;

      // Load mission budget for budget slider
      await _loadMissionBudget(activeStrategy.id);
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading preferences: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _adjustWeight(int index, double delta) {
    final activeStrategy = ref.read(activeStrategyProvider);
    if (activeStrategy == null) return;

    final weights = List<PreferenceWeight>.from(
      ref.read(preferenceWeightsProvider(activeStrategy.strategyTypeId)),
    );

    if (index < 0 || index >= weights.length) return;

    // Calculate new weight for the adjusted preference
    final newWeight = (weights[index].weight + delta).clamp(0.0, 100.0);
    _setWeight(index, newWeight);
  }

  void _setWeight(int index, double newWeight) {
    final activeStrategy = ref.read(activeStrategyProvider);
    if (activeStrategy == null) return;

    final weights = List<PreferenceWeight>.from(
      ref.read(preferenceWeightsProvider(activeStrategy.strategyTypeId)),
    );

    if (index < 0 || index >= weights.length) return;

    // Clamp to valid range
    newWeight = newWeight.clamp(0.0, 100.0);
    final actualDelta = newWeight - weights[index].weight;

    if (actualDelta.abs() < 0.01) return; // No meaningful change

    // Update the target preference
    weights[index] = weights[index].copyWith(weight: newWeight);

    // Distribute the delta across other preferences proportionally
    final otherIndices = List.generate(weights.length, (i) => i)
        .where((i) => i != index)
        .toList();

    if (otherIndices.isEmpty) return;

    // Calculate total weight of others for proportional distribution
    final othersTotalWeight = otherIndices.fold<double>(
      0,
      (sum, i) => sum + weights[i].weight,
    );

    if (othersTotalWeight > 0) {
      // Distribute proportionally
      for (final i in otherIndices) {
        final proportion = weights[i].weight / othersTotalWeight;
        final adjustment = -actualDelta * proportion;
        final adjustedWeight = (weights[i].weight + adjustment).clamp(0.0, 100.0);
        weights[i] = weights[i].copyWith(weight: adjustedWeight);
      }
    } else {
      // All others are 0, distribute equally
      final equalAdjustment = -actualDelta / otherIndices.length;
      for (final i in otherIndices) {
        final adjustedWeight = (weights[i].weight + equalAdjustment).clamp(0.0, 100.0);
        weights[i] = weights[i].copyWith(weight: adjustedWeight);
      }
    }

    // Normalize to ensure sum is exactly 100
    final total = weights.fold<double>(0, (sum, w) => sum + w.weight);
    if (total > 0 && (total - 100.0).abs() > 0.01) {
      for (var i = 0; i < weights.length; i++) {
        weights[i] = weights[i].copyWith(weight: (weights[i].weight / total) * 100);
      }
    }

    ref.read(preferenceWeightsProvider(activeStrategy.strategyTypeId).notifier).state = weights;
  }

  void _setMonetary(int index, double newMonetary) {
    final activeStrategy = ref.read(activeStrategyProvider);
    if (activeStrategy == null) return;

    final weights = List<PreferenceWeight>.from(
      ref.read(preferenceWeightsProvider(activeStrategy.strategyTypeId)),
    );

    if (index < 0 || index >= weights.length) return;

    // Clamp to non-negative values
    newMonetary = newMonetary.clamp(0.0, double.infinity);

    // Update the monetary value
    weights[index] = weights[index].copyWith(monetary: newMonetary);

    ref.read(preferenceWeightsProvider(activeStrategy.strategyTypeId).notifier).state = weights;
  }

  double _calculateMonetaryScale(List<PreferenceWeight> weights) {
    if (weights.isEmpty) return 1000.0; // Default scale
    final maxMonetary = weights.map((w) => w.monetary).reduce((a, b) => a > b ? a : b);
    if (maxMonetary <= 0) return 1000.0; // Minimum scale of 1000
    
    // Scale to 110% of maximum value
    return maxMonetary * 1.1;
  }

  double _calculatePercentageScale(List<PreferenceWeight> weights) {
    if (weights.isEmpty) return 100.0; // Default scale
    final maxPercentage = weights.map((w) => w.weight).reduce((a, b) => a > b ? a : b);
    if (maxPercentage <= 0) return 100.0; // Minimum scale of 100
    
    // Scale to 110% of maximum value
    return maxPercentage * 1.1;
  }


  Future<void> _savePreferences() async {
    final activeStrategy = ref.read(activeStrategyProvider);
    if (activeStrategy == null) return;

    final weights = ref.read(preferenceWeightsProvider(activeStrategy.strategyTypeId));
    if (weights.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // Get existing preferences to preserve IDs
      final existingPreferences = await firestoreService.getAllStrategyPreferences(
        activeStrategy.id,
      );

      for (final weight in weights) {
        // Find existing preference or create new
        final existing = existingPreferences.firstWhere(
          (sp) => sp.name == weight.preference.name,
          orElse: () => StrategyPreference(
            id: '',
            strategyId: activeStrategy.id,
            name: weight.preference.name,
            shortLabel: weight.preference.shortLabel,
            description: weight.preference.description,
            relativeWeight: 0,
            monetaryFactorPerYear: 0,
            order: weight.preference.order,
            enabled: weight.preference.enabled,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Convert weight from 0-100 to 0-1 range
        final relativeWeight = weight.weight / 100;

        final preference = existing.copyWith(
          relativeWeight: relativeWeight,
          monetaryFactorPerYear: weight.monetary,
          updatedAt: DateTime.now(),
        );

        if (existing.id.isEmpty) {
          // Create new preference
          await firestoreService.createStrategyPreference(preference);
        } else {
          // Update existing preference
          await firestoreService.updateStrategyPreference(preference);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Value profile saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _showAgent = true);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving preferences: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Load mission budget from current mission
  Future<void> _loadMissionBudget(String strategyId) async {
    try {
      final missionMapAsync = await ref.read(strategyMissionMapProvider(strategyId).future);
      Mission? currentMission;
      
      if (missionMapAsync != null && missionMapAsync.missions.isNotEmpty) {
        // Find the current mission (the one that covers today's date)
        final now = DateTime.now();
        final startDate = missionMapAsync.strategyStartDate ?? now;
        int cumulativeMonths = 0;
        
        for (final mission in missionMapAsync.missions) {
          final missionStart = DateTime(startDate.year, startDate.month + cumulativeMonths, 1);
          final missionEnd = DateTime(startDate.year, startDate.month + cumulativeMonths + mission.durationMonths, 1);
          
          if (now.isAfter(missionStart) && now.isBefore(missionEnd)) {
            currentMission = mission;
            break;
          }
          
          cumulativeMonths += mission.durationMonths;
        }
        
        // If no current mission found, use the first mission
        if (currentMission == null && missionMapAsync.missions.isNotEmpty) {
          currentMission = missionMapAsync.missions.first;
        }
      }

      if (mounted) {
        setState(() {
          _missionBudget = currentMission?.totalAnnualInvestment;
          _missionName = currentMission?.mission;
        });
      }
    } catch (e) {
      debugPrint('Error loading mission budget: $e');
    }
  }

  /// Start a new agent refinement session
  Future<void> _startAgentSession() async {
    final activeStrategy = ref.read(activeStrategyProvider);
    if (activeStrategy == null) return;

    final weights = ref.read(preferenceWeightsProvider(activeStrategy.strategyTypeId));
    if (weights.isEmpty) return;

    setState(() {
      _isAgentProcessing = true;
      _agentFeedback = 'Starting refinement session...';
    });

    try {
      // Mission budget already loaded in _loadPreferences(), calculate actual budget
      
      // Calculate max annual budget from mission budget and percentage
      final maxAnnualBudget = _missionBudget != null 
          ? _missionBudget! * (_budgetPercentage / 100.0)
          : null;

      // Create new session
      final currentWeights = <String, double>{};
      final currentMonetary = <String, double>{};
      for (final w in weights) {
        currentWeights[w.preference.name] = w.weight / 100.0; // Convert to 0.0-1.0
        currentMonetary[w.preference.name] = w.monetary;
      }

      _activeSession = AgentSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        strategyId: activeStrategy.id,
        strategyTypeId: activeStrategy.strategyTypeId,
        startedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        iterationCount: 0,
        isActive: true,
        initialWeights: Map.from(currentWeights),
        initialMonetary: Map.from(currentMonetary),
        currentWeights: Map.from(currentWeights),
        currentMonetary: Map.from(currentMonetary),
        history: [],
        maxAnnualBudget: maxAnnualBudget,
      );

      // Generate initial questions
      await _generateQuestions();
    } catch (e) {
      debugPrint('Error starting agent session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isAgentProcessing = false;
        _agentFeedback = '';
        _activeSession = null;
      });
    }
  }

  /// Generate questions using the AI agent
  Future<void> _generateQuestions() async {
    if (_activeSession == null) return;

    final activeStrategy = ref.read(activeStrategyProvider);
    if (activeStrategy == null) return;

    final weights = ref.read(preferenceWeightsProvider(activeStrategy.strategyTypeId));
    final preferences = weights.map((w) => w.preference).toList();

    setState(() {
      _isAgentProcessing = true;
    });

    try {
      // Get the agent service
      final agentService = await ref.read(valueProfileAgentServiceProvider.future);
      final stabilityCalculator = ref.read(stabilityCalculatorProvider);

      // Calculate current stability
      _stability = stabilityCalculator.calculateStability(
        history: _activeSession!.history,
        currentWeights: _activeSession!.currentWeights,
        currentMonetary: _activeSession!.currentMonetary,
      );

      // Generate questions
      final response = await agentService.generateQuestions(
        preferences: preferences,
        currentWeights: _activeSession!.currentWeights,
        currentMonetary: _activeSession!.currentMonetary,
        history: _activeSession!.history,
        stability: _stability,
        maxAnnualBudget: _activeSession!.maxAnnualBudget,
        missionBudget: _missionBudget,
        missionName: _missionName,
      );

      if (mounted) {
        setState(() {
          _currentQuestions = response.questions;
          _agentFeedback = response.reasoning;
          _isAgentProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating questions: $e');
      if (mounted) {
        setState(() {
          _isAgentProcessing = false;
          _agentFeedback = 'Unable to generate questions. Please try again.';
        });
      }
    }
  }

  /// Submit answers and get refinement
  Future<void> _submitAnswers(List<int> selectedOptions, Map<String, double> sliderValues) async {
    if (_activeSession == null || _currentQuestions.isEmpty) return;

    final activeStrategy = ref.read(activeStrategyProvider);
    if (activeStrategy == null) return;

    final weights = ref.read(preferenceWeightsProvider(activeStrategy.strategyTypeId));
    final preferences = weights.map((w) => w.preference).toList();

    setState(() {
      _isAgentProcessing = true;
    });

    try {
      // Get the agent service
      final agentService = await ref.read(valueProfileAgentServiceProvider.future);
      final stabilityCalculator = ref.read(stabilityCalculatorProvider);

      // Process answers and get refinement
      final refinement = await agentService.processAnswers(
        preferences: preferences,
        questions: _currentQuestions,
        selectedOptionIndices: selectedOptions,
        currentWeights: _activeSession!.currentWeights,
        currentMonetary: _activeSession!.currentMonetary,
        history: _activeSession!.history,
        maxAnnualBudget: _activeSession!.maxAnnualBudget,
      );

      // Create question answer records
      final newAnswers = <QuestionAnswer>[];
      for (int i = 0; i < _currentQuestions.length && i < selectedOptions.length; i++) {
        final question = _currentQuestions[i];
        final optionIndex = selectedOptions[i];
        final selectedOption = optionIndex < question.options.length
            ? question.options[optionIndex]
            : 'Unknown';

        newAnswers.add(QuestionAnswer(
          questionId: question.id,
          questionText: question.questionText,
          questionType: question.type,
          selectedOption: selectedOption,
          optionIndex: optionIndex,
          answeredAt: DateTime.now(),
          weightsBefore: Map.from(_activeSession!.currentWeights),
          weightsAfter: Map.from(refinement.updatedWeights),
          monetaryBefore: Map.from(_activeSession!.currentMonetary),
          monetaryAfter: Map.from(refinement.updatedMonetary),
          stabilityAtAnswer: _stability.overallStability,
          explanation: refinement.explanation,
        ));
      }

      // Update session with new history and values
      _activeSession = _activeSession!.copyWith(
        currentWeights: refinement.updatedWeights,
        currentMonetary: refinement.updatedMonetary,
        history: [..._activeSession!.history, ...newAnswers],
        iterationCount: _activeSession!.iterationCount + 1,
        updatedAt: DateTime.now(),
      );

      // Update UI weights
      final updatedWeights = <PreferenceWeight>[];
      for (final w in weights) {
        final newWeight = refinement.updatedWeights[w.preference.name] ?? (w.weight / 100.0);
        final newMonetary = refinement.updatedMonetary[w.preference.name] ?? w.monetary;
        updatedWeights.add(PreferenceWeight(
          preference: w.preference,
          weight: newWeight * 100.0, // Convert back to 0-100
          monetary: newMonetary,
        ));
      }

      // Normalize weights to sum to 100
      final totalWeight = updatedWeights.fold(0.0, (sum, w) => sum + w.weight);
      if (totalWeight > 0) {
        final normalizedWeights = updatedWeights.map((w) => PreferenceWeight(
          preference: w.preference,
          weight: (w.weight / totalWeight) * 100.0,
          monetary: w.monetary,
        )).toList();
        
        ref.read(preferenceWeightsProvider(activeStrategy.strategyTypeId).notifier).state = 
            normalizedWeights;
      }

      // Calculate new stability
      _stability = stabilityCalculator.calculateStability(
        history: _activeSession!.history,
        currentWeights: _activeSession!.currentWeights,
        currentMonetary: _activeSession!.currentMonetary,
      );

      // Auto-save after refinement
      await _savePreferences();

      // Check if converged or generate more questions
      if (_stability.isConverged) {
        if (mounted) {
          setState(() {
            _agentFeedback = 'Congratulations! Your preferences have converged to a stable configuration. '
                '${refinement.explanation}';
            _currentQuestions = [];
            _isAgentProcessing = false;
          });
        }
      } else {
        // Generate next set of questions
        await _generateQuestions();
      }
    } catch (e) {
      debugPrint('Error processing answers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing answers: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isAgentProcessing = false;
        });
      }
    }
  }

  /// End the agent session
  void _endAgentSession() {
    setState(() {
      _activeSession = null;
      _currentQuestions = [];
      _stability = StabilityMetrics.initial();
      _agentFeedback = '';
      _isAgentProcessing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Refinement session completed!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeStrategy = ref.watch(activeStrategyProvider);
    final selectedPreference = ref.watch(selectedPreferenceProvider);

    if (activeStrategy == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          title: const Text('Value Profile'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No active strategy selected'),
        ),
      );
    }

    final weights = ref.watch(preferenceWeightsProvider(activeStrategy.strategyTypeId));

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          title: const Text('Value Profile'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (weights.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          title: const Text('Value Profile'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No preferences found for this strategy type'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Value Profile'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _savePreferences,
              child: const Text(
                'Next',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.primaryTintLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adjust Your Value Priorities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use the + and - buttons to adjust weights, or double-click values to edit directly. '
                  'Blue bars show relative importance (%), green bars show monetary value (\$/year). '
                  'Click on a label for the full description.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          // Two column layout: Bar Chart and Details
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Bar Chart
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Budget Slider
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildBudgetSlider(),
                      ),
                      
                      // Legend
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: DualBarLegend(),
                      ),
                      
                      // Chart with Y-axis labels
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Y-axis (Percentage)
                            Padding(
                              padding: const EdgeInsets.only(top: 72.0),
                              child: SizedBox(
                                width: 50,
                                height: 300,
                                child: Builder(
                                  builder: (context) {
                                    final percentageMax = _calculatePercentageScale(weights);
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        _buildYAxisLabel('${percentageMax.toStringAsFixed(0)}%', Colors.blue[700]!),
                                        _buildYAxisLabel('${(percentageMax * 0.75).toStringAsFixed(0)}%', Colors.blue[700]!),
                                        _buildYAxisLabel('${(percentageMax * 0.5).toStringAsFixed(0)}%', Colors.blue[700]!),
                                        _buildYAxisLabel('${(percentageMax * 0.25).toStringAsFixed(0)}%', Colors.blue[700]!),
                                        _buildYAxisLabel('0%', Colors.blue[700]!),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            
                            // Bars - Responsive width
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  ...List.generate(weights.length, (index) {
                                    final weight = weights[index];
                                    final monetaryScale = _calculateMonetaryScale(weights);
                                    final percentageScale = _calculatePercentageScale(weights);
                                    return Expanded(
                                      flex: 1,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2),
                                        child: PreferenceDualBar(
                                          weight: weight,
                                          onIncrease: () => _adjustWeight(index, 1),
                                          onDecrease: () => _adjustWeight(index, -1),
                                          onWeightChange: (newWeight) => _setWeight(index, newWeight),
                                          onMonetaryChange: (newMonetary) => _setMonetary(index, newMonetary),
                                          onLabelTap: () {
                                            ref.read(selectedPreferenceProvider.notifier).state =
                                                weight.preference;
                                          },
                                          isSelected: selectedPreference?.id == weight.preference.id,
                                          monetaryScale: monetaryScale,
                                          percentageScale: percentageScale,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            // Right Y-axis (Monetary)
                            Padding(
                              padding: const EdgeInsets.only(top: 72.0),
                              child: SizedBox(
                                width: 60,
                                height: 300,
                                child: Builder(
                                  builder: (context) {
                                    final monetaryMax = _calculateMonetaryScale(weights);
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildYAxisLabel(_formatMonetary(monetaryMax), Colors.green[700]!),
                                        _buildYAxisLabel(_formatMonetary(monetaryMax * 0.75), Colors.green[700]!),
                                        _buildYAxisLabel(_formatMonetary(monetaryMax * 0.5), Colors.green[700]!),
                                        _buildYAxisLabel(_formatMonetary(monetaryMax * 0.25), Colors.green[700]!),
                                        _buildYAxisLabel('\$0', Colors.green[700]!),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Column: Preference Details (25% width)
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(-2, 0),
                        ),
                      ],
                    ),
                    child: _showAgent
                        ? AgentPanel(
                            stability: _stability,
                            feedback: _agentFeedback,
                            questions: _currentQuestions,
                            onSubmitAnswers: _submitAnswers,
                            onStartSession: _startAgentSession,
                            onEndSession: _endAgentSession,
                            isProcessing: _isAgentProcessing,
                            hasActiveSession: _activeSession != null,
                            maxAnnualBudget: _activeSession?.maxAnnualBudget,
                            currentMonetary: _activeSession?.currentMonetary,
                            missionBudget: _missionBudget,
                          )
                        : selectedPreference != null
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedPreference.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryTintLight,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            selectedPreference.shortLabel,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      ref.read(selectedPreferenceProvider.notifier).state = null;
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),
                              const Text(
                                'Description:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                selectedPreference.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Click on a preference label to view its description',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYAxisLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _buildBudgetSlider() {
    final calculatedBudget = _missionBudget != null 
        ? _missionBudget! * (_budgetPercentage / 100.0)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.3),
          width: 1,
        ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Value Preferences Budget',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green[200]!,
                    width: 1,
                  ),
                ),
                child: Text(
                  '${_budgetPercentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Budget amount display
          if (calculatedBudget != null) ...[
            Text(
              '\$${_formatNumber(calculatedBudget.toInt())} per year',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'of \$${_formatNumber(_missionBudget!.toInt())} mission budget',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ] else ...[
            Text(
              'No mission budget set',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create a mission with a budget to enable value preferences allocation',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Slider - always show
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: Colors.grey[300],
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 20,
              ),
            ),
            child: Slider(
              value: _budgetPercentage,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_budgetPercentage.toStringAsFixed(0)}%',
              onChanged: _missionBudget != null ? (value) {
                setState(() {
                  _budgetPercentage = value;
                  // Update active session if exists
                  if (_activeSession != null && _missionBudget != null) {
                    final newBudget = _missionBudget! * (value / 100.0);
                    _activeSession = _activeSession!.copyWith(
                      maxAnnualBudget: newBudget,
                      updatedAt: DateTime.now(),
                    );
                  }
                });
              } : null, // Disable slider if no mission budget
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0%',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '100%',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    // Add thousand separators
    final str = number.toString();
    final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(regex, (Match m) => '${m[1]},');
  }

  String _formatMonetary(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      final kValue = value / 1000;
      // Show decimal if not a whole number of thousands
      if (kValue % 1 == 0) {
        return '\$${kValue.toStringAsFixed(0)}K';
      } else {
        return '\$${kValue.toStringAsFixed(2)}K';
      }
    } else {
      return '\$${value.toStringAsFixed(0)}';
    }
  }
}

class _PreferenceBar extends StatefulWidget {
  final PreferenceWeight weight;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final ValueChanged<double> onWeightChange;
  final VoidCallback onLabelTap;
  final bool isSelected;

  const _PreferenceBar({
    required this.weight,
    required this.onIncrease,
    required this.onDecrease,
    required this.onWeightChange,
    required this.onLabelTap,
    required this.isSelected,
  });

  @override
  State<_PreferenceBar> createState() => _PreferenceBarState();
}

class _PreferenceBarState extends State<_PreferenceBar> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        _saveEdit();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = widget.weight.weight.toStringAsFixed(1);
    });
    _focusNode.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  void _saveEdit() {
    final text = _controller.text.trim();
    final newValue = double.tryParse(text);
    
    if (newValue != null && newValue >= 0 && newValue <= 100) {
      widget.onWeightChange(newValue);
    }
    
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final percentage = widget.weight.weight;
    final barColor = widget.isSelected ? AppTheme.primary : Colors.blue[700]!;
    const maxBarHeight = 300.0;

    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Increase button
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: widget.onIncrease,
            iconSize: 28,
            color: Colors.green[700],
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(height: 8),
          
          // Percentage display (editable on double-click)
          GestureDetector(
            onDoubleTap: _startEditing,
            child: _isEditing
                ? SizedBox(
                    width: 65,
                    height: 28,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        suffixText: '%',
                        suffixStyle: const TextStyle(fontSize: 10),
                      ),
                      onSubmitted: (_) => _saveEdit(),
                      onEditingComplete: _saveEdit,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          
          // Vertical Bar
          SizedBox(
            height: maxBarHeight,
            width: 60,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Background bar
                Container(
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // Filled portion (grows from bottom)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: percentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Decrease button
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: widget.onDecrease,
            iconSize: 28,
            color: Colors.red[700],
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(height: 8),
          
          // Label (clickable)
          InkWell(
            onTap: widget.onLabelTap,
            child: Container(
              width: 80,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppTheme.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: widget.isSelected
                    ? Border.all(color: AppTheme.primary, width: 2)
                    : null,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.weight.preference.shortLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.isSelected ? AppTheme.primary : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
