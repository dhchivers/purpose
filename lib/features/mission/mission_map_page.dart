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
import 'package:purpose/core/models/mission_map.dart';
import 'package:purpose/core/models/mission_document.dart';
import 'package:purpose/core/models/mission_creation_session.dart';
import 'package:purpose/core/models/user_comment.dart';
import 'package:purpose/core/services/user_comment_provider.dart';
import 'package:intl/intl.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Page displaying user's mission map
class MissionMapPage extends ConsumerStatefulWidget {
  const MissionMapPage({super.key});

  @override
  ConsumerState<MissionMapPage> createState() => _MissionMapPageState();
}

class _MissionMapPageState extends ConsumerState<MissionMapPage> {
  int? _editingMissionIndex;
  bool _isSaving = false;
  final Set<int> _expandedMissions = {}; // Track which missions are expanded
  
  // Text controllers for editing
  final TextEditingController _missionController = TextEditingController();
  final TextEditingController _focusController = TextEditingController();
  final TextEditingController _structuralShiftController = TextEditingController();
  final TextEditingController _capabilityController = TextEditingController();
  final TextEditingController _riskGuardrailController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  bool _useBudgets = false;

  @override
  void dispose() {
    _missionController.dispose();
    _focusController.dispose();
    _structuralShiftController.dispose();
    _capabilityController.dispose();
    _riskGuardrailController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _startEditingMission(MissionDocument mission, int index) {
    setState(() {
      _editingMissionIndex = index;
      _missionController.text = mission.mission;
      _focusController.text = mission.focus;
      _structuralShiftController.text = mission.structuralShift;
      _capabilityController.text = mission.capabilityRequired;
      _riskGuardrailController.text = mission.riskOrValueGuardrail;
      _durationController.text = mission.durationMonths.toString();
      _useBudgets = mission.useBudgets;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMissionIndex = null;
      _missionController.clear();
      _focusController.clear();
      _structuralShiftController.clear();
      _capabilityController.clear();
      _riskGuardrailController.clear();
      _durationController.clear();
      _useBudgets = false;
    });
  }

  void _toggleMissionExpansion(int index) {
    setState(() {
      if (_expandedMissions.contains(index)) {
        _expandedMissions.remove(index);
      } else {
        _expandedMissions.add(index);
      }
    });
  }

  // Calculate mission start date based on cumulative durations
  DateTime? _calculateMissionStartDate(MissionMap missionMap, List<MissionDocument> missions, int missionIndex) {
    if (missionMap.strategyStartDate == null) return null;
    
    int cumulativeMonths = 0;
    for (int i = 0; i < missionIndex; i++) {
      cumulativeMonths += missions[i].durationMonths;
    }
    
    final startDate = missionMap.strategyStartDate!;
    return DateTime(startDate.year, startDate.month + cumulativeMonths, 1);
  }

  // Calculate mission end date
  DateTime? _calculateMissionEndDate(MissionMap missionMap, List<MissionDocument> missions, int missionIndex) {
    final startDate = _calculateMissionStartDate(missionMap, missions, missionIndex);
    if (startDate == null) return null;
    
    final durationMonths = missions[missionIndex].durationMonths;
    return DateTime(startDate.year, startDate.month + durationMonths - 1, 1);
  }

  // Format date as "Month Year"
  String _formatMonthYear(DateTime? date) {
    if (date == null) return 'Not set';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _updateStrategyStartDate(MissionMap missionMap, DateTime newDate) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final updatedMap = missionMap.copyWith(
        strategyStartDate: newDate,
        updatedAt: DateTime.now(),
      );
      
      await firestoreService.updateMissionMap(updatedMap);
      ref.invalidate(missionMapStreamProvider(missionMap.strategyId));
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Strategy start date updated!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating start date: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveMission(MissionMap missionMap, List<MissionDocument> missions, int index) async {
    if (_missionController.text.trim().isEmpty ||
        _focusController.text.trim().isEmpty ||
        _structuralShiftController.text.trim().isEmpty ||
        _capabilityController.text.trim().isEmpty ||
        _riskGuardrailController.text.trim().isEmpty ||
        _durationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All fields are required'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Validate duration is a positive integer
    final duration = int.tryParse(_durationController.text.trim());
    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Duration must be a positive number of months'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // Parse risk level from guardrail text
      final riskGuardrail = _riskGuardrailController.text.trim();
      RiskLevel? riskLevel;
      if (riskGuardrail.toLowerCase().contains('low')) {
        riskLevel = RiskLevel.low;
      } else if (riskGuardrail.toLowerCase().contains('high')) {
        riskLevel = RiskLevel.high;
      } else if (riskGuardrail.toLowerCase().contains('medium')) {
        riskLevel = RiskLevel.medium;
      }

      // Get the mission document to update
      final missionDoc = missions[index];
      
      // Create updated mission document
      final updatedMissionDoc = missionDoc.copyWith(
        mission: _missionController.text.trim(),
        focus: _focusController.text.trim(),
        structuralShift: _structuralShiftController.text.trim(),
        capabilityRequired: _capabilityController.text.trim(),
        riskOrValueGuardrail: riskGuardrail,
        riskLevel: riskLevel,
        durationMonths: duration,
        useBudgets: _useBudgets,
        updatedAt: DateTime.now(),
      );

      await firestoreService.updateMissionDocument(updatedMissionDoc);
      ref.invalidate(missionsForMapStreamProvider(missionMap.id));
      ref.invalidate(currentUserProvider);
      
      setState(() {
        _isSaving = false;
        _editingMissionIndex = null;
      });
      
      _missionController.clear();
      _focusController.clear();
      _structuralShiftController.clear();
      _capabilityController.clear();
      _riskGuardrailController.clear();
      _durationController.clear();
      setState(() => _useBudgets = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mission updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating mission: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteMission(MissionMap missionMap, List<MissionDocument> missions, int index) async {
    // Prevent deleting if only one mission remains
    if (missions.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the last mission. At least one mission is required.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final mission = missions[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Mission?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this mission?'),
            const SizedBox(height: 12),
            Text(
              mission.mission,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will adjust the timeline for all remaining missions.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // Delete the mission document
      await firestoreService.deleteMissionDocument(missions[index].id);
      
      // Reindex remaining missions by updating their sequenceNumbers
      final remainingMissions = missions.where((m) => m.id != missions[index].id).toList();
      for (int i = 0; i < remainingMissions.length; i++) {
        if (remainingMissions[i].sequenceNumber != i) {
          final updatedMission = remainingMissions[i].copyWith(
            sequenceNumber: i,
            updatedAt: DateTime.now(),
          );
          await firestoreService.updateMissionDocument(updatedMission);
        }
      }

      // Adjust currentMissionIndex if necessary
      int? updatedCurrentIndex = missionMap.currentMissionIndex;
      if (updatedCurrentIndex != null) {
        if (index < updatedCurrentIndex) {
          // Mission deleted before current, shift index down
          updatedCurrentIndex = updatedCurrentIndex - 1;
        } else if (index == updatedCurrentIndex) {
          // Current mission deleted, stay at same position (which is now the next mission)
          // But if we deleted the last mission, move back
          if (updatedCurrentIndex >= remainingMissions.length) {
            updatedCurrentIndex = remainingMissions.length - 1;
          }
        }
        // If deleted after current, no change needed
      }

      // Update mission map with new count and currentMissionIndex
      final updatedMap = missionMap.copyWith(
        totalMissions: remainingMissions.length,
        currentMissionIndex: updatedCurrentIndex,
        updatedAt: DateTime.now(),
      );
      await firestoreService.updateMissionMap(updatedMap);
      
      ref.invalidate(missionsForMapStreamProvider(missionMap.id));
      ref.invalidate(missionMapStreamProvider(missionMap.strategyId));
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mission deleted successfully. Timeline updated.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting mission: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showAddMissionDialog(MissionMap missionMap, List<MissionDocument> missions) async {
    final briefDescriptionController = TextEditingController();
    final missionTitleController = TextEditingController();
    final focusController = TextEditingController();
    final structuralShiftController = TextEditingController();
    final capabilityController = TextEditingController();
    final riskGuardrailController = TextEditingController();
    final durationController = TextEditingController(text: '12');
    int selectedPosition = missions.length; // Default: add at end (0-indexed)
    
    // Capture the outer context for SnackBar usage
    final scaffoldContext = context;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        bool isGenerating = false;
        String? generationError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleAiGenerate() async {
              if (briefDescriptionController.text.trim().isEmpty) {
                setDialogState(() {
                  generationError = 'Please describe the mission intent first.';
                });
                return;
              }
              setDialogState(() {
                isGenerating = true;
                generationError = null;
              });
              try {
                final activeStrategy = ref.read(activeStrategyProvider);
                final geminiService = await ref.read(geminiServiceProvider.future);
                final values = await ref.read(
                    strategyValuesProvider(activeStrategy?.id ?? '').future);
                final vision = await ref.read(
                    strategyVisionProvider(activeStrategy?.id ?? '').future);

                final result = await geminiService.generateSingleMission(
                  purposeStatement: activeStrategy?.purpose ?? '',
                  coreValues: values.map((v) => v.statement).toList(),
                  visionStatement: vision?.visionStatement ?? '',
                  existingMissionTitles:
                      missions.map((m) => m.mission).toList(),
                  briefDescription: briefDescriptionController.text.trim(),
                  insertPosition: selectedPosition,
                );

                missionTitleController.text = result['mission'] as String? ?? '';
                focusController.text = result['focus'] as String? ?? '';
                structuralShiftController.text =
                    result['structural_shift'] as String? ?? '';
                capabilityController.text =
                    result['capability_required'] as String? ?? '';
                riskGuardrailController.text =
                    result['risk_or_value_guardrail'] as String? ?? '';
                final aiDuration = result['duration_months'];
                if (aiDuration != null) {
                  durationController.text = aiDuration.toString();
                }

                setDialogState(() => isGenerating = false);
              } catch (e) {
                setDialogState(() {
                  isGenerating = false;
                  generationError = 'AI generation failed. Fill in fields manually.';
                });
              }
            }

            return AlertDialog(
              title: const Text('Add New Mission'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI Generation section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI Generate',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: briefDescriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Describe the mission intent',
                                border: OutlineInputBorder(),
                                isDense: true,
                                hintText:
                                    'e.g. Build strategic partnerships to scale operations',
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 8),
                            if (generationError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  generationError!,
                                  style: const TextStyle(
                                      color: AppTheme.error, fontSize: 12),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    isGenerating ? null : handleAiGenerate,
                                icon: isGenerating
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.auto_awesome, size: 16),
                                label: Text(
                                    isGenerating ? 'Generating…' : 'Generate'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Insert Position',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: selectedPosition,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: 'Select position',
                        ),
                        items: List.generate(
                          missions.length + 1,
                          (index) => DropdownMenuItem(
                            value: index,
                            child: Text('Mission ${index + 1}'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedPosition = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: missionTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Mission Title *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: focusController,
                        decoration: const InputDecoration(
                          labelText: 'Mission Focus *',
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: 'What this mission focuses on',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: structuralShiftController,
                        decoration: const InputDecoration(
                          labelText: 'Structural Shift *',
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: 'What structural change occurs',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: capabilityController,
                        decoration: const InputDecoration(
                          labelText: 'Capability Required *',
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: 'What capabilities need to be developed',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: riskGuardrailController,
                        decoration: const InputDecoration(
                          labelText: 'Risk & Value Guardrails *',
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: 'Include: low, medium, or high risk',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration (months) *',
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: 'e.g., 12',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (missionTitleController.text.trim().isEmpty ||
                        focusController.text.trim().isEmpty ||
                        structuralShiftController.text.trim().isEmpty ||
                        capabilityController.text.trim().isEmpty ||
                        riskGuardrailController.text.trim().isEmpty ||
                        durationController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(
                          content: Text('All fields are required'),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                      return;
                    }

                    final duration =
                        int.tryParse(durationController.text.trim());
                    if (duration == null || duration <= 0) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(
                          content: Text('Duration must be a positive number'),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'position': selectedPosition,
                      'confirmed': true,
                    });
                  },
                  child: const Text('Add Mission'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result['confirmed'] != true) {
      return;
    }

    // Get the selected position from result
    selectedPosition = result['position'] as int;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // Parse risk level from guardrail text
      final riskGuardrail = riskGuardrailController.text.trim();
      RiskLevel? riskLevel;
      if (riskGuardrail.toLowerCase().contains('low')) {
        riskLevel = RiskLevel.low;
      } else if (riskGuardrail.toLowerCase().contains('high')) {
        riskLevel = RiskLevel.high;
      } else if (riskGuardrail.toLowerCase().contains('medium')) {
        riskLevel = RiskLevel.medium;
      }

      final duration = int.parse(durationController.text.trim());
      
      // Calculate time horizon based on duration (simplified)
      String timeHorizon;
      final years = (duration / 12).ceil();
      if (years <= 2) {
        timeHorizon = '0-2 years';
      } else if (years <= 4) {
        timeHorizon = '2-4 years';
      } else if (years <= 6) {
        timeHorizon = '4-6 years';
      } else {
        timeHorizon = '$years years';
      }

      // Create new mission
      final newMission = Mission(
        mission: missionTitleController.text.trim(),
        missionSequence: '${selectedPosition + 1}',
        focus: focusController.text.trim(),
        structuralShift: structuralShiftController.text.trim(),
        capabilityRequired: capabilityController.text.trim(),
        riskOrValueGuardrail: riskGuardrail,
        timeHorizon: timeHorizon,
        riskLevel: riskLevel,
        durationMonths: duration,
      );

      // Generate new mission document ID
      final newMissionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Create new mission document
      final newMissionDoc = MissionDocument(
        id: newMissionId,
        missionMapId: missionMap.id,
        strategyId: missionMap.strategyId,
        sequenceNumber: selectedPosition,
        mission: newMission.mission,
        missionSequence: newMission.missionSequence,
        focus: newMission.focus,
        structuralShift: newMission.structuralShift,
        capabilityRequired: newMission.capabilityRequired,
        riskOrValueGuardrail: newMission.riskOrValueGuardrail,
        timeHorizon: newMission.timeHorizon,
        riskLevel: newMission.riskLevel,
        durationMonths: newMission.durationMonths,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save new mission document
      await firestoreService.saveMissionDocument(newMissionDoc);

      // Re-sequence all missions at or after the insertion point
      for (int i = selectedPosition; i < missions.length; i++) {
        final missionToUpdate = missions[i];
        final updatedMission = missionToUpdate.copyWith(
          sequenceNumber: i + 1,
          missionSequence: '${i + 2}',
          updatedAt: DateTime.now(),
        );
        await firestoreService.updateMissionDocument(updatedMission);
      }

      // Adjust currentMissionIndex if necessary
      int? updatedCurrentIndex = missionMap.currentMissionIndex;
      if (updatedCurrentIndex != null && selectedPosition <= updatedCurrentIndex) {
        updatedCurrentIndex = updatedCurrentIndex + 1;
      }

      // Update mission map with new count and currentMissionIndex
      final updatedMap = missionMap.copyWith(
        totalMissions: missions.length + 1,
        currentMissionIndex: updatedCurrentIndex,
        updatedAt: DateTime.now(),
      );
      await firestoreService.updateMissionMap(updatedMap);
      
      ref.invalidate(missionsForMapStreamProvider(missionMap.id));
      ref.invalidate(missionMapStreamProvider(missionMap.strategyId));
      ref.invalidate(currentUserProvider);
      
      briefDescriptionController.dispose();
      missionTitleController.dispose();
      focusController.dispose();
      structuralShiftController.dispose();
      capabilityController.dispose();
      riskGuardrailController.dispose();
      durationController.dispose();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mission added at position ${selectedPosition + 1}. Timeline updated.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      briefDescriptionController.dispose();
      missionTitleController.dispose();
      focusController.dispose();
      structuralShiftController.dispose();
      capabilityController.dispose();
      riskGuardrailController.dispose();
      durationController.dispose();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding mission: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
            tooltip: 'Back to Home',
          ),
          title: const Text('Mission Map'),
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

    final missionMapAsync = ref.watch(missionMapStreamProvider(activeStrategy.id));

    return missionMapAsync.when(
      data: (missionMap) {
        if (missionMap == null) {
          // Empty state with simple AppBar
          return Scaffold(
            appBar: AppBar(
              backgroundColor: AppTheme.graphite,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
                tooltip: 'Back to Home',
              ),
              title: Text(
                activeStrategy.name,
                style: const TextStyle(fontSize: 21),
                overflow: !kIsWeb && Platform.isIOS ? TextOverflow.ellipsis : null,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.forum_outlined),
                  onPressed: () => context.go('/comments'),
                  tooltip: 'Comments',
                ),
              ],
            ),
            body: _buildEmptyState(),
          );
        }
        
        // Main view with action buttons in AppBar
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppTheme.graphite,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/'),
              tooltip: 'Back to Home',
            ),
            title: Text(
              activeStrategy.name,
              style: const TextStyle(fontSize: 21),
              overflow: !kIsWeb && Platform.isIOS ? TextOverflow.ellipsis : null,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.forum_outlined),
                onPressed: () => context.go('/comments'),
                tooltip: 'Comments',
              ),
            ],
          ),
          body: Column(
            children: [
              // Header section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => _MissionMapCommentDialog(
                            missionMapId: missionMap.id,
                            strategyName: activeStrategy.name,
                          ),
                        );
                      },
                      icon: const Icon(Icons.forum_outlined),
                      tooltip: 'Provide Comment',
                      iconSize: 24,
                      color: Colors.white,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Mission Map',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final missionsAsync = ref.watch(missionsForMapStreamProvider(missionMap.id));
                        final missions = missionsAsync.value ?? [];
                        return IconButton(
                          onPressed: () => _showAddMissionDialog(missionMap, missions),
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: 'Add Mission',
                          iconSize: 28,
                          color: Colors.white,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final missionsAsync = ref.watch(missionsForMapStreamProvider(missionMap.id));
                    return missionsAsync.when(
                      data: (missions) => _buildMissionMapView(missionMap, missions),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: Text('Error loading missions: $error'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.graphite,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
            tooltip: 'Back to Home',
          ),
          title: Text(
            activeStrategy.name,
            style: const TextStyle(fontSize: 21),
            overflow: !kIsWeb && Platform.isIOS ? TextOverflow.ellipsis : null,
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.graphite,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
            tooltip: 'Back to Home',
          ),
          title: Text(
            activeStrategy.name,
            style: const TextStyle(fontSize: 21),
            overflow: !kIsWeb && Platform.isIOS ? TextOverflow.ellipsis : null,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading mission map: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.error),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToMissionCreate(BuildContext context) {
    final activeStrategy = ref.read(activeStrategyProvider);
    final visionAsync = activeStrategy == null
        ? null
        : ref.read(strategyVisionProvider(activeStrategy.id));
    final visionComplete = visionAsync?.valueOrNull != null;

    if (!visionComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete your Vision before creating a Mission Map.',
          ),
          backgroundColor: AppTheme.error,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    context.go('/mission/create');
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              'No Mission Map Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.graphite,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create a strategic mission map to bridge the gap between your current state and vision.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.graphite.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                _navigateToMissionCreate(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Mission Map'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionMapView(MissionMap missionMap, List<MissionDocument> missions) {
    final currentIndex = missionMap.currentMissionIndex ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Strategy Start Date Section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.grayLight),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: AppTheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Start Date:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.graphite,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatMonthYear(missionMap.strategyStartDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final initialDate = missionMap.strategyStartDate ?? now;
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 20),
                    );
                    if (selectedDate != null) {
                      await _updateStrategyStartDate(missionMap, selectedDate);
                    }
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  color: AppTheme.primary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Change Date',
                ),
              ],
            ),
          ),
          // const SizedBox(height: 24),

          // Visual timeline bar (temporarily removed)
          // _buildVisualTimeline(missionMap, missions),

          // const SizedBox(height: 32)

          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: missions.length,
            separatorBuilder: (context, index) => _buildTimelineConnector(),
            itemBuilder: (context, index) {
              final mission = missions[index];
              final isCurrent = index == currentIndex;
              final isCompleted = index < currentIndex;
              final isFuture = index > currentIndex;

              return _buildMissionCard(
                mission,
                index,
                missionMap,
                missions,
                isCurrent: isCurrent,
                isCompleted: isCompleted,
                isFuture: isFuture,
              );
            },
          ),
        ],
      ),
    );
  }

  // Widget _buildVisualTimeline(MissionMap missionMap, List<MissionDocument> missions) {
  //   if (missionMap.strategyStartDate == null) {
  //     return const SizedBox.shrink();
  //   }

  //   // Calculate total duration and individual mission positions
  //   int totalMonths = 0;
  //   for (var mission in missions) {
  //     totalMonths += mission.durationMonths;
  //   }

  //   if (totalMonths == 0) return const SizedBox.shrink();

  //   // Calculate cumulative positions for date labels
  //   final List<int> cumulativeMonths = [0];
  //   for (int i = 0; i < missions.length; i++) {
  //     cumulativeMonths.add(cumulativeMonths[i] + missions[i].durationMonths);
  //   }

  //   // Calculate current date position
  //   final now = DateTime.now();
  //   final startDate = missionMap.strategyStartDate!;
  //   final monthsSinceStart = (now.year - startDate.year) * 12 + (now.month - startDate.month);
  //   final currentDatePosition = monthsSinceStart / totalMonths;

  //   return const SizedBox.shrink(); // method body removed temporarily
  // }
  Widget _buildTimelineConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 35),
      child: Container(
        width: 2,
        height: 24,
        color: AppTheme.grayLight,
      ),
    );
  }

  Widget _buildMissionCard(
    MissionDocument mission,
    int index,
    MissionMap missionMap,
    List<MissionDocument> missions, {
    required bool isCurrent,
    required bool isCompleted,
    required bool isFuture,
  }) {
    final isEditing = _editingMissionIndex == index;
    final isExpanded = _expandedMissions.contains(index) || isEditing;
    Color statusColor;
    Color backgroundColor;
    Color borderColor;

    if (isCompleted) {
      statusColor = AppTheme.success;
      backgroundColor = AppTheme.success.withOpacity(0.05);
      borderColor = AppTheme.success.withOpacity(0.3);
    } else if (isCurrent) {
      statusColor = AppTheme.primary;
      backgroundColor = AppTheme.primary.withOpacity(0.05);
      borderColor = AppTheme.primary;
    } else {
      statusColor = AppTheme.grayMedium;
      backgroundColor = Colors.white;
      borderColor = AppTheme.grayLight;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Mission content
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: isCurrent ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: expand button + risk badge + edit button
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!isEditing) ...[
                        IconButton(
                          icon: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                          ),
                          onPressed: () => _toggleMissionExpansion(index),
                          tooltip: isExpanded ? 'Collapse' : 'Expand',
                          color: AppTheme.primary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (mission.useBudgets) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Budgeting',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (!isEditing) ...[
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          onPressed: () => _startEditingMission(mission, index),
                          tooltip: 'Edit Mission',
                          color: AppTheme.primary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ),
                // Title row
                Row(
                  children: [
                    Expanded(
                      child: isEditing
                          ? TextField(
                              controller: _missionController,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.graphite,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Mission Title',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            )
                          : GestureDetector(
                              onTap: () => context.go('/mission/${mission.id}'),
                              child: Text(
                                mission.mission,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isFuture 
                                      ? AppTheme.primary.withOpacity(0.4)
                                      : AppTheme.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: isFuture
                                      ? AppTheme.primary.withOpacity(0.4)
                                      : AppTheme.primary,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatMonthYear(_calculateMissionStartDate(missionMap, missions, index))} - ${_formatMonthYear(_calculateMissionEndDate(missionMap, missions, index))}',
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${mission.durationMonths} months)',
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (isEditing) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _useBudgets,
                        onChanged: (value) => setState(() => _useBudgets = value ?? false),
                        activeColor: AppTheme.primary,
                      ),
                      const Text(
                        'Enable Budgeting',
                        style: TextStyle(fontSize: 14, color: AppTheme.graphite),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  mission.focus,
                  style: TextStyle(
                    fontSize: 14,
                    color: isFuture 
                        ? AppTheme.graphite.withOpacity(0.5)
                        : AppTheme.graphite,
                    height: 1.5,
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 16),
                  isEditing
                      ? _buildEditableSection(
                          'Mission Focus',
                          _focusController,
                          Icons.track_changes,
                        )
                      : _buildExpandableSection(
                          'Mission Focus',
                          mission.focus,
                          Icons.track_changes,
                        ),
                  if (!isEditing) const SizedBox(height: 12),
                  isEditing
                      ? _buildEditableSection(
                          'Structural Shift',
                          _structuralShiftController,
                          Icons.transform,
                        )
                      : _buildExpandableSection(
                          'Structural Shift',
                          mission.structuralShift,
                          Icons.transform,
                        ),
                  const SizedBox(height: 12),
                  isEditing
                      ? _buildEditableSection(
                          'Capability Required',
                          _capabilityController,
                          Icons.psychology,
                        )
                      : _buildExpandableSection(
                          'Capability Required',
                          mission.capabilityRequired,
                          Icons.psychology,
                        ),
                  const SizedBox(height: 12),
                  isEditing
                      ? _buildEditableSection(
                          'Risk & Value Guardrails',
                          _riskGuardrailController,
                          Icons.security,
                        )
                      : _buildExpandableSection(
                          'Risk & Value Guardrails',
                          mission.riskOrValueGuardrail,
                          Icons.security,
                        ),
                  if (isEditing) ...[
                    const SizedBox(height: 12),
                    _buildDurationField(),
                  ],
                ],
                if (isEditing) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (missions.length > 1)
                        TextButton(
                          onPressed: _isSaving ? null : () => _deleteMission(missionMap, missions, index),
                          style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                          child: const Text('Delete'),
                        )
                      else
                        const SizedBox.shrink(),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _isSaving ? null : _cancelEditing,
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isSaving ? null : () => _saveMission(missionMap, missions, index),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.graphite,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildEditableSection(
    String title,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.graphite,
            height: 1.4,
          ),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDurationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.timelapse,
              size: 14,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 6),
            const Text(
              'Duration (months)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _durationController,
          keyboardType: TextInputType.number,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.graphite,
            height: 1.4,
          ),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            hintText: 'e.g., 12',
          ),
        ),
      ],
    );
  }
}

class _MissionMapCommentDialog extends ConsumerStatefulWidget {
  final String missionMapId;
  final String strategyName;

  const _MissionMapCommentDialog({
    required this.missionMapId,
    required this.strategyName,
  });

  @override
  ConsumerState<_MissionMapCommentDialog> createState() =>
      _MissionMapCommentDialogState();
}

class _MissionMapCommentDialogState
    extends ConsumerState<_MissionMapCommentDialog> {
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
        entityId: widget.missionMapId,
        entityType: 'mission_map',
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
                    const Icon(Icons.map_outlined,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MISSION MAP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.grayMedium,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.strategyName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.graphite,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                        (widget.missionMapId, 'mission_map')),
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
