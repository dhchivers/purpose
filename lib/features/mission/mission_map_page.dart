import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/models/user_mission_map.dart';
import 'package:purpose/core/models/mission_creation_session.dart';
import 'package:purpose/core/theme/app_theme.dart';

/// Provider for user mission map
final userMissionMapProvider = FutureProvider.autoDispose<UserMissionMap?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return null;
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserMissionMap(user.uid);
});

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

  void _startEditingMission(Mission mission, int index) {
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
  DateTime? _calculateMissionStartDate(UserMissionMap missionMap, int missionIndex) {
    if (missionMap.strategyStartDate == null) return null;
    
    int cumulativeMonths = 0;
    for (int i = 0; i < missionIndex; i++) {
      cumulativeMonths += missionMap.missions[i].durationMonths;
    }
    
    final startDate = missionMap.strategyStartDate!;
    return DateTime(startDate.year, startDate.month + cumulativeMonths, 1);
  }

  // Calculate mission end date
  DateTime? _calculateMissionEndDate(UserMissionMap missionMap, int missionIndex) {
    final startDate = _calculateMissionStartDate(missionMap, missionIndex);
    if (startDate == null) return null;
    
    final durationMonths = missionMap.missions[missionIndex].durationMonths;
    return DateTime(startDate.year, startDate.month + durationMonths - 1, 1);
  }

  // Format date as "Month Year"
  String _formatMonthYear(DateTime? date) {
    if (date == null) return 'Not set';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _updateStrategyStartDate(UserMissionMap missionMap, DateTime newDate) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final updatedMap = missionMap.copyWith(
        strategyStartDate: newDate,
        updatedAt: DateTime.now(),
      );
      
      await firestoreService.updateUserMissionMap(updatedMap);
      ref.invalidate(userMissionMapProvider);
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

  Future<void> _saveMission(UserMissionMap missionMap, int index) async {
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
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');

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

      // Create updated mission
      final updatedMission = missionMap.missions[index].copyWith(
        mission: _missionController.text.trim(),
        structuralShift: _structuralShiftController.text.trim(),
        capabilityRequired: _capabilityController.text.trim(),
        riskOrValueGuardrail: riskGuardrail,
        riskLevel: riskLevel,
        durationMonths: duration,
      );

      // Update mission list
      final updatedMissions = List<Mission>.from(missionMap.missions);
      updatedMissions[index] = updatedMission;

      // Create updated mission map
      final updatedMap = missionMap.copyWith(
        missions: updatedMissions,
        updatedAt: DateTime.now(),
      );

      await firestoreService.updateUserMissionMap(updatedMap);
      
      ref.invalidate(userMissionMapProvider);
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

  Future<void> _deleteMission(UserMissionMap missionMap, int index) async {
    // Prevent deleting if only one mission remains
    if (missionMap.missions.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the last mission. At least one mission is required.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final mission = missionMap.missions[index];
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
                color: Color(0xFF1E6BFF),
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
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');

      // Remove mission from list
      final updatedMissions = List<Mission>.from(missionMap.missions);
      updatedMissions.removeAt(index);

      // Adjust currentMissionIndex if necessary
      int? updatedCurrentIndex = missionMap.currentMissionIndex;
      if (updatedCurrentIndex != null) {
        if (index < updatedCurrentIndex) {
          // Mission deleted before current, shift index down
          updatedCurrentIndex = updatedCurrentIndex - 1;
        } else if (index == updatedCurrentIndex) {
          // Current mission deleted, stay at same position (which is now the next mission)
          // But if we deleted the last mission, move back
          if (updatedCurrentIndex >= updatedMissions.length) {
            updatedCurrentIndex = updatedMissions.length - 1;
          }
        }
        // If deleted after current, no change needed
      }

      // Create updated mission map
      final updatedMap = missionMap.copyWith(
        missions: updatedMissions,
        currentMissionIndex: updatedCurrentIndex,
        updatedAt: DateTime.now(),
      );

      await firestoreService.updateUserMissionMap(updatedMap);
      
      ref.invalidate(userMissionMapProvider);
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

  Future<void> _showAddMissionDialog(UserMissionMap missionMap) async {
    final missionTitleController = TextEditingController();
    final focusController = TextEditingController();
    final structuralShiftController = TextEditingController();
    final capabilityController = TextEditingController();
    final riskGuardrailController = TextEditingController();
    final durationController = TextEditingController(text: '12');
    int selectedPosition = missionMap.missions.length; // Default: add at end (0-indexed)
    
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
                      color: Color(0xFF1E6BFF),
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
                      missionMap.missions.length + 1,
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
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');

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

      // Insert mission at selected position
      final updatedMissions = List<Mission>.from(missionMap.missions);
      updatedMissions.insert(selectedPosition, newMission);

      // Update mission sequences
      for (int i = 0; i < updatedMissions.length; i++) {
        updatedMissions[i] = updatedMissions[i].copyWith(
          missionSequence: '${i + 1}',
        );
      }

      // Adjust currentMissionIndex if necessary
      int? updatedCurrentIndex = missionMap.currentMissionIndex;
      if (updatedCurrentIndex != null && selectedPosition <= updatedCurrentIndex) {
        updatedCurrentIndex = updatedCurrentIndex + 1;
      }

      // Create updated mission map
      final updatedMap = missionMap.copyWith(
        missions: updatedMissions,
        currentMissionIndex: updatedCurrentIndex,
        updatedAt: DateTime.now(),
      );

      await firestoreService.updateUserMissionMap(updatedMap);
      
      ref.invalidate(userMissionMapProvider);
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

  Future<void> _deleteMissionMap(UserMissionMap missionMap) async {
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
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');

      await firestoreService.deleteUserMissionMap(missionMap.id, user.uid);
      
      ref.invalidate(userMissionMapProvider);
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
    final missionMapAsync = ref.watch(userMissionMapProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/');
          },
          tooltip: 'Back to Home',
        ),
        title: const Text('Mission Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(userMissionMapProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: missionMapAsync.when(
        data: (missionMap) {
          if (missionMap == null) {
            return _buildEmptyState();
          }
          return _buildMissionMapView(missionMap);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
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
                color: Color(0xFF0A0E27),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create a strategic mission map to bridge the gap between your current state and vision.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: const Color(0xFF0A0E27).withOpacity(0.7),
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

  Widget _buildMissionMapView(UserMissionMap missionMap) {
    final currentIndex = missionMap.currentMissionIndex ?? 0;
    final isComplete = missionMap.isComplete;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with progress
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Strategic Mission Map',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A0E27),
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons
              IconButton(
                onPressed: () {
                  context.go('/mission/create');
                },
                icon: const Icon(Icons.refresh),
                tooltip: 'Regenerate Map',
                iconSize: 28,
                color: const Color(0xFF1E6BFF),
              ),
              const SizedBox(width: 8),
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
                        ),
                      )
                    : const Icon(Icons.delete),
                tooltip: 'Delete Map',
                iconSize: 28,
                color: AppTheme.error,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Strategy Start Date Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF1E6BFF),
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Strategy Start Date:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatMonthYear(missionMap.strategyStartDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E6BFF),
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
                    foregroundColor: const Color(0xFF1E6BFF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Current mission highlight
          if (!isComplete)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E6BFF), Color(0xFF4A90FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E6BFF).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Current Mission',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    missionMap.missions[currentIndex].mission,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    missionMap.missions[currentIndex].focus,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

          if (isComplete)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.success,
                    AppTheme.success.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mission Map Complete!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Congratulations on completing all missions!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // Visual timeline bar
          _buildVisualTimeline(missionMap),

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
                  color: Color(0xFF0A0E27),
                ),
              ),
              IconButton(
                onPressed: () => _showAddMissionDialog(missionMap),
                icon: const Icon(Icons.add_circle),
                tooltip: 'Add Mission',
                iconSize: 28,
                color: const Color(0xFF1E6BFF),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: missionMap.missions.length,
            separatorBuilder: (context, index) => _buildTimelineConnector(),
            itemBuilder: (context, index) {
              final mission = missionMap.missions[index];
              final isCurrent = index == currentIndex;
              final isCompleted = index < currentIndex;
              final isFuture = index > currentIndex;

              return _buildMissionCard(
                mission,
                index,
                missionMap,
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

  Widget _buildVisualTimeline(UserMissionMap missionMap) {
    if (missionMap.strategyStartDate == null) {
      return const SizedBox.shrink();
    }

    // Calculate total duration and individual mission positions
    int totalMonths = 0;
    for (var mission in missionMap.missions) {
      totalMonths += mission.durationMonths;
    }

    if (totalMonths == 0) return const SizedBox.shrink();

    // Calculate current date position
    final now = DateTime.now();
    final startDate = missionMap.strategyStartDate!;
    final monthsSinceStart = (now.year - startDate.year) * 12 + (now.month - startDate.month);
    final currentDatePosition = monthsSinceStart / totalMonths;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Visual Timeline',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0A0E27),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;

              return SizedBox(
                height: 104, // Increased to accommodate Today label below
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Mission rectangles with labels
                    Row(
                      children: [
                        for (int i = 0; i < missionMap.missions.length; i++) ...[
                          Expanded(
                            flex: missionMap.missions[i].durationMonths,
                            child: Column(
                              children: [
                                // Circled number label
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: i == missionMap.currentMissionIndex
                                        ? const Color(0xFF1E6BFF)
                                        : i < (missionMap.currentMissionIndex ?? 0)
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFF9CA3AF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Rounded rectangle for mission
                                Expanded(
                                  child: Container(
                                    margin: EdgeInsets.only(
                                      right: i < missionMap.missions.length - 1 ? 4 : 0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: i == missionMap.currentMissionIndex
                                          ? const Color(0xFF1E6BFF).withOpacity(0.2)
                                          : i < (missionMap.currentMissionIndex ?? 0)
                                              ? const Color(0xFF10B981).withOpacity(0.2)
                                              : const Color(0xFF9CA3AF).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: i == missionMap.currentMissionIndex
                                            ? const Color(0xFF1E6BFF)
                                            : i < (missionMap.currentMissionIndex ?? 0)
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFF9CA3AF),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Current date indicator line
                    if (currentDatePosition >= 0 && currentDatePosition <= 1)
                      Positioned(
                        left: availableWidth * currentDatePosition,
                        top: 40, // Start after circled numbers (32px height + 8px spacing)
                        bottom: 0,
                        child: Container(
                          width: 2,
                          color: const Color(0xFFEF4444),
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
                            color: const Color(0xFFEF4444),
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatMonthYear(missionMap.strategyStartDate),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatMonthYear(
                  DateTime(
                    startDate.year,
                    startDate.month + totalMonths,
                    1,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
        color: const Color(0xFFE5E7EB),
      ),
    );
  }

  Widget _buildMissionCard(
    Mission mission,
    int index,
    UserMissionMap missionMap, {
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
      statusColor = const Color(0xFF1E6BFF);
      backgroundColor = const Color(0xFF1E6BFF).withOpacity(0.05);
      borderColor = const Color(0xFF1E6BFF);
    } else {
      statusColor = const Color(0xFF9CA3AF);
      backgroundColor = Colors.white;
      borderColor = const Color(0xFFE5E7EB);
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
                                color: Color(0xFF0A0E27),
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
                                    ? const Color(0xFF0A0E27).withOpacity(0.5)
                                    : const Color(0xFF0A0E27),
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
                        color: const Color(0xFF1E6BFF),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _startEditingMission(mission, index),
                        tooltip: 'Edit Mission',
                        color: const Color(0xFF1E6BFF),
                      ),
                      if (missionMap.missions.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _deleteMission(missionMap, index),
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
                      '${_formatMonthYear(_calculateMissionStartDate(missionMap, index))} - ${_formatMonthYear(_calculateMissionEndDate(missionMap, index))}',
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
                        ? const Color(0xFF374151).withOpacity(0.5)
                        : const Color(0xFF374151),
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
                        onPressed: _isSaving ? null : () => _saveMission(missionMap, index),
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
              color: const Color(0xFF1E6BFF),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E6BFF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF374151),
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
              color: const Color(0xFF1E6BFF),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E6BFF),
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
            color: Color(0xFF374151),
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
              color: Color(0xFF1E6BFF),
            ),
            const SizedBox(width: 6),
            const Text(
              'Duration (months)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E6BFF),
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
            color: Color(0xFF374151),
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
