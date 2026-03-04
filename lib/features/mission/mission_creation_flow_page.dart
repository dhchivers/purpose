import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/gemini_provider.dart';
import 'package:purpose/core/services/strategy_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/models/mission_creation_session.dart';
import 'package:purpose/core/models/mission_map.dart';
import 'package:purpose/core/models/mission_document.dart';

/// Page for creating a mission map through guided prompts
class MissionCreationFlowPage extends ConsumerStatefulWidget {
  const MissionCreationFlowPage({super.key});

  @override
  ConsumerState<MissionCreationFlowPage> createState() => _MissionCreationFlowPageState();
}

class _MissionCreationFlowPageState extends ConsumerState<MissionCreationFlowPage> {
  MissionCreationSession? _session;
  bool _isLoading = false;
  int _currentStep = 0;

  // Step 1: Current State controllers
  final TextEditingController _currentBuildingController = TextEditingController();
  final TextEditingController _currentScaleController = TextEditingController();
  final TextEditingController _currentAuthorityController = TextEditingController();

  // Step 2: Vision State controllers
  final TextEditingController _visionInfluenceScaleController = TextEditingController();
  final TextEditingController _visionEnvironmentController = TextEditingController();
  final TextEditingController _visionResponsibilityController = TextEditingController();
  final TextEditingController _visionMeasurableChangeController = TextEditingController();

  // Step 3: Constraints
  List<String> _selectedConstraintValues = [];
  final TextEditingController _nonNegotiableCommitmentsController = TextEditingController();
  String? _selectedRiskTolerance;

  // AI generated missions
  List<Mission>? _generatedMissions;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  @override
  void dispose() {
    _currentBuildingController.dispose();
    _currentScaleController.dispose();
    _currentAuthorityController.dispose();
    _visionInfluenceScaleController.dispose();
    _visionEnvironmentController.dispose();
    _visionResponsibilityController.dispose();
    _visionMeasurableChangeController.dispose();
    _nonNegotiableCommitmentsController.dispose();
    super.dispose();
  }

