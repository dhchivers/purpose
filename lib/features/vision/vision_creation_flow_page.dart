import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/gemini_provider.dart';
import 'package:purpose/core/models/vision_creation_session.dart';
import 'package:purpose/core/models/user_vision.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/core/constants/app_constants.dart';

/// Page for creating a vision statement through guided prompts
class VisionCreationFlowPage extends ConsumerStatefulWidget {
  const VisionCreationFlowPage({super.key});

  @override
  ConsumerState<VisionCreationFlowPage> createState() => _VisionCreationFlowPageState();
}

class _VisionCreationFlowPageState extends ConsumerState<VisionCreationFlowPage> {
  VisionCreationSession? _session;
  bool _isLoading = false;
  int _currentStep = 0;

  // Form controllers and state
  int? _selectedTimeframe;
  final TextEditingController _meaningfulChangeController = TextEditingController();
  InfluenceScale? _selectedInfluenceScale;
  final TextEditingController _roleController = TextEditingController();

  // AI generated options
  int? _selectedOptionIndex;
  final TextEditingController _customStatementController = TextEditingController();
  bool _isEditingStatement = false;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  @override
  void dispose() {
    _meaningfulChangeController.dispose();
    _roleController.dispose();
    _customStatementController.dispose();
    super.dispose();
  }

