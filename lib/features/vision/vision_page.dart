import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/gemini_provider.dart';
import 'package:purpose/core/services/strategy_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/models/user_vision.dart';
import 'package:purpose/core/models/vision_creation_session.dart';
import 'package:purpose/core/models/strategy_type.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/core/constants/app_constants.dart';
import 'package:purpose/features/admin/admin_strategy_types_page.dart';

/// Provider for user vision
final userVisionProvider = FutureProvider.autoDispose<UserVision?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return null;
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserVision(user.uid);
});

/// Page displaying user's vision with editing capabilities
class VisionPage extends ConsumerStatefulWidget {
  const VisionPage({super.key});

  @override
  ConsumerState<VisionPage> createState() => _VisionPageState();
}

class _VisionPageState extends ConsumerState<VisionPage> {
  bool _isEditingVision = false;
  bool _isEditingQuestions = false;
  bool _isRegenerating = false;
  bool _isSaving = false;
  
  final TextEditingController _visionController = TextEditingController();
  final TextEditingController _meaningfulChangeController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  
  int? _editTimeframe;
  InfluenceScale? _editInfluenceScale;
  
  VisionCreationSession? _session;

  @override
  void dispose() {
    _visionController.dispose();
    _meaningfulChangeController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _loadSession(String sessionId) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final session = await firestoreService.getVisionCreationSession(sessionId);
      if (mounted) {
        setState(() {
          _session = session;
          if (session != null) {
            _meaningfulChangeController.text = session.meaningfulChange ?? '';
            _roleController.text = session.roleDescription ?? '';
            _editTimeframe = session.timeframeYears;
            _editInfluenceScale = session.influenceScale;
          }
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error loading vision session: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading session: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveVisionStatement(UserVision vision) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final updatedVision = vision.copyWith(
        visionStatement: _visionController.text.trim(),
        updatedAt: DateTime.now(),
      );
      
      await firestoreService.updateUserVision(updatedVision);
      
      // Invalidate caches
      ref.invalidate(strategyVisionStreamProvider(updatedVision.strategyId));
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        setState(() {
          _isEditingVision = false;
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vision updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error saving vision: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving vision: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _regenerateVision(UserVision vision) async {
    if (_session == null) return;

    setState(() {
      _isRegenerating = true;
    });

    try {
      final geminiService = await ref.read(geminiServiceProvider.future);
      final firestoreService = ref.read(firestoreServiceProvider);

      // Generate new vision statements with updated inputs
      final optionsData = await geminiService.generateVisionStatements(
        timeframeYears: _editTimeframe ?? _session!.timeframeYears!,
        purposeStatement: _session!.purposeStatement ?? '',
        coreValues: _session!.coreValues ?? [],
        meaningfulChange: _meaningfulChangeController.text.trim(),
        influenceScale: (_editInfluenceScale ?? _session!.influenceScale!).name,
        roleDescription: _roleController.text.trim(),
      );

      // Convert to VisionOption objects
      final options = optionsData.map((o) {
        return VisionOption(
          label: o['label'] as String,
          statement: o['statement'] as String,
        );
      }).toList();

      // Update session with new options
      final updatedSession = _session!.copyWith(
        timeframeYears: _editTimeframe ?? _session!.timeframeYears,
        meaningfulChange: _meaningfulChangeController.text.trim(),
        influenceScale: _editInfluenceScale ?? _session!.influenceScale,
        roleDescription: _roleController.text.trim(),
        visionOptions: options,
      );
      
      await firestoreService.saveVisionCreationSession(updatedSession);
      
      if (mounted) {
        setState(() {
          _session = updatedSession;
          _isRegenerating = false;
          _isEditingQuestions = false;
        });

        // Show dialog to select new vision
        _showVisionSelectionDialog(vision, options);
      }
    } catch (e, stackTrace) {
      print('❌ Error regenerating vision: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isRegenerating = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error regenerating vision: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showVisionSelectionDialog(UserVision currentVision, List<VisionOption> options) {
    int? selectedIndex;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select New Vision'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final isSelected = selectedIndex == index;
                
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primary : AppTheme.grayLight,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      setDialogState(() {
                        selectedIndex = index;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppTheme.primary : AppTheme.graphite,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            option.statement,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.graphite,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedIndex == null
                  ? null
                  : () async {
                      Navigator.of(context).pop();
                      await _applyNewVision(currentVision, options[selectedIndex!].statement);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyNewVision(UserVision currentVision, String newStatement) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final updatedVision = currentVision.copyWith(
        visionStatement: newStatement,
        updatedAt: DateTime.now(),
      );
      
      await firestoreService.updateUserVision(updatedVision);
      
      // Invalidate caches
      ref.invalidate(userVisionProvider);
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vision updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error applying vision: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying vision: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final user = ref.read(currentUserProvider).value;
    final vision = await ref.read(userVisionProvider.future);
    
    if (user == null || vision == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vision'),
        content: const Text(
          'Are you sure you want to delete your vision? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final firestoreService = ref.read(firestoreServiceProvider);
        await firestoreService.deleteUserVision(vision.id, user.uid);
        
        // Invalidate caches
        ref.invalidate(userVisionProvider);
        ref.invalidate(currentUserProvider);
        
        if (mounted) {
          context.go(AppConstants.homeRoute);
        }
      } catch (e, stackTrace) {
        print('❌ Error deleting vision: $e');
        print('Stack trace: $stackTrace');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting vision: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  String _getInfluenceScaleLabel(InfluenceScale scale) {
    switch (scale) {
      case InfluenceScale.individuals:
        return 'Individuals';
      case InfluenceScale.organizations:
        return 'Organizations';
      case InfluenceScale.institutions:
        return 'Institutions';
      case InfluenceScale.systems:
        return 'Broader Systems';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeStrategy = ref.watch(activeStrategyProvider);
    final strategyTypesAsync = ref.watch(strategyTypesStreamProvider);

    if (activeStrategy == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.graphite,
          foregroundColor: Colors.white,
          title: const Text('Vision'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppConstants.homeRoute),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No active strategy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please create or select a strategy from the dashboard.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      );
    }

    final visionAsync = ref.watch(strategyVisionStreamProvider(activeStrategy.id));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.graphite,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Text(activeStrategy.name),
            const SizedBox(width: 12),
            strategyTypesAsync.when(
              data: (types) {
                final strategyType = types.firstWhere(
                  (type) => type.id == activeStrategy.strategyTypeId,
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
                return Chip(
                  label: Text(
                    strategyType.name,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: Color(strategyType.color),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppConstants.homeRoute),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
            tooltip: 'Delete Vision',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vision',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: visionAsync.when(
              data: (vision) {
                if (vision == null) {
                  return Center(
                    child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.visibility_off_outlined,
                    size: 64,
                    color: AppTheme.grayMedium,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No vision created yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.graphite,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your vision to see it here',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.grayMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/vision/create'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Create Vision'),
                  ),
                ],
              ),
            );
          }

          // Load session data if not already loaded
          if (_session == null && vision.sessionId != null) {
            _loadSession(vision.sessionId!);
          }

          // Set initial vision text if editing for first time
          if (_isEditingVision && _visionController.text.isEmpty) {
            _visionController.text = vision.visionStatement;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vision Statement Section
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.primaryTint),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.visibility,
                              color: AppTheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${activeStrategy.name} - Vision',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            if (!_isEditingVision)
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _isEditingVision = true;
                                    _visionController.text = vision.visionStatement;
                                  });
                                },
                                color: AppTheme.primary,
                                tooltip: 'Edit Vision',
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isEditingVision)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _visionController,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _isSaving
                                          ? null
                                          : () {
                                              setState(() {
                                                _isEditingVision = false;
                                                _visionController.clear();
                                              });
                                            },
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isSaving
                                          ? null
                                          : () => _saveVisionStatement(vision),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: _isSaving
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Save'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Text(
                            vision.visionStatement,
                            style: const TextStyle(
                              fontSize: 18,
                              color: AppTheme.graphite,
                              height: 1.6,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 16,
                              color: AppTheme.grayMedium,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${vision.timeframeYears}-year vision',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.grayMedium,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Updated ${_formatDate(vision.updatedAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.grayMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Creation Context Section
                if (_session != null) ...[
                  Row(
                    children: [
                      const Text(
                        'Vision Creation Context',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.graphite,
                        ),
                      ),
                      const Spacer(),
                      if (!_isEditingQuestions)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isEditingQuestions = true;
                            });
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit & Regenerate'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Questions Cards
                  _buildContextCard(
                    'Timeframe',
                    Icons.calendar_today,
                    _isEditingQuestions
                        ? _buildTimeframeSelector()
                        : Text(
                            '${_session!.timeframeYears} years',
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.graphite,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),

                  _buildContextCard(
                    'Meaningful Change',
                    Icons.auto_awesome,
                    _isEditingQuestions
                        ? TextField(
                            controller: _meaningfulChangeController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          )
                        : Text(
                            _session!.meaningfulChange ?? '',
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.graphite,
                              height: 1.5,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),

                  _buildContextCard(
                    'Influence Scale',
                    Icons.groups,
                    _isEditingQuestions
                        ? _buildInfluenceScaleSelector()
                        : Text(
                            _getInfluenceScaleLabel(_session!.influenceScale!),
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.graphite,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),

                  _buildContextCard(
                    'Your Role',
                    Icons.person_outline,
                    _isEditingQuestions
                        ? TextField(
                            controller: _roleController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          )
                        : Text(
                            _session!.roleDescription ?? '',
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.graphite,
                              height: 1.5,
                            ),
                          ),
                  ),

                  if (_isEditingQuestions) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isRegenerating
                                ? null
                                : () {
                                    setState(() {
                                      _isEditingQuestions = false;
                                      // Reset to original values
                                      _meaningfulChangeController.text =
                                          _session!.meaningfulChange ?? '';
                                      _roleController.text =
                                          _session!.roleDescription ?? '';
                                      _editTimeframe = _session!.timeframeYears;
                                      _editInfluenceScale = _session!.influenceScale;
                                    });
                                  },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isRegenerating
                                ? null
                                : () => _regenerateVision(vision),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: _isRegenerating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Regenerate Vision'),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // AI Generated Options (if available)
                  if (_session!.visionOptions != null &&
                      _session!.visionOptions!.isNotEmpty) ...[
                    const Text(
                      'AI-Generated Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.graphite,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._session!.visionOptions!.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      final isSelected = _session!.selectedOptionIndex == index;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          elevation: 0,
                          color: isSelected
                              ? AppTheme.primaryTintLight
                              : AppTheme.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.grayLight,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      option.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? AppTheme.primary
                                            : AppTheme.graphite,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppTheme.primary,
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  option.statement,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.graphite,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          print('❌ Error loading vision (AsyncValue): $error');
          print('Stack trace: $stack');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 16),
                Text('Error loading vision: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userVisionProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        },
      ),
    ),
        ],
      ),
    );
  }

  Widget _buildContextCard(String title, IconData icon, Widget content) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.grayLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Wrap(
      spacing: 8,
      children: [5, 10, 15].map((years) {
        final isSelected = _editTimeframe == years;
        return ChoiceChip(
          label: Text('$years years'),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _editTimeframe = years;
            });
          },
          selectedColor: AppTheme.primaryTint,
          backgroundColor: AppTheme.background,
        );
      }).toList(),
    );
  }

  Widget _buildInfluenceScaleSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: InfluenceScale.values.map((scale) {
        final isSelected = _editInfluenceScale == scale;
        return ChoiceChip(
          label: Text(_getInfluenceScaleLabel(scale)),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _editInfluenceScale = scale;
            });
          },
          selectedColor: AppTheme.primaryTint,
          backgroundColor: AppTheme.background,
        );
      }).toList(),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? "week" : "weeks"} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? "month" : "months"} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? "year" : "years"} ago';
    }
  }
}
