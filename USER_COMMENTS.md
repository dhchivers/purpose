# User Comments Collection

## Overview

The `user_comments` collection stores feedback, journal entries, and threaded comments from users on various entities throughout the application (goals, objectives, missions, etc.).

## Data Model

### UserComment Model
Located in: `lib/core/models/user_comment.dart`

**Fields:**
- `id` (String) - Unique identifier for the comment
- `userId` (String) - ID of the user who created the comment
- `entityId` (String) - ID of the entity being commented on
- `entityType` (String) - Type of entity (e.g., 'goal', 'objective', 'mission', 'journal')
- `commentText` (String) - The actual comment content
- `parentCommentId` (String?, nullable) - ID of parent comment for threaded replies
- `createdAt` (DateTime) - Timestamp when comment was created
- `updatedAt` (DateTime) - Timestamp when comment was last updated

### Entity Types

Supported entity types:
- `'goal'` - Comments on goals
- `'objective'` - Comments on objectives
- `'mission'` - Comments on mission documents
- `'journal'` - Personal journal entries
- Additional types can be added as needed

## Firestore Service Methods

Located in: `lib/core/services/firestore_service.dart`

### Save a Comment
```dart
Future<void> saveUserComment(UserComment comment)
```
Creates or updates a comment in Firestore.

**Example:**
```dart
final comment = UserComment(
  id: FirebaseFirestore.instance.collection('user_comments').doc().id,
  userId: currentUser.uid,
  entityId: goalId,
  entityType: 'goal',
  commentText: 'This goal is progressing well!',
  parentCommentId: null,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
await firestoreService.saveUserComment(comment);
```

### Get Comments for an Entity
```dart
Future<List<UserComment>> getCommentsForEntity(String entityId, String entityType)
Stream<List<UserComment>> commentsForEntityStream(String entityId, String entityType)
```
Retrieves all comments for a specific entity, ordered by newest first.

**Example:**
```dart
// One-time fetch
final comments = await firestoreService.getCommentsForEntity(goalId, 'goal');

// Real-time stream
ref.watch(commentsForEntityStreamProvider((goalId, 'goal')));
```

### Get Replies to a Comment
```dart
Future<List<UserComment>> getRepliesForComment(String parentCommentId)
```
Retrieves all replies to a specific comment (for threaded discussions).

**Example:**
```dart
final replies = await firestoreService.getRepliesForComment(commentId);
```

### Get Comments by User
```dart
Future<List<UserComment>> getCommentsByUser(String userId)
```
Retrieves all comments created by a specific user, ordered by newest first.

**Example:**
```dart
final myComments = await firestoreService.getCommentsByUser(currentUser.uid);
```

### Delete a Comment
```dart
Future<void> deleteUserComment(String commentId)
```
Deletes a comment and all its replies recursively.

**Example:**
```dart
await firestoreService.deleteUserComment(commentId);
```

## Firestore Indexes

The following composite indexes are configured in `firestore.indexes.json`:

### 1. Entity Comments Index
```json
{
  "entityId": "ASCENDING",
  "entityType": "ASCENDING",
  "createdAt": "DESCENDING"
}
```
Supports querying comments by entity with newest first.

### 2. Reply Threading Index
```json
{
  "parentCommentId": "ASCENDING",
  "createdAt": "ASCENDING"
}
```
Supports querying replies to a comment in chronological order.

### 3. User Comments Index
```json
{
  "userId": "ASCENDING",
  "createdAt": "DESCENDING"
}
```
Supports querying all comments by a user with newest first.

## Usage Examples

### Adding Feedback to a Goal

```dart
void _showFeedbackDialog(String goalId) async {
  final commentController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Provide Feedback'),
      content: TextField(
        controller: commentController,
        decoration: InputDecoration(
          labelText: 'Your feedback',
          hintText: 'Enter your thoughts...',
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final firestoreService = ref.read(firestoreServiceProvider);
            final authState = ref.read(authProvider);
            
            final comment = UserComment(
              id: FirebaseFirestore.instance
                  .collection('user_comments')
                  .doc()
                  .id,
              userId: authState.user!.uid,
              entityId: goalId,
              entityType: 'goal',
              commentText: commentController.text.trim(),
              parentCommentId: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            
            await firestoreService.saveUserComment(comment);
            Navigator.pop(context);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Feedback saved!')),
            );
          },
          child: Text('Save'),
        ),
      ],
    ),
  );
}
```

