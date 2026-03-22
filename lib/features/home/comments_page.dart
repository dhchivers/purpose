import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:purpose/core/models/user_comment.dart';
import 'package:purpose/core/models/user_value.dart';
import 'package:purpose/core/models/mission_document.dart';
import 'package:purpose/core/services/auth_provider.dart';
import 'package:purpose/core/services/firestore_provider.dart';
import 'package:purpose/core/services/goal_provider.dart';
import 'package:purpose/core/services/strategy_provider.dart';
import 'package:purpose/core/services/strategy_context_provider.dart';
import 'package:purpose/core/services/user_comment_provider.dart';
import 'package:purpose/core/theme/app_theme.dart';

final _valueByIdProvider = FutureProvider.family<UserValue?, String>((ref, id) async {
  return ref.read(firestoreServiceProvider).getUserValue(id);
});

final _missionByIdProvider = FutureProvider.family<MissionDocument?, String>((ref, id) async {
  return ref.read(firestoreServiceProvider).getMissionDocument(id);
});

const _kEntityTypeLabels = {
  'purpose': 'Purpose',
  'vision': 'Vision',
  'mission_map': 'Mission Map',
  'mission': 'Mission',
  'value': 'Core Value',
  'goal': 'Goal',
  'objective': 'Objective',
};

class CommentsPage extends ConsumerWidget {
  const CommentsPage({super.key});

  String _labelFor(String entityType) =>
      _kEntityTypeLabels[entityType] ?? entityType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStrategy = ref.watch(activeStrategyProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.graphite,
          foregroundColor: Colors.white,
          title: const Text('Comments', style: TextStyle(fontSize: 21)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: const Center(child: Text('Please log in')),
      );
    }

