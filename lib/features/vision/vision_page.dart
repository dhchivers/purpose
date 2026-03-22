import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/gemini_provider.dart';
import 'package:purpose/core/services/strategy_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/models/user_vision.dart';
import 'package:purpose/core/models/vision_creation_session.dart';
import 'package:purpose/core/models/user_comment.dart';
import 'package:purpose/core/services/user_comment_provider.dart';
import 'package:intl/intl.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/core/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
          actions: [
            IconButton(
              icon: const Icon(Icons.forum_outlined),
              onPressed: () => context.go('/comments'),
              tooltip: 'Comments',
            ),
          ],
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
        title: Text(
          activeStrategy.name,
          style: const TextStyle(fontSize: 21),
          overflow: !kIsWeb && Platform.isIOS ? TextOverflow.ellipsis : null,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppConstants.homeRoute),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => context.go('/comments'),
            tooltip: 'Comments',
          ),
        ],
      ),
      body: visionAsync.when(
        data: (vision) {
          // Load session data if not already loaded
          if (vision != null && _session == null && vision.sessionId != null) {
            _loadSession(vision.sessionId!);
          }

          // Set initial vision text if editing for first time
          if (vision != null && _isEditingVision && _visionController.text.isEmpty) {
            _visionController.text = vision.visionStatement;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECTION 1: Vision Statement Header (matches Purpose page style)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => _VisionCommentDialog(
                                strategyId: activeStrategy.id,
                                visionStatement: vision?.visionStatement,
                              ),
                            );
                          },
                          icon: const Icon(Icons.forum_outlined, size: 22),
                          color: Colors.white70,
                          tooltip: 'Provide Comment',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Vision',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (vision != null && !_isEditingVision)
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Colors.white70),
                            onPressed: () {
                              setState(() {
                                _isEditingVision = true;
                                _visionController.text = vision.visionStatement;
                              });
                            },
                            tooltip: 'Edit Vision',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else
                          const SizedBox(width: 22),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (vision == null)
                      const Text(
                        'No vision created yet. Tap below to create your vision.',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      )
                    else if (_isEditingVision) ...[
                      TextField(
                        controller: _visionController,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white54),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => setState(() {
                                        _isEditingVision = false;
                                        _visionController.clear();
                                      }),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white54),
                              ),
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
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primary,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Text(
                        vision.visionStatement,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    if (vision != null && !_isEditingVision) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${vision.timeframeYears}-year vision · Updated ${_formatDate(vision.updatedAt)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // SECTION 2: Scrollable Content
              Expanded(
                child: vision == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility_off_outlined,
                                  size: 64, color: AppTheme.grayMedium),
                              const SizedBox(height: 16),
                              const Text(
                                'No vision created yet',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.graphite),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () {
                                  final activeStrategy = ref.read(activeStrategyProvider);
                                  final purposeComplete = activeStrategy?.purpose != null &&
                                      activeStrategy!.purpose!.isNotEmpty;
                                  final valuesAsync = activeStrategy == null
                                      ? null
                                      : ref.read(strategyValuesProvider(activeStrategy.id));
                                  final valuesComplete = valuesAsync?.valueOrNull?.isNotEmpty == true;

                                  if (!purposeComplete || !valuesComplete) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please complete your Purpose and Values before creating a Vision.',
                                        ),
                                        backgroundColor: AppTheme.error,
                                        duration: Duration(seconds: 4),
                                      ),
                                    );
                                    return;
                                  }
                                  context.go('/vision/create');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 16),
                                ),
                                child: const Text('Create Vision'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

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
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isEditingQuestions = true;
                            });
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          color: AppTheme.primary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Edit & Regenerate',
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
                                : const Text('Regenerate'),
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
          ),   // closes SingleChildScrollView
        ),     // closes Expanded
      ],       // closes outer Column children
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
  ),  // closes visionAsync.when(
);    // closes Scaffold
}     // closes build

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

