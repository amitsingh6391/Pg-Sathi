import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore model for notice comments
class NoticeCommentModel {
  const NoticeCommentModel({
    required this.id,
    required this.noticeId,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String noticeId;
  final String userId;
  final String userName;
  final String userRole; // 'student' or 'owner'
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory NoticeCommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NoticeCommentModel(
      id: doc.id,
      noticeId: data['noticeId'] as String,
      userId: data['userId'] as String,
      userName: data['userName'] as String,
      userRole: data['userRole'] as String,
      comment: data['comment'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'noticeId': noticeId,
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