  Future<void> _initializeSession() async {
    final user = ref.read(currentUserProvider).value;
    final activeStrategy = ref.read(activeStrategyProvider);
    
    if (user == null || activeStrategy == null) {
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

    try {
      setState(() => _isLoading = true);
      
      // Load strategy's values and vision
      final values = await ref.read(strategyValuesProvider(activeStrategy.id).future);
      final coreValues = values.map((v) => v.statement).toList();
      final vision = await ref.read(strategyVisionProvider(activeStrategy.id).future);

      setState(() {
        _session = MissionCreationSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user.uid,
          strategyId: activeStrategy.id,
          startedAt: DateTime.now(),
          purposeStatement: activeStrategy.purpose,
          coreValues: coreValues,
          visionStatement: vision?.visionStatement,
          visionTimeframeYears: vision?.timeframeYears,
        );
        _isLoading = false;
      });

      // Pre-populate constraint values with all strategy values
      _selectedConstraintValues = List.from(coreValues);
    } catch (e) {
      setState(() {
        _session = MissionCreationSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user.uid,
          strategyId: activeStrategy.id,
          startedAt: DateTime.now(),
          purposeStatement: activeStrategy.purpose,
          coreValues: [],
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _handleNext() async {
    if (_currentStep == 0) {
      // Step 1: Validate current state
      if (_currentBuildingController.text.trim().isEmpty ||
          _currentScaleController.text.trim().isEmpty ||
          _currentAuthorityController.text.trim().isEmpty) {
        _showError('Please answer all questions about your current state');
        return;
      }
      
      setState(() {
        _session = _session?.copyWith(
          currentBuilding: _currentBuildingController.text.trim(),
          currentScale: _currentScaleController.text.trim(),
          currentAuthority: _currentAuthorityController.text.trim(),
        );
        _currentStep++;
      });
    } else if (_currentStep == 1) {
      // Step 2: Validate vision state
      if (_visionInfluenceScaleController.text.trim().isEmpty ||
          _visionEnvironmentController.text.trim().isEmpty ||
          _visionResponsibilityController.text.trim().isEmpty ||
          _visionMeasurableChangeController.text.trim().isEmpty) {
        _showError('Please answer all questions about your vision state');
        return;
      }
      
      setState(() {
        _session = _session?.copyWith(
          visionInfluenceScale: _visionInfluenceScaleController.text.trim(),
          visionEnvironment: _visionEnvironmentController.text.trim(),
          visionResponsibility: _visionResponsibilityController.text.trim(),
          visionMeasurableChange: _visionMeasurableChangeController.text.trim(),
        );
        _currentStep++;
      });
    } else if (_currentStep == 2) {
      // Step 3: Validate constraints
      if (_selectedConstraintValues.isEmpty) {
        _showError('Please select at least one core value that cannot be violated');
        return;
      }
      if (_nonNegotiableCommitmentsController.text.trim().isEmpty) {
        _showError('Please describe your non-negotiable commitments');
        return;
      }
      if (_selectedRiskTolerance == null) {
        _showError('Please select your risk tolerance');
        return;
      }
      
      setState(() {
        _session = _session?.copyWith(
          constraintValues: _selectedConstraintValues,
          nonNegotiableCommitments: _nonNegotiableCommitmentsController.text.trim(),
          riskTolerance: _selectedRiskTolerance,
        );
      });
      
      // Generate mission map
      await _generateMissionMap();
    } else if (_currentStep == 3) {
      // Final step: Save mission map
      await _saveMissionMap();
    }
  }

  Future<void> _generateMissionMap() async {
    setState(() {
      _isLoading = true;
      _currentStep++;
    });

    try {
      final geminiService = await ref.read(geminiServiceProvider.future);
      final firestoreService = ref.read(firestoreServiceProvider);

      // Generate mission map
      final missionsData = await geminiService.generateMissionMap(
        purposeStatement: _session!.purposeStatement ?? '',
        coreValues: _session!.coreValues ?? [],
        visionStatement: _session!.visionStatement ?? '',
        visionTimeframeYears: _session!.visionTimeframeYears ?? 10,
        currentBuilding: _session!.currentBuilding!,
        currentScale: _session!.currentScale!,
        currentAuthority: _session!.currentAuthority!,
        visionInfluenceScale: _session!.visionInfluenceScale!,
        visionEnvironment: _session!.visionEnvironment!,
        visionResponsibility: _session!.visionResponsibility!,
        visionMeasurableChange: _session!.visionMeasurableChange!,
        constraintValues: _session!.constraintValues!,
        nonNegotiableCommitments: _session!.nonNegotiableCommitments!,
        riskTolerance: _session!.riskTolerance!,
      );

      // Parse missions with risk level from risk_or_value_guardrail
      final missions = missionsData.map((mData) {
        // Extract risk level from risk_or_value_guardrail field
        final riskGuardrail = mData['risk_or_value_guardrail'] as String? ?? '';
        RiskLevel? riskLevel;
        if (riskGuardrail.toLowerCase().contains('low')) {
          riskLevel = RiskLevel.low;
        } else if (riskGuardrail.toLowerCase().contains('high')) {
          riskLevel = RiskLevel.high;
        } else if (riskGuardrail.toLowerCase().contains('medium')) {
          riskLevel = RiskLevel.medium;
        }

        return Mission(
          mission: mData['mission'] as String,
          missionSequence: mData['mission_sequence'] as String,
          focus: mData['focus'] as String,
          structuralShift: mData['structural_shift'] as String,
          capabilityRequired: mData['capability_required'] as String,
          riskOrValueGuardrail: riskGuardrail,
          timeHorizon: mData['time_horizon'] as String,
          riskLevel: riskLevel,
        );
      }).toList();

      setState(() {
        _generatedMissions = missions;
        _session = _session?.copyWith(
          missionMap: missions,
          completedAt: DateTime.now(),
        );
        _isLoading = false;
      });

      // Save session
      await firestoreService.saveMissionCreationSession(_session!);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to generate mission map: $e');
    }
  }

  Future<void> _saveMissionMap() async {
    if (_generatedMissions == null || _generatedMissions!.isEmpty) {
      _showError('No missions to save');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');

      final firestoreService = ref.read(firestoreServiceProvider);
      
      final now = DateTime.now();
      final missionMapId = now.millisecondsSinceEpoch.toString();

      // Create MissionMap (metadata only - no embedded missions)
      final missionMap = MissionMap(
        id: missionMapId,
        strategyId: _session!.strategyId,
        sessionId: _session!.id,
        currentMissionIndex: 0, // Start at first mission
        totalMissions: _generatedMissions!.length,
        strategyStartDate: null, // User can set this later
        createdAt: now,
        updatedAt: now,
      );

      // Save mission map first
      await firestoreService.saveMissionMap(missionMap);

      // Create and save individual mission documents
      for (int i = 0; i < _generatedMissions!.length; i++) {
        final mission = _generatedMissions![i];
        final missionId = '${missionMapId}_$i';
        final missionDoc = MissionDocument.fromMission(
          id: missionId,
          missionMapId: missionMapId,
          strategyId: _session!.strategyId,
          sequenceNumber: i,
          mission: mission,
        );
        await firestoreService.saveMissionDocument(missionDoc);
      }

      // Invalidate user cache to refresh dashboard
      ref.invalidate(currentUserProvider);

      if (mounted) {
        // Navigate to mission map page
        context.go('/mission');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to save mission map: $e');
    }
  }

  void _handleBack() {
    if (_currentStep > 0 && _currentStep < 3) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null || _isLoading && _currentStep == 0) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Mission Map'),
        leading: _currentStep < 3 && _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBack,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  context.go('/');
                },
                tooltip: 'Back to Home',
              ),
      ),
      body: _buildStepContent(),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildCurrentStateStep();
      case 1:
        return _buildVisionStateStep();
      case 2:
        return _buildConstraintsStep();
      case 3:
        return _buildMissionMapDisplay();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCurrentStateStep() {
    return _buildStepContainer(
      title: 'Step 1: Current Mission State',
      subtitle: 'Tell us about where you are now',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionCard(
            question: '1. What are you currently building or leading?',
            hint: 'e.g., A consulting practice, a nonprofit program, a community initiative...',
            controller: _currentBuildingController,
          ),
          const SizedBox(height: 24),
          _buildQuestionCard(
            question: '2. What scale are you operating at?',
            hint: 'e.g., Working with 5-10 clients locally, Managing a team of 20, Operating in 3 cities...',
            controller: _currentScaleController,
          ),
          const SizedBox(height: 24),
          _buildQuestionCard(
            question: '3. What authority do you currently hold?',
            hint: 'e.g., Solo practitioner with advisory role, Director with budget authority, Founder with full control...',
            controller: _currentAuthorityController,
          ),
        ],
      ),
    );
  }