class _VisionCommentDialog extends ConsumerStatefulWidget {
  final String strategyId;
  final String? visionStatement;

  const _VisionCommentDialog({
    required this.strategyId,
    this.visionStatement,
  });

  @override
  ConsumerState<_VisionCommentDialog> createState() =>
      _VisionCommentDialogState();
}

class _VisionCommentDialogState extends ConsumerState<_VisionCommentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  bool _isSaving = false;
  bool _composing = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('User not authenticated');

      final commentId = FirebaseFirestore.instance
          .collection('user_comments')
          .doc()
          .id;

      await firestoreService.saveUserComment(UserComment(
        id: commentId,
        userId: currentUser.uid,
        entityId: widget.strategyId,
        entityType: 'vision',
        commentText: _commentController.text.trim(),
        parentCommentId: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment saved successfully!'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving comment: $e'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.grayLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.grayLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VISION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.grayMedium,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.visionStatement ??
                                'No vision statement yet.',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.graphite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_composing) ...[                TextFormField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    labelText: 'Comment',
                    hintText:
                        'Share your thoughts, progress, or reflections...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 2),
                    ),
                    counterText: '',
                  ),
                  maxLines: 8,
                  maxLength: 1000,
                  style: const TextStyle(fontSize: 12),
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your comment';
                    }
                    if (value.trim().length < 5) {
                      return 'Comment must be at least 5 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    ListenableBuilder(
                      listenable: _commentController,
                      builder: (ctx, _) => Text(
                        '${_commentController.text.length}/1000',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grayMedium,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => setState(() {
                                _composing = false;
                                _commentController.clear();
                              }),
                      child: const Text('Cancel',
                          style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                          : const Text('Submit'),
                    ),
                  ],
                ),
              ] else
                GestureDetector(
                  onTap: () => setState(() => _composing = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.grayLight),
                      borderRadius: BorderRadius.circular(8),
                      color: AppTheme.grayLight.withOpacity(0.2),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_comment_outlined,
                            size: 14, color: AppTheme.grayMedium),
                        SizedBox(width: 8),
                        Text(
                          'Add a comment...',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.grayMedium),
                        ),
                      ],
                    ),
                  ),
                ),
              Builder(
                builder: (ctx) {
                  final commentsAsync = ref.watch(
                    commentsForEntityStreamProvider(
                        (widget.strategyId, 'vision')),
                  );
                  return commentsAsync.when(
                    data: (allComments) {
                      final parents = allComments
                          .where((c) => c.parentCommentId == null)
                          .toList()
                        ..sort(
                            (a, b) => b.createdAt.compareTo(a.createdAt));
                      if (parents.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Divider(height: 16),
                          ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxHeight: 240),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildCommentWidgets(
                                    allComments, parents),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCommentWidgets(
      List<UserComment> allComments, List<UserComment> parents) {
    final widgets = <Widget>[];
    for (final parent in parents) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _commentTile(parent),
      ));
      final replies = allComments
          .where((c) => c.parentCommentId == parent.id)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final reply in replies) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Container(
            padding: const EdgeInsets.only(left: 8),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
            child: _commentTile(reply),
          ),
        ));
      }
    }
    return widgets;
  }

  Widget _commentTile(UserComment comment) {
    final now = DateTime.now();
    final diff = now.difference(comment.createdAt);
    final String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = 'just now';
    } else if (diff.inHours < 1) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      timeAgo = '${diff.inHours}h ago';
    } else if (diff.inDays < 30) {
      timeAgo = '${diff.inDays}d ago';
    } else {
      timeAgo = DateFormat('MMM d').format(comment.createdAt);
    }
    final authorName = ref.watch(userByIdProvider(comment.userId)).value?.fullName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          authorName != null ? '$timeAgo · $authorName' : timeAgo,
          style: const TextStyle(fontSize: 10, color: AppTheme.grayMedium),
        ),
        Text(
          comment.commentText,
          style: const TextStyle(fontSize: 12, color: AppTheme.graphite),
        ),
      ],
    );
  }
}