### Displaying Comments with Real-time Updates

```dart
class CommentsWidget extends ConsumerWidget {
  final String entityId;
  final String entityType;

  const CommentsWidget({
    required this.entityId,
    required this.entityType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(
      commentsForEntityStreamProvider((entityId, entityType))
    );

    return commentsAsync.when(
      data: (comments) {
        if (comments.isEmpty) {
          return Text('No comments yet');
        }
        
        return ListView.builder(
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            return ListTile(
              title: Text(comment.commentText),
              subtitle: Text(
                DateFormat('MMM d, yyyy - h:mm a').format(comment.createdAt)
              ),
            );
          },
        );
      },
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

### Adding Threaded Replies

```dart
Future<void> _addReply(String parentCommentId, String goalId) async {
  final replyController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Add Reply'),
      content: TextField(
        controller: replyController,
        decoration: InputDecoration(labelText: 'Your reply'),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final firestoreService = ref.read(firestoreServiceProvider);
            final authState = ref.read(authProvider);
            
            final reply = UserComment(
              id: FirebaseFirestore.instance
                  .collection('user_comments')
                  .doc()
                  .id,
              userId: authState.user!.uid,
              entityId: goalId,
              entityType: 'goal',
              commentText: replyController.text.trim(),
              parentCommentId: parentCommentId, // Link to parent
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            
            await firestoreService.saveUserComment(reply);
            Navigator.pop(context);
          },
          child: Text('Reply'),
        ),
      ],
    ),
  );
}
```

## Firestore Rules

Currently using permissive rules for development:

```javascript
match /user_comments/{commentId} {
  allow read, write: if true;
}
```

**TODO:** Implement secure rules for production:

```javascript
match /user_comments/{commentId} {
  // Allow users to read all comments
  allow read: if request.auth != null;
  
  // Allow users to create comments
  allow create: if request.auth != null
    && request.resource.data.userId == request.auth.uid;
  
  // Allow users to update/delete their own comments
  allow update, delete: if request.auth != null
    && resource.data.userId == request.auth.uid;
}
```

## Integration Points

### With Goals and Objectives

The feedback button placeholders on goal and objective cards should be connected to the comment system:

```dart
IconButton(
  onPressed: () => _showFeedbackDialog(goalId),
  icon: Icon(Icons.feedback_outlined, size: 20),
  color: AppTheme.grayMedium,
  tooltip: 'Provide Feedback',
),
```

### With Journal Entries

Journal entries can be implemented as comments with entityType='journal':

```dart
final journalEntry = UserComment(
  id: FirebaseFirestore.instance.collection('user_comments').doc().id,
  userId: currentUser.uid,
  entityId: currentUser.uid, // Journal is user-specific
  entityType: 'journal',
  commentText: 'Today I made progress on my goals...',
  parentCommentId: null,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

## Best Practices

1. **Always validate comment text** - Ensure non-empty before saving
2. **Use parentCommentId for threading** - Set to null for top-level comments
3. **Delete recursively** - When deleting a comment, delete all replies
4. **Show author names** - Use UserModel.fullName with the userId field
5. **Allow editing** - Users should be able to edit their own comments (update commentText and updatedAt)
6. **Pagination** - For entities with many comments, implement pagination using Firestore's limit() and startAfter()

## Future Enhancements

1. **Rich text formatting** - Support markdown or rich text in comments
2. **Attachments** - Allow users to attach images or files
3. **Reactions** - Add emoji reactions or likes to comments
4. **Mentions** - Support @username mentions in comments
5. **Edit history** - Track comment edit history
6. **Moderation** - Add flagging/reporting mechanism for inappropriate content
7. **Notifications** - Notify users when someone replies to their comment

## Related Documentation

- [DATA_MODELS.md](DATA_MODELS.md) - Overview of all data models
- [FIRESTORE_DATA_MODEL.md](FIRESTORE_DATA_MODEL.md) - Complete Firestore schema
- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Testing procedures

---

## Summary

The user_comments collection provides a flexible, extensible system for collecting user feedback, journal entries, and threaded discussions throughout the application. With proper indexing and the provided service methods, it supports efficient queries for entity-based comments, user activity, and threaded conversations.
