// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  uid: json['uid'] as String,
  email: json['email'] as String,
  userType: json['userType'] == null
      ? UserType.member
      : _userTypeFromJson(json['userType'] as String?),
  fullName: json['fullName'] as String,
  age: (json['age'] as num?)?.toInt(),
  location: json['location'] as String?,
  photoUrl: json['photoUrl'] as String?,
  createdAt: _dateTimeFromJson(json['createdAt']),
  moduleProgress: (json['moduleProgress'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, ModuleProgress.fromJson(e as Map<String, dynamic>)),
  ),
  completedModuleIds: (json['completedModuleIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  updatedAt: _dateTimeFromJson(json['updatedAt']),
  emailVerified: json['emailVerified'] as bool,
  purpose: json['purpose'] as String?,
  vision: json['vision'] as String?,
  mission: json['mission'] as String?,
  goalIds: (json['goalIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'uid': instance.uid,
  'email': instance.email,
  'userType': _userTypeToJson(instance.userType),
  'fullName': instance.fullName,
  'age': instance.age,
  'location': instance.location,
  'photoUrl': instance.photoUrl,
  'createdAt': _dateTimeToJson(instance.createdAt),
  'updatedAt': _dateTimeToJson(instance.updatedAt),
  'emailVerified': instance.emailVerified,
  'purpose': instance.purpose,
  'vision': instance.vision,
  'mission': instance.mission,
  'goalIds': instance.goalIds,
  'onboardingCompleted': instance.onboardingCompleted,
  'moduleProgress': instance.moduleProgress,
  'completedModuleIds': instance.completedModuleIds,
};
