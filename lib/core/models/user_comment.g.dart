// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserComment _$UserCommentFromJson(Map<String, dynamic> json) => UserComment(
  id: json['id'] as String,
  userId: json['userId'] as String,
  entityId: json['entityId'] as String,
  entityType: json['entityType'] as String,
  commentText: json['commentText'] as String,
  parentCommentId: json['parentCommentId'] as String?,
  createdAt: UserComment._dateTimeFromTimestamp(json['createdAt']),
  updatedAt: UserComment._dateTimeFromTimestamp(json['updatedAt']),
);

Map<String, dynamic> _$UserCommentToJson(UserComment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'entityId': instance.entityId,
      'entityType': instance.entityType,
      'commentText': instance.commentText,
      'parentCommentId': instance.parentCommentId,
      'createdAt': UserComment._dateTimeToTimestamp(instance.createdAt),
      'updatedAt': UserComment._dateTimeToTimestamp(instance.updatedAt),
    };