  Future<void> _initializeSession() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    try {
      // Load user's core values
      final firestoreService = ref.read(firestoreServiceProvider);
      final userValues = await firestoreService.getUserValues(user.uid);
      final coreValues = userValues.map((v) => v.statement).toList();

      setState(() {
        _session = VisionCreationSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user.uid,
          startedAt: DateTime.now(),
          purposeStatement: user.purpose, // Load from user profile
          coreValues: coreValues, // Load from user values
        );
      });
    } catch (e) {
      // If we can't load values, proceed with empty list
      setState(() {
        _session = VisionCreationSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user.uid,
          startedAt: DateTime.now(),
          purposeStatement: user.purpose,
          coreValues: [],
        );
      });
    }
  }

  Future<void> _handleNext() async {
    if (_currentStep == 0) {
      // Validate timeframe selection
      if (_selectedTimeframe == null) {
        _showError('Please select a timeframe');
        return;
      }
      
      setState(() {
        _session = _session?.copyWith(timeframeYears: _selectedTimeframe);
        _currentStep++;
      });
    } else if (_currentStep == 1) {
      // Validate meaningful change
      if (_meaningfulChangeController.text.trim().isEmpty) {
        _showError('Please describe the meaningful change');
        return;
      }
      
      setState(() {
        _session = _session?.copyWith(meaningfulChange: _meaningfulChangeController.text.trim());
        _currentStep++;
      });
    } else if (_currentStep == 2) {
      // Validate influence scale
      if (_selectedInfluenceScale == null) {
        _showError('Please select your influence scale');
        return;
      }
      
      setState(() {
        _session = _session?.copyWith(influenceScale: _selectedInfluenceScale);
        _currentStep++;
      });
    } else if (_currentStep == 3) {
      // Validate role description
      if (_roleController.text.trim().isEmpty) {
        _showError('Please describe your role');
        return;
      }
      
      setState(() {
        _session = _session?.copyWith(roleDescription: _roleController.text.trim());
      });
      
      // Save session and generate vision statements
      await _generateVisionStatements();
    } else if (_currentStep == 4) {
      // Final selection - validate and save
      await _confirmVisionSelection();
    }
  }

  Future<void> _generateVisionStatements() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final geminiService = await ref.read(geminiServiceProvider.future);
      final firestoreService = ref.read(firestoreServiceProvider);

      // Generate vision statements
      final optionsData = await geminiService.generateVisionStatements(
        timeframeYears: _session!.timeframeYears!,
        purposeStatement: _session!.purposeStatement ?? '',
        coreValues: _session!.coreValues ?? [],
        meaningfulChange: _session!.meaningfulChange!,
        influenceScale: _session!.influenceScale!.name,
        roleDescription: _session!.roleDescription!,
      );

      // Convert to VisionOption objects
      final options = optionsData.map((o) {
        return VisionOption(
          label: o['label'] as String,
          statement: o['statement'] as String,
        );
      }).toList();

      setState(() {
        _session = _session?.copyWith(visionOptions: options);
        _currentStep++;
        _isLoading = false;
      });

      // Save session
      await firestoreService.saveVisionCreationSession(_session!);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        _showError('Error generating vision statements: $e');
      }
    }
  }

  Future<void> _confirmVisionSelection() async {
    if (_selectedOptionIndex == null) {
      _showError('Please select a vision statement');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final selectedOption = _session!.visionOptions![_selectedOptionIndex!];
      
      final finalStatement = _isEditingStatement && _customStatementController.text.trim().isNotEmpty
          ? _customStatementController.text.trim()
          : selectedOption.statement;

      // Create UserVision
      final userVision = UserVision(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _session!.userId,
        timeframeYears: _session!.timeframeYears!,
        visionStatement: finalStatement,
        sessionId: _session!.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save user vision
      await firestoreService.saveUserVision(userVision);

      // Update session as completed
      final completedSession = _session!.copyWith(
        completedAt: DateTime.now(),
        selectedOptionIndex: _selectedOptionIndex,
        customStatement: _isEditingStatement ? _customStatementController.text.trim() : null,
      );
      await firestoreService.saveVisionCreationSession(completedSession);

      // Invalidate user cache to refresh dashboard
      ref.invalidate(currentUserProvider);

      if (mounted) {
        // Navigate back to home with success message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vision created successfully!'),
                backgroundColor: AppTheme.success,
              ),
            );
            context.go(AppConstants.homeRoute);
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        _showError('Error saving vision: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Vision Creation'),
        content: const Text(
          'Are you sure you want to cancel? Your progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue Creating'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.go(AppConstants.homeRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: Text('Create Vision - Step ${_currentStep + 1} of 5'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmCancel,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildStepContent(),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    if (_currentStep > 0 && _currentStep < 4)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _currentStep--;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppTheme.primary),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_currentStep > 0 && _currentStep < 4) const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(_currentStep == 4 ? 'Complete' : 'Next'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildTimeframeStep();
      case 1:
        return _buildMeaningfulChangeStep();
      case 2:
        return _buildInfluenceScaleStep();
      case 3:
        return _buildRoleStep();
      case 4:
        return _buildFinalSelectionStep();
      default:
        return const Center(child: Text('Invalid step'));
    }
  }

  Widget _buildTimeframeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Your Timeframe',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.graphite,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'How far into the future are you looking?',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.grayMedium,
            ),
          ),
          const SizedBox(height: 32),
          _buildTimeframeCard(
            years: 5,
            title: '5 Years',
            description: 'School age and early career',
            guidance: 'Focus on skill development, foundational experiences, and early impact.',
          ),
          const SizedBox(height: 16),
          _buildTimeframeCard(
            years: 10,
            title: '10 Years',
            description: 'Early to mid-career',
            guidance: 'Focus on establishing expertise, building influence, and scaling impact.',
          ),
          const SizedBox(height: 16),
          _buildTimeframeCard(
            years: 15,
            title: '15 Years',
            description: 'Mid to late career',
            guidance: 'Focus on systemic change, legacy building, and transformative impact.',
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeCard({
    required int years,
    required String title,
    required String description,
    required String guidance,
  }) {
    final isSelected = _selectedTimeframe == years;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : AppTheme.grayLight,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTimeframe = years;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryTint : AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color: isSelected ? AppTheme.primary : AppTheme.grayMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppTheme.primary : AppTheme.graphite,
                          ),
                        ),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.grayMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                guidance,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.grayMedium,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeaningfulChangeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meaningful Change',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.graphite,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'In ${_session!.timeframeYears} years, what meaningful change exists because you acted on your purpose?',
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.grayMedium,
              height: 1.5,
            ),
          ),
          if (_session!.purposeStatement != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryTintLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryTint),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Purpose',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _session!.purposeStatement!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.graphite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _meaningfulChangeController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Describe the changed conditions that exist...',
              hintStyle: const TextStyle(color: AppTheme.grayMedium),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.grayLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryTintLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Focus on changed conditions, not your activities. What\'s different in the world? How do people/systems operate differently?',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.graphite,
                      height: 1.5,
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

  Widget _buildInfluenceScaleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scale of Influence',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.graphite,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'In the ${_session!.timeframeYears}-year timeframe, are you primarily influencing:',
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.grayMedium,
            ),
          ),
          const SizedBox(height: 32),
          _buildInfluenceScaleCard(
            scale: InfluenceScale.individuals,
            icon: Icons.person_outline,
            title: 'Individuals',
            description: 'Direct impact on people through relationships, coaching, or one-on-one interactions.',
          ),
          const SizedBox(height: 16),
          _buildInfluenceScaleCard(
            scale: InfluenceScale.organizations,
            icon: Icons.business_outlined,
            title: 'Organizations',
            description: 'Impact on teams, companies, or groups through leadership, culture, or collaboration.',
          ),
          const SizedBox(height: 16),
          _buildInfluenceScaleCard(
            scale: InfluenceScale.institutions,
            icon: Icons.account_balance_outlined,
            title: 'Institutions',
            description: 'Impact on established entities like schools, governments, or major organizations.',
          ),
          const SizedBox(height: 16),
          _buildInfluenceScaleCard(
            scale: InfluenceScale.systems,
            icon: Icons.hub_outlined,
            title: 'Broader Systems',
            description: 'Impact on interconnected systems, industries, or societal structures.',
          ),
        ],
      ),
    );
  }

  Widget _buildInfluenceScaleCard({
    required InfluenceScale scale,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isSelected = _selectedInfluenceScale == scale;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : AppTheme.grayLight,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedInfluenceScale = scale;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryTint : AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppTheme.primary : AppTheme.grayMedium,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppTheme.primary : AppTheme.graphite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.grayMedium,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Role',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.graphite,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'What role are you playing in bringing about this change?',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.grayMedium,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _roleController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Describe your role in creating this change...',
              hintStyle: const TextStyle(color: AppTheme.grayMedium),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.grayLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Examples of roles:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.graphite,
            ),
          ),
          const SizedBox(height: 12),
          _buildExampleChip('Catalyst - Initiating and sparking change'),
          const SizedBox(height: 8),
          _buildExampleChip('Builder - Creating new structures or systems'),
          const SizedBox(height: 8),
          _buildExampleChip('Connector - Bridging people, ideas, or resources'),
          const SizedBox(height: 8),
          _buildExampleChip('Educator - Teaching, training, or developing others'),
          const SizedBox(height: 8),
          _buildExampleChip('Advocate - Championing causes or perspectives'),
          const SizedBox(height: 8),
          _buildExampleChip('Innovator - Pioneering new approaches or solutions'),
        ],
      ),
    );
  }

  Widget _buildExampleChip(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryTintLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryTint),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.graphite,
        ),
      ),
    );
  }

  Widget _buildFinalSelectionStep() {
    if (_session?.visionOptions == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Your Vision',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.graphite,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select the vision statement that resonates most with you. You can edit it before finalizing.',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.grayMedium,
            ),
          ),
          const SizedBox(height: 24),
          ..._session!.visionOptions!.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildVisionOptionCard(index, option),
            );
          }),
          if (_selectedOptionIndex != null) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: AppTheme.primaryTintLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.primaryTint),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Selected Vision',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isEditingStatement = !_isEditingStatement;
                              if (_isEditingStatement) {
                                _customStatementController.text =
                                    _session!.visionOptions![_selectedOptionIndex!].statement;
                              }
                            });
                          },
                          icon: Icon(
                            _isEditingStatement ? Icons.close : Icons.edit,
                            size: 18,
                          ),
                          label: Text(_isEditingStatement ? 'Cancel' : 'Edit'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isEditingStatement)
                      TextField(
                        controller: _customStatementController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      )
                    else
                      Text(
                        _session!.visionOptions![_selectedOptionIndex!].statement,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppTheme.graphite,
                          height: 1.6,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisionOptionCard(int index, VisionOption option) {
    final isSelected = _selectedOptionIndex == index;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : AppTheme.grayLight,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedOptionIndex = index;
            _isEditingStatement = false;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppTheme.primary : AppTheme.graphite,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                option.statement,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.graphite,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
