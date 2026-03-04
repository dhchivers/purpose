import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purpose/core/models/mission_document.dart';
import 'package:purpose/core/models/mission_creation_session.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';

/// Provider for a specific mission document
final missionDocumentProvider =
    FutureProvider.family<MissionDocument?, String>((ref, missionId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getMissionDocument(missionId);
});

class MissionDetailPage extends ConsumerWidget {
  final String missionId;

  const MissionDetailPage({
    super.key,
    required this.missionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionAsync = ref.watch(missionDocumentProvider(missionId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Mission Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mission'),
        ),
      ),
      body: missionAsync.when(
        data: (mission) {
          if (mission == null) {
            return const Center(child: Text('Mission not found'));
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mission Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primary,
                        AppTheme.primary.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Mission ${mission.sequenceNumber + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        mission.mission,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Info chips row
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildInfoChip(
                            icon: Icons.schedule,
                            label: mission.timeHorizon,
                          ),
                          _buildInfoChip(
                            icon: Icons.calendar_month,
                            label: '${mission.durationMonths} months',
                          ),
                          if (mission.riskLevel != null)
                            _buildRiskChip(mission.riskLevel!),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Compact cards in full-width grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate card width to fit nicely
                          final availableWidth = constraints.maxWidth;
                          final cardWidth = (availableWidth - 36) / 4; // 4 cards with 12px gaps
                          
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildCompactCard(
                                title: 'Focus',
                                icon: Icons.track_changes,
                                content: mission.focus,
                                color: AppTheme.primary,
                                width: cardWidth,
                              ),
                              _buildCompactCard(
                                title: 'Structural Shift',
                                icon: Icons.transform,
                                content: mission.structuralShift,
                                color: AppTheme.primaryLight,
                                width: cardWidth,
                              ),
                              _buildCompactCard(
                                title: 'Capability Required',
                                icon: Icons.military_tech,
                                content: mission.capabilityRequired,
                                color: AppTheme.success,
                                width: cardWidth,
                              ),
                              _buildCompactCard(
                                title: 'Risk & Value Guardrail',
                                icon: Icons.security,
                                content: mission.riskOrValueGuardrail,
                                color: AppTheme.warning,
                                width: cardWidth,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Goals Placeholder
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.flag,
                            color: AppTheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Goals',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.graphite,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(48),
                        decoration: BoxDecoration(
                          color: AppTheme.grayLight.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.grayLight,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 48,
                                color: AppTheme.grayMedium,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Goals for this mission will appear here',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.grayMedium,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppTheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading mission',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.grayMedium,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.white.withOpacity(0.9),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRiskChip(RiskLevel riskLevel) {
    Color color;
    String label;
    
    switch (riskLevel) {
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
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCard({
    required String title,
    required IconData icon,
    required String content,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      height: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppTheme.graphite,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
