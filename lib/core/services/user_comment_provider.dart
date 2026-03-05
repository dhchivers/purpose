import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/models/user_comment.dart';
import 'package:purpose/core/services/firestore_provider.dart';

/// Provider for a specific comment by ID (Future)
final userCommentProvider = FutureProvider.family<UserComment?, String>((ref, commentId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserComment(commentId);
});

/// Provider for comments on a specific entity (Stream - real-time updates)
/// Usage: ref.watch(commentsForEntityStreamProvider((entityId, entityType)))
final commentsForEntityStreamProvider = StreamProvider.family<List<UserComment>, (String, String)>(
  (ref, params) {
    final (entityId, entityType) = params;
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.commentsForEntityStream(entityId, entityType);
  },
);

/// Provider for replies to a specific comment (Future)
final repliesForCommentProvider = FutureProvider.family<List<UserComment>, String>((ref, commentId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getRepliesForComment(commentId);
});

/// Provider for all comments by a specific user (Future)
final commentsByUserProvider = FutureProvider.family<List<UserComment>, String>((ref, userId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getCommentsByUser(userId);
});

/// Provider to get comment count for an entity
final commentCountForEntityProvider = FutureProvider.family<int, (String, String)>(
  (ref, params) async {
    final (entityId, entityType) = params;
    final firestoreService = ref.watch(firestoreServiceProvider);
    final comments = await firestoreService.getCommentsForEntity(entityId, entityType);
    return comments.length;
  },
);
