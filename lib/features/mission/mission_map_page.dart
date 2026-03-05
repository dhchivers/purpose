import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/strategy_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/models/mission_map.dart';
import 'package:purpose/core/models/mission_document.dart';
import 'package:purpose/core/models/mission_creation_session.dart';
import 'package:purpose/core/models/strategy_type.dart';
import 'package:purpose/core/theme/app_theme.dart';
import 'package:purpose/features/admin/admin_strategy_types_page.dart';

/// Page displaying user's mission map
class MissionMapPage extends ConsumerStatefulWidget {
  const MissionMapPage({super.key});

  @override
  ConsumerState<MissionMapPage> createState() => _MissionMapPageState();
}

class _MissionMapPageState extends ConsumerState<MissionMapPage> {
  bool _isDeleting = false;
  int? _editingMissionIndex;
  bool _isSaving = false;
  final Set<int> _expandedMissions = {}; // Track which missions are expanded
  
  // Text controllers for editing
  final TextEditingController _missionController = TextEditingController();
  final TextEditingController _structuralShiftController = TextEditingController();
  final TextEditingController _capabilityController = TextEditingController();
  final TextEditingController _riskGuardrailController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  @override
  void dispose() {
    _missionController.dispose();
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
      _structuralShiftController.text = mission.structuralShift;
      _capabilityController.text = mission.capabilityRequired;
      _riskGuardrailController.text = mission.riskOrValueGuardrail;
      _durationController.text = mission.durationMonths.toString();
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMissionIndex = null;
      _missionController.clear();
      _structuralShiftController.clear();
      _capabilityController.clear();
      _riskGuardrailController.clear();
      _durationController.clear();
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

  // Format date as separate lines for timeline
  Widget _buildTimelineDate(DateTime? date) {
    if (date == null) return const SizedBox.shrink();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          months[date.month - 1],
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.grayMedium,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
        Text(
          '${date.year}',
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.grayMedium,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
        ),
      ],
    );
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
        structuralShift: _structuralShiftController.text.trim(),
        capabilityRequired: _capabilityController.text.trim(),
        riskOrValueGuardrail: riskGuardrail,
        riskLevel: riskLevel,
        durationMonths: duration,
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
      _structuralShiftController.clear();
      _capabilityController.clear();
      _riskGuardrailController.clear();
      _durationController.clear();
      
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
        return AlertDialog(
          title: const Text('Add New Mission'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        selectedPosition = value;
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
                      labelText: 'Focus *',
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
                
                final duration = int.tryParse(durationController.text.trim());
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

    if (result == null || result['confirmed'] != true) {
      missionTitleController.dispose();
      focusController.dispose();
      structuralShiftController.dispose();
      capabilityController.dispose();
      riskGuardrailController.dispose();
      durationController.dispose();
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

  Future<void> _deleteMissionMap(MissionMap missionMap) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Mission Map?'),
        content: const Text(
          'Are you sure you want to delete your mission map? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // Delete the mission map (which will cascade delete all mission documents)
      await firestoreService.deleteMissionMap(missionMap.id, missionMap.strategyId);
      
      ref.invalidate(missionMapStreamProvider(missionMap.strategyId));
      ref.invalidate(missionsForMapStreamProvider(missionMap.id));
      ref.invalidate(currentUserProvider);
      
      setState(() => _isDeleting = false);
      
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting mission map: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
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
            actions: [
              IconButton(
                onPressed: () {
                  context.go('/mission/create');
                },
                icon: const Icon(Icons.refresh),
                tooltip: 'Regenerate Map',
              ),
              IconButton(
                onPressed: _isDeleting 
                    ? null 
                    : () => _deleteMissionMap(missionMap),
                icon: _isDeleting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.delete),
                tooltip: 'Delete Map',
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
                child: const Center(
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
                context.go('/mission/create');
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
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Strategy Start Date:',
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
                TextButton.icon(
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
                  label: const Text('Change Date'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Visual timeline bar
          _buildVisualTimeline(missionMap, missions),

          const SizedBox(height: 32),

          // All missions timeline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mission Timeline',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.graphite,
                ),
              ),
              IconButton(
                onPressed: () => _showAddMissionDialog(missionMap, missions),
                icon: const Icon(Icons.add_circle),
                tooltip: 'Add Mission',
                iconSize: 28,
                color: AppTheme.primary,
              ),
            ],
          ),
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

  Widget _buildVisualTimeline(MissionMap missionMap, List<MissionDocument> missions) {
    if (missionMap.strategyStartDate == null) {
      return const SizedBox.shrink();
    }

    // Calculate total duration and individual mission positions
    int totalMonths = 0;
    for (var mission in missions) {
      totalMonths += mission.durationMonths;
    }

    if (totalMonths == 0) return const SizedBox.shrink();

    // Calculate cumulative positions for date labels
    final List<int> cumulativeMonths = [0];
    for (int i = 0; i < missions.length; i++) {
      cumulativeMonths.add(cumulativeMonths[i] + missions[i].durationMonths);
    }

    // Calculate current date position
    final now = DateTime.now();
    final startDate = missionMap.strategyStartDate!;
    final monthsSinceStart = (now.year - startDate.year) * 12 + (now.month - startDate.month);
    final currentDatePosition = monthsSinceStart / totalMonths;

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grayLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;

              return SizedBox(
                height: 90, // Reduced height without circled numbers
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Date labels at top
                    ...[
                      for (int i = 0; i <= missions.length; i++)
                        Positioned(
                          left: availableWidth * (cumulativeMonths[i] / totalMonths) - 15,
                          top: 4, // Position just above the bars
                          child: _buildTimelineDate(
                            DateTime(
                              startDate.year,
                              startDate.month + cumulativeMonths[i],
                              1,
                            ),
                          ),
                        ),
                    ],
                    // Mission rectangles with labels
                    Positioned(
                      top: 26, // Position below date labels
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Row(
                      children: [
                        for (int i = 0; i < missions.length; i++) ...[
                          Expanded(
                            flex: missions[i].durationMonths,
                            child: Container(
                              margin: EdgeInsets.only(
                                right: i < missions.length - 1 ? 4 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: i == missionMap.currentMissionIndex
                                    ? AppTheme.primary.withOpacity(0.2)
                                    : i < (missionMap.currentMissionIndex ?? 0)
                                        ? AppTheme.success.withOpacity(0.2)
                                        : AppTheme.grayMedium.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: i == missionMap.currentMissionIndex
                                      ? AppTheme.primary
                                      : i < (missionMap.currentMissionIndex ?? 0)
                                          ? AppTheme.success
                                          : AppTheme.grayMedium,
                                  width: 2,
                                ),
                              ),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        // Calculate appropriate font size based on bar width
                                        final barWidth = constraints.maxWidth;
                                        final barHeight = constraints.maxHeight;
                                        final missionTitle = missions[i].mission;
                                        
                                        // Estimate characters that can fit
                                        // Rough estimate: 7 pixels per character at base font size
                                        final maxCharsPerLine = (barWidth - 8) / 7;
                                        final estimatedLines = (missionTitle.length / maxCharsPerLine).ceil();
                                        
                                        // Calculate font size to fit (with minimum and maximum)
                                        double fontSize = 11;
                                        if (barWidth < 80) {
                                          fontSize = 8;
                                        } else if (barWidth < 120) {
                                          fontSize = 9;
                                        } else if (barWidth < 160) {
                                          fontSize = 10;
                                        } else if (barWidth >= 200) {
                                          fontSize = 12;
                                        }
                                        
                                        // Reduce font size if we have many lines
                                        if (estimatedLines > 3 && barHeight < 50) {
                                          fontSize = fontSize * 0.85;
                                        }
                                        
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                          child: Align(
                                            alignment: Alignment.topCenter,
                                            child: InkWell(
                                              onTap: () {
                                                context.go('/mission/${missions[i].id}');
                                              },
                                              borderRadius: BorderRadius.circular(4),
                                              child: Padding(
                                                padding: const EdgeInsets.all(2),
                                                child: Text(
                                                  missionTitle,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 4,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: fontSize,
                                                    fontWeight: FontWeight.w600,
                                                    color: i == missionMap.currentMissionIndex
                                                        ? AppTheme.primary
                                                        : i < (missionMap.currentMissionIndex ?? 0)
                                                            ? AppTheme.success.withOpacity(0.9)
                                                            : AppTheme.grayMedium,
                                                    height: 1.2,
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: (i == missionMap.currentMissionIndex
                                                        ? AppTheme.primary
                                                        : i < (missionMap.currentMissionIndex ?? 0)
                                                            ? AppTheme.success.withOpacity(0.9)
                                                            : AppTheme.grayMedium).withOpacity(0.3),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ],
                      ),
                    ),
                    // Current date indicator line (20% of bar height from bottom)
                    if (currentDatePosition >= 0 && currentDatePosition <= 1)
                      Positioned(
                        left: availableWidth * currentDatePosition,
                        top: 77, // Adjusted for new height (90 total - 13px line = 77)
                        child: Container(
                          width: 2,
                          height: 13, // 20% of bar height (64px * 0.2)
                          color: AppTheme.error,
                        ),
                      ),
                    // Today label positioned under the line
                    if (currentDatePosition >= 0 && currentDatePosition <= 1)
                      Positioned(
                        left: availableWidth * currentDatePosition - 30, // Center the label (60px width / 2)
                        bottom: -24, // Position below the timeline
                        child: Container(
                          width: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Today',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

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
        // Timeline marker
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted ? statusColor : backgroundColor,
                border: Border.all(
                  color: borderColor,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),

        // Mission content
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
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
                          : Text(
                              mission.mission,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isFuture 
                                    ? AppTheme.graphite.withOpacity(0.5)
                                    : AppTheme.graphite,
                              ),
                            ),
                    ),
                    if (!isEditing) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                        ),
                        onPressed: () => _toggleMissionExpansion(index),
                        tooltip: isExpanded ? 'Collapse' : 'Expand',
                        color: AppTheme.primary,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _startEditingMission(mission, index),
                        tooltip: 'Edit Mission',
                        color: AppTheme.primary,
                      ),
                      if (missions.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _deleteMission(missionMap, missions, index),
                          tooltip: 'Delete Mission',
                          color: AppTheme.error,
                        ),
                    ],
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
                    const SizedBox(width: 12),
                    _buildRiskBadge(mission.riskLevel),
                  ],
                ),
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
                    mainAxisAlignment: MainAxisAlignment.end,
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskBadge(RiskLevel? level) {
    Color color;
    String label;

    switch (level) {
      case RiskLevel.low:
        color = AppTheme.success;
        label = 'Low Risk';
        break;
      case RiskLevel.medium:
        color = AppTheme.warning;
        label = 'Medium Risk';
        break;
      case RiskLevel.high:
        color = AppTheme.error;
        label = 'High Risk';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
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