  Widget _buildVisionStateStep() {
    return _buildStepContainer(
      title: 'Step 2: Vision State',
      subtitle: 'Describe where you want to be in ${_session?.visionTimeframeYears ?? 10} years',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionCard(
            question: '1. What scale of influence will you have?',
            hint: 'e.g., Regional, National, Global, Industry-wide...',
            controller: _visionInfluenceScaleController,
          ),
          const SizedBox(height: 24),
          _buildQuestionCard(
            question: '2. What kind of environment will you operate in?',
            hint: 'e.g., Leading a network of organizations, Running a scaled institution, Influencing policy...',
            controller: _visionEnvironmentController,
          ),
          const SizedBox(height: 24),
          _buildQuestionCard(
            question: '3. What level of responsibility will you hold?',
            hint: 'e.g., CEO of multi-million dollar org, Advisor to national leaders, Founder of movement...',
            controller: _visionResponsibilityController,
          ),
          const SizedBox(height: 24),
          _buildQuestionCard(
            question: '4. What measurable change will exist?',
            hint: 'e.g., 100+ communities using our framework, 50,000 people directly impacted, Policy adopted in 10 states...',
            controller: _visionMeasurableChangeController,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildConstraintsStep() {
    final availableValues = _session?.coreValues ?? [];
    
    return _buildStepContainer(
      title: 'Step 3: Constraints & Commitments',
      subtitle: 'Define your boundaries and risk tolerance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Values that cannot be violated
          const Text(
            '1. Select core values that cannot be violated',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0A0E27),
            ),
          ),
          const SizedBox(height: 12),
          if (availableValues.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'You haven\'t defined any core values yet. We\'ll proceed without value constraints.',
                style: TextStyle(color: Colors.orange),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableValues.map((value) {
                final isSelected = _selectedConstraintValues.contains(value);
                return FilterChip(
                  label: Text(value),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedConstraintValues.add(value);
                      } else {
                        _selectedConstraintValues.remove(value);
                      }
                    });
                  },
                  selectedColor: const Color(0xFF1E6BFF).withOpacity(0.2),
                  checkmarkColor: const Color(0xFF1E6BFF),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),

          // Non-negotiable commitments
          _buildQuestionCard(
            question: '2. What are your non-negotiable commitments?',
            hint: 'e.g., Family time on weekends, No more than 50% travel, Must maintain financial stability...',
            controller: _nonNegotiableCommitmentsController,
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // Risk tolerance
          const Text(
            '3. What is your risk tolerance?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0A0E27),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildRiskToleranceOption(
                'Conservative',
                'Prefer proven approaches, steady growth, and financial security',
              ),
              _buildRiskToleranceOption(
                'Moderate',
                'Willing to take calculated risks with backup plans',
              ),
              _buildRiskToleranceOption(
                'Aggressive',
                'Comfortable with high-risk, high-reward opportunities',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskToleranceOption(String value, String description) {
    final isSelected = _selectedRiskTolerance == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRiskTolerance = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF1E6BFF).withOpacity(0.1)
              : Colors.white,
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF1E6BFF)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected 
                  ? const Color(0xFF1E6BFF)
                  : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected 
                          ? const Color(0xFF1E6BFF)
                          : const Color(0xFF0A0E27),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionMapDisplay() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              'Analyzing your mission journey...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A0E27),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mapping the path from current state to vision',
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF0A0E27).withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (_generatedMissions == null || _generatedMissions!.isEmpty) {
      return Center(
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
              'Failed to generate mission map',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentStep = 2;
                });
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Mission Map',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A0E27),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A strategic path from your current state to your vision',
            style: TextStyle(
              fontSize: 16,
              color: const Color(0xFF0A0E27).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),

          // Mission cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _generatedMissions!.length,
            separatorBuilder: (context, index) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final mission = _generatedMissions![index];
              return _buildMissionCard(mission, index);
            },
          ),

