import 'package:json_annotation/json_annotation.dart';
import 'package:purpose/core/models/tier_analysis.dart';
import 'package:purpose/core/models/integrated_identity.dart';
import 'package:purpose/core/models/purpose_option.dart';

part 'identity_synthesis_result.g.dart';

/// Complete identity synthesis analysis result
@JsonSerializable(explicitToJson: true)
class IdentitySynthesisResult {
  /// Unique identifier for this analysis result
  final String id;

  /// User ID this analysis belongs to
  final String userId;

  /// Analysis results for each tier/module
  final List<TierAnalysis> tierAnalysis;

  /// Integrated cross-tier identity
  final IntegratedIdentity integratedIdentity;

  /// Three generated purpose statement options
  final List<PurposeOption> purposeOptions;

  /// When this analysis was created
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime createdAt;

  /// Hash of the question answers used for this analysis (to detect staleness)
  final String answersHash;

  /// Which option was selected by the user (index: 0, 1, or 2)
  final int? selectedOptionIndex;

  /// User's edited version of the selected statement (if edited)
  final String? editedStatement;

  /// Whether this statement was promoted to the user's purpose
  final bool isPromoted;

  const IdentitySynthesisResult({
    required this.id,
    required this.userId,
    required this.tierAnalysis,
    required this.integratedIdentity,
    required this.purposeOptions,
    required this.createdAt,
    required this.answersHash,
    this.selectedOptionIndex,
    this.editedStatement,
    this.isPromoted = false,
  });

  /// Creates an IdentitySynthesisResult from JSON
  factory IdentitySynthesisResult.fromJson(Map<String, dynamic> json) =>
      _$IdentitySynthesisResultFromJson(json);

  /// Converts IdentitySynthesisResult to JSON
  Map<String, dynamic> toJson() => _$IdentitySynthesisResultToJson(this);

  /// Helper to convert DateTime from Firestore Timestamp
  static DateTime _dateTimeFromJson(dynamic json) {
    if (json is int) {
      return DateTime.fromMillisecondsSinceEpoch(json);
    } else if (json is String) {
      return DateTime.parse(json);
    } else if (json is Map) {
      // Firestore Timestamp format
      return DateTime.fromMillisecondsSinceEpoch(json['_seconds'] * 1000);
    }
    return DateTime.now();
  }

  /// Helper to convert DateTime to JSON
  static dynamic _dateTimeToJson(DateTime dateTime) {
    return dateTime.toIso8601String();
  }

  /// Get the final purpose statement (edited or selected)
  String? get finalPurposeStatement {
    if (editedStatement != null && editedStatement!.isNotEmpty) {
      return editedStatement;
    }
    if (selectedOptionIndex != null && 
        selectedOptionIndex! >= 0 && 
        selectedOptionIndex! < purposeOptions.length) {
      return purposeOptions[selectedOptionIndex!].statement;
    }
    return null;
  }

  /// Creates a copy with updated fields
  IdentitySynthesisResult copyWith({
    String? id,
    String? userId,
    List<TierAnalysis>? tierAnalysis,
    IntegratedIdentity? integratedIdentity,
    List<PurposeOption>? purposeOptions,
    DateTime? createdAt,
    String? answersHash,
    int? selectedOptionIndex,
    String? editedStatement,
    bool? isPromoted,
  }) {
    return IdentitySynthesisResult(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tierAnalysis: tierAnalysis ?? this.tierAnalysis,
      integratedIdentity: integratedIdentity ?? this.integratedIdentity,
      purposeOptions: purposeOptions ?? this.purposeOptions,
      createdAt: createdAt ?? this.createdAt,
      answersHash: answersHash ?? this.answersHash,
      selectedOptionIndex: selectedOptionIndex ?? this.selectedOptionIndex,
      editedStatement: editedStatement ?? this.editedStatement,
      isPromoted: isPromoted ?? this.isPromoted,
    );
  }
}
