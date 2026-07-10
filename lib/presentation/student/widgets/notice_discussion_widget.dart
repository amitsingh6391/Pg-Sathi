import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/notice_comment_model.dart';
import '../../core/app_ui_constants.dart';

/// LinkedIn-style discussion section for notice comments
class NoticeDiscussionWidget extends StatefulWidget {
  const NoticeDiscussionWidget({
    super.key,
    required this.noticeId,
    required this.studentId,
    required this.studentName,
    required this.commentsStream,
    this.isOwnerView = false,
  });

  final String noticeId;
  final String studentId;
  final String studentName;
  final Stream<QuerySnapshot> commentsStream;
  final bool isOwnerView;

  @override
  State<NoticeDiscussionWidget> createState() => _NoticeDiscussionWidgetState();
}

class _NoticeDiscussionWidgetState extends State<NoticeDiscussionWidget> {
  final _commentController = TextEditingController();
  final _focusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppUIConstants.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          _buildCommentInput(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.commentsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments =
                    snapshot.data?.docs
                        .map((doc) => NoticeCommentModel.fromFirestore(doc))
                        .toList() ??
                    [];

                if (comments.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildCommentsList(comments);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.commentsStream,
      builder: (context, snapshot) {
        final commentCount = snapshot.data?.docs.length ?? 0;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Discussion',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$commentCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentInput() {
    return Container(
      color: AppUIConstants.surface,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF0A66C2),
            child: Text(
              widget.studentName.isNotEmpty
                  ? widget.studentName[0].toUpperCase()
                  : 'S',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppUIConstants.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppUIConstants.border),
              ),
              child: TextField(
                controller: _commentController,
                focusNode: _focusNode,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          if (_commentController.text.trim().isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: _postComment,
              icon: const Icon(Icons.send, color: Color(0xFF0A66C2)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Start the conversation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to comment on this notice',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList(List<NoticeCommentModel> comments) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildCommentCard(comments[index]);
      },
    );
  }

  Widget _buildCommentCard(NoticeCommentModel comment) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: comment.userRole == 'owner'
              ? const Color(0xFFFF6B35)
              : const Color(0xFF0A66C2),
          child: Text(
            comment.userName.isNotEmpty
                ? comment.userName[0].toUpperCase()
                : 'U',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment.userName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (comment.userRole == 'owner')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Owner',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    _formatDateTime(comment.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                comment.comment,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _postComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    try {
      final commentModel = NoticeCommentModel(
        id: '',
        noticeId: widget.noticeId,
        userId: widget.studentId,
        userName: widget.studentName,
        userRole: widget.isOwnerView ? 'owner' : 'student',
        comment: commentText,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('notice_comments')
          .add(commentModel.toFirestore());

      // Increment comment count on parent notice
      await _firestore.collection('notices').doc(widget.noticeId).update({
        'commentCount': FieldValue.increment(1),
        'lastCommentAt': FieldValue.serverTimestamp(),
      });

      // Send notification about new comment
      _sendCommentNotification(commentText);

      _commentController.clear();
      _focusNode.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
      }
    }
  }

  Future<void> _sendCommentNotification(String commentText) async {
    try {
      // Get the notice details to find the owner
      final noticeDoc = await _firestore
          .collection('notices')
          .doc(widget.noticeId)
          .get();

      if (!noticeDoc.exists) return;

      final noticeData = noticeDoc.data()!;
      final ownerId = noticeData['ownerId'] as String;
      final noticeTitle = noticeData['title'] as String;

      // Get all unique commenters (excluding current user)
      final commentsSnapshot = await _firestore
          .collection('notice_comments')
          .where('noticeId', isEqualTo: widget.noticeId)
          .get();

      final uniqueCommenters = commentsSnapshot.docs
          .map((doc) => doc.data()['userId'] as String)
          .where((userId) => userId != widget.studentId)
          .toSet()
          .toList();

      // Add owner if not already in list and not the commenter
      if (ownerId != widget.studentId && !uniqueCommenters.contains(ownerId)) {
        uniqueCommenters.insert(0, ownerId);
      }

      if (uniqueCommenters.isEmpty) return;

      // Prepare notification data
      final title = '${widget.studentName} commented on a notice';
      final body = commentText.length > 100
          ? '${commentText.substring(0, 100)}...'
          : commentText;

      // Send notification via Cloud Function
      await _firestore.collection('notifications').add({
        'userIds': uniqueCommenters,
        'title': title,
        'body': body,
        'data': {
          'type': 'comment',
          'notice_id': widget.noticeId,
          'notice_title': noticeTitle,
          'commenter_name': widget.studentName,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silent fail - notification is not critical
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }
}