          const SizedBox(height: 32),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _currentStep = 2;
                    _generatedMissions = null;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerate'),
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveMissionMap,
                icon: const Icon(Icons.check),
                label: const Text('Save Mission Map'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard(Mission mission, int index) {
    final riskColor = _getRiskColor(mission.riskLevel);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E6BFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E6BFF),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.mission,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A0E27),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: const Color(0xFF0A0E27).withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mission.timeHorizon,
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF0A0E27).withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: riskColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getRiskLabel(mission.riskLevel),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: riskColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Focus
          _buildMissionDetailSection(
            'Focus',
            mission.focus,
            Icons.center_focus_strong,
          ),
          const SizedBox(height: 16),

          // Structural Shift
          _buildMissionDetailSection(
            'Structural Shift',
            mission.structuralShift,
            Icons.transform,
          ),
          const SizedBox(height: 16),

          // Capability Required
          _buildMissionDetailSection(
            'Capability Required',
            mission.capabilityRequired,
            Icons.psychology,
          ),
          const SizedBox(height: 16),

          // Risk & Value Guardrails
          _buildMissionDetailSection(
            'Risk & Value Guardrails',
            mission.riskOrValueGuardrail,
            Icons.security,
          ),
        ],
      ),
    );
  }

  Widget _buildMissionDetailSection(String label, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: const Color(0xFF1E6BFF),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E6BFF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF374151),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Color _getRiskColor(RiskLevel? level) {
    switch (level) {
      case RiskLevel.low:
        return Colors.green;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.high:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getRiskLabel(RiskLevel? level) {
    switch (level) {
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.medium:
        return 'Medium Risk';
      case RiskLevel.high:
        return 'High Risk';
      default:
        return 'Unknown Risk';
    }
  }

  Widget _buildStepContainer({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A0E27),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: const Color(0xFF0A0E27).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          child,
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleNext,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Continue',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({
    required String question,
    required String hint,
    required TextEditingController controller,
    int maxLines = 3,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0A0E27),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: const Color(0xFF0A0E27).withOpacity(0.4),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF1E6BFF),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