    final commentsAsync = ref.watch(commentsForUserStreamProvider(currentUser.uid));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.graphite,
        foregroundColor: Colors.white,
        title: Text(
          activeStrategy?.name ?? 'Comments',
          style: const TextStyle(fontSize: 21),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: commentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error loading comments: $e',
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ),
        data: (allComments) {
          final topLevel =
              allComments.where((c) => c.parentCommentId == null).toList();

          if (topLevel.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forum_outlined, size: 48, color: AppTheme.grayMedium),
                    SizedBox(height: 16),
                    Text(
                      'No comments yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.graphite,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Use the chat icon on any page to leave a comment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.grayMedium,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Group by entityType → entityId → List<UserComment>
          final grouped = <String, Map<String, List<UserComment>>>{};
          for (final comment in topLevel) {
            grouped
                .putIfAbsent(comment.entityType, () => {})
                .putIfAbsent(comment.entityId, () => [])
                .add(comment);
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: grouped.entries.expand((typeEntry) {
              final entityType = typeEntry.key;
              final typeLabel = _labelFor(entityType);
              final byEntity = typeEntry.value;
              return [
                // Entity type header
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    typeLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                // Entity sub-groups
                ...byEntity.entries.map((entityEntry) => _EntitySection(
                      entityType: entityType,
                      entityId: entityEntry.key,
                      comments: entityEntry.value,
                      allComments: allComments,
                      authorName: currentUser.fullName,
                    )),
              ];
            }).toList(),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entity section widget (collapsible entity info + comment cards)
// ---------------------------------------------------------------------------

class _EntitySection extends ConsumerStatefulWidget {
  final String entityType;
  final String entityId;
  final List<UserComment> comments;
  final List<UserComment> allComments;
  final String authorName;

  const _EntitySection({
    required this.entityType,
    required this.entityId,
    required this.comments,
    required this.allComments,
    required this.authorName,
  });

  @override
  ConsumerState<_EntitySection> createState() => _EntitySectionState();
}

class _EntitySectionState extends ConsumerState<_EntitySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    String entityTitle;
    String? entityDetail;
    String navRoute;

    if (widget.entityType == 'purpose') {
      final strategy = ref.watch(activeStrategyProvider);
      entityTitle = 'Purpose Statement';
      entityDetail = strategy?.purpose;
      navRoute = '/purpose';
    } else if (widget.entityType == 'vision') {
      final vision =
          ref.watch(strategyVisionProvider(widget.entityId)).value;
      entityTitle = 'Vision';
      entityDetail = vision?.visionStatement;
      navRoute = '/vision';
    } else if (widget.entityType == 'mission') {
      final mission =
          ref.watch(_missionByIdProvider(widget.entityId)).value;
      entityTitle = mission?.mission ?? 'Mission';
      entityDetail = mission?.focus;
      navRoute = '/mission/${widget.entityId}';
    } else if (widget.entityType == 'goal') {
      final goal = ref.watch(goalProvider(widget.entityId)).value;
      entityTitle = goal?.title ?? 'Goal';
      entityDetail = goal?.description;
      navRoute = goal != null
          ? '/mission/${goal.missionId}?goalId=${widget.entityId}'
          : '/mission';
    } else if (widget.entityType == 'objective') {
      final objective =
          ref.watch(objectiveProvider(widget.entityId)).value;
      entityTitle = objective?.title ?? 'Objective';
      entityDetail = objective?.description;
      navRoute = objective != null
          ? '/mission/${objective.missionId}?objectiveId=${widget.entityId}'
          : '/mission';
    } else if (widget.entityType == 'value') {
      final value = ref.watch(_valueByIdProvider(widget.entityId)).value;
      entityTitle = value?.refinedLabel ?? 'Core Value';
      entityDetail = value?.statement;
      navRoute = '/values/${widget.entityId}';
    } else {
      // mission_map or unknown
      entityTitle =
          _kEntityTypeLabels[widget.entityType] ?? widget.entityType;
      entityDetail = null;
      navRoute = '/mission';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collapsible entity info row
        Container(
          margin: const EdgeInsets.only(bottom: 6, top: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        bottomLeft: Radius.circular(6),
                      ),
                      onTap: () => context.go(navRoute),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.open_in_new,
                                size: 13, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                entityTitle,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (entityDetail != null)
                    IconButton(
                      onPressed: () =>
                          setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: AppTheme.grayMedium,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      constraints: const BoxConstraints(),
                      tooltip: _expanded ? 'Collapse' : 'Expand',
                    )
                  else
                    const SizedBox(width: 8),
                ],
              ),
              if (_expanded && entityDetail != null) ...[
                const Divider(height: 1, indent: 12, endIndent: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Text(
                    entityDetail,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.graphite,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Comment cards for this entity
        ...widget.comments.map((comment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CommentCard(
                comment: comment,
                authorName: widget.authorName,
                replies: widget.allComments
                    .where((c) => c.parentCommentId == comment.id)
                    .toList(),
              ),
            )),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Comment card widget
// ---------------------------------------------------------------------------

class _CommentCard extends ConsumerStatefulWidget {
  final UserComment comment;
  final String authorName;
  final List<UserComment> replies;

  const _CommentCard({
    required this.comment,
    required this.authorName,
    this.replies = const [],
  });

  @override
  ConsumerState<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends ConsumerState<_CommentCard> {
  bool _showReply = false;
  bool _isEditing = false;
  bool _isSaving = false;
  final _replyController = TextEditingController();
  final _editController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _submitEdit() async {
    final text = _editController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.updateUserComment(widget.comment.id, text);
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating comment: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _deleteComment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text(
            'This will permanently delete this comment and any replies.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.deleteUserComment(widget.comment.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error deleting comment: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('Not authenticated');
      final replyId =
          FirebaseFirestore.instance.collection('user_comments').doc().id;
      await firestoreService.saveUserComment(UserComment(
        id: replyId,
        userId: currentUser.uid,
        entityId: widget.comment.entityId,
        entityType: widget.comment.entityType,
        commentText: text,
        parentCommentId: widget.comment.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      _replyController.clear();
      setState(() {
        _showReply = false;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving reply: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryTintLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: date/author + action buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 12, color: AppTheme.grayMedium),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            DateFormat('MMM d, yyyy · h:mm a')
                                .format(widget.comment.createdAt),
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.grayMedium),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 13, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          widget.authorName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.comment.userId ==
                      ref.watch(currentUserProvider).value?.uid) ...[
                    IconButton(
                      onPressed: () => setState(() {
                        _isEditing = !_isEditing;
                        if (_isEditing) {
                          _editController.text = widget.comment.commentText;
                          _showReply = false;
                        } else {
                          _editController.clear();
                        }
                      }),
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color:
                            _isEditing ? AppTheme.primary : AppTheme.grayMedium,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _deleteComment,
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: AppTheme.grayMedium),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete',
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    onPressed: () => setState(() {
                      _showReply = !_showReply;
                      if (!_showReply) _replyController.clear();
                    }),
                    icon: Icon(
                      Icons.reply,
                      size: 16,
                      color:
                          _showReply ? AppTheme.primary : AppTheme.grayMedium,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Reply',
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 2),

          // Comment text or edit field
          if (_isEditing) ...[
            TextField(
              controller: _editController,
              maxLines: 3,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          _editController.clear();
                          setState(() => _isEditing = false);
                        },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submitEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ] else
            Text(
              widget.comment.commentText,
              style: const TextStyle(fontSize: 14, color: AppTheme.graphite),
            ),

          // Replies
          if (widget.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...widget.replies.map((reply) => Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 6),
                  child: _ReplyCard(
                    reply: reply,
                    authorName: widget.authorName,
                  ),
                )),
          ],

          // Reply input
          if (_showReply) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _replyController,
              maxLines: 3,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Write a reply...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          _replyController.clear();
                          setState(() => _showReply = false);
                        },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submitReply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Reply', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reply card widget (with edit + delete)
// ---------------------------------------------------------------------------

class _ReplyCard extends ConsumerStatefulWidget {
  final UserComment reply;
  final String authorName;

  const _ReplyCard({
    required this.reply,
    required this.authorName,
  });

  @override
  ConsumerState<_ReplyCard> createState() => _ReplyCardState();
}

class _ReplyCardState extends ConsumerState<_ReplyCard> {
  bool _isEditing = false;
  bool _isSaving = false;
  final _editController = TextEditingController();

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _submitEdit() async {
    final text = _editController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(firestoreServiceProvider).updateUserComment(widget.reply.id, text);
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating reply: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _deleteReply() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reply?'),
        content: const Text('This will permanently delete this reply.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(firestoreServiceProvider).deleteUserComment(widget.reply.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting reply: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider).value?.uid;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 2,
            margin: const EdgeInsets.only(right: 8, top: 2),
            color: AppTheme.primary.withOpacity(0.35),
          ),
          Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 10, color: AppTheme.grayMedium),
                            const SizedBox(width: 2),
                            Text(
                              DateFormat('MMM d · h:mm a').format(widget.reply.createdAt),
                              style: const TextStyle(fontSize: 10, color: AppTheme.grayMedium),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 11, color: AppTheme.primary),
                            const SizedBox(width: 3),
                            Text(
                              widget.authorName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.reply.userId == currentUserId) ...[
                    IconButton(
                      onPressed: () => setState(() {
                        _isEditing = !_isEditing;
                        if (_isEditing) {
                          _editController.text = widget.reply.commentText;
                        } else {
                          _editController.clear();
                        }
                      }),
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: _isEditing ? AppTheme.primary : AppTheme.grayMedium,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit',
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _deleteReply,
                      icon: const Icon(Icons.delete_outline, size: 14, color: AppTheme.grayMedium),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              if (_isEditing) ...[
                TextField(
                  controller: _editController,
                  maxLines: 3,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              _editController.clear();
                              setState(() => _isEditing = false);
                            },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _submitEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ] else
                Text(
                  widget.reply.commentText,
                  style: const TextStyle(fontSize: 13, color: AppTheme.graphite),
                ),
            ],
          ),
        ),
      ],
    ),  // Row
    ); // IntrinsicHeight
  }
}
