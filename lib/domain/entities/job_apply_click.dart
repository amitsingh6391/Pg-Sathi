import 'package:equatable/equatable.dart';

/// Analytics record for every time a student taps an outbound link on a
/// [JobAlert] detail screen. Drives the admin analytics dashboard and lets
/// us report click volume to affiliate partners.
class JobApplyClick extends Equatable {
  const JobApplyClick({
    required this.id,
    required this.userId,
    required this.jobId,
    required this.linkIndex,
    required this.destinationUrl,
    required this.clickedAt,
    this.partnerSource,
  });

  final String id;
  final String userId;
  final String jobId;

  /// Index into [JobAlert.importantLinks].
  final int linkIndex;

  final String destinationUrl;
  final DateTime clickedAt;

  /// Affiliate partner tag, e.g. "testbook" when the outbound URL belongs to
  /// a known partner. Null for official govt links.
  final String? partnerSource;

  @override
  List<Object?> get props => [
        id,
        userId,
        jobId,
        linkIndex,
        destinationUrl,
        clickedAt,
        partnerSource,
      ];
}
