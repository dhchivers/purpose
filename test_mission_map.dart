import 'dart:convert';
import 'package:purpose/core/services/gemini_service.dart';
import 'package:purpose/core/config/ai_config.dart';

void main() async {
  print('Testing Mission Map Generation...\n');
  
  // Initialize service
  final geminiService = GeminiService(apiKey: AIConfig.openAiApiKey);
  
  try {
    print('Generating mission map with test data...\n');
    
    final missions = await geminiService.generateMissionMap(
      // Context
      purposeStatement: 'To create systems that empower communities to solve local problems',
      coreValues: ['Integrity', 'Innovation', 'Community', 'Sustainability'],
      visionStatement: 'Communities worldwide are equipped with the tools, knowledge, and networks to solve their own challenges, reducing dependence on external intervention.',
      visionTimeframeYears: 10,
      
      // Step 1: Current State
      currentBuilding: 'A small consulting practice helping local nonprofits with strategic planning',
      currentScale: 'Working with 3-5 organizations in one city',
      currentAuthority: 'Individual consultant with some grassroots credibility',
      
      // Step 2: Vision State
      visionInfluenceScale: 'National',
      visionEnvironment: 'Network of community organizations and social enterprises',
      visionResponsibility: 'Leading a movement and platform that enables community-driven change',
      visionMeasurableChange: 'Hundreds of communities have solved critical problems using the frameworks and tools developed',
      
      // Step 3: Constraints
      constraintValues: ['Integrity', 'Community'],
      nonNegotiableCommitments: 'Must maintain work-life balance and family time',
      riskTolerance: 'Moderate - willing to take calculated risks but need financial stability',
    );
    
    print('\n✅ SUCCESS! Generated ${missions.length} missions:\n');
    print('=' * 80);
    
    for (var mission in missions) {
      print('\n${mission['mission']}');
      print('Sequence: ${mission['mission_sequence']}');
      print('Time Horizon: ${mission['time_horizon']}');
      print('\nFocus:');
      print('  ${mission['focus']}');
      print('\nStructural Shift:');
      print('  ${mission['structural_shift']}');
      print('\nCapability Required:');
      print('  ${mission['capability_required']}');
      print('\nRisk & Value Guardrails:');
      print('  ${mission['risk_or_value_guardrail']}');
      print('\n' + '-' * 80);
    }
    
    print('\n\nRAW JSON OUTPUT:');
    print('=' * 80);
    print(JsonEncoder.withIndent('  ').convert({'mission_map': missions}));
    print('=' * 80);
    
  } catch (e, stackTrace) {
    print('\n❌ FAILED');
    print('Error: $e');
    print('Stack trace: $stackTrace');
  }
}
