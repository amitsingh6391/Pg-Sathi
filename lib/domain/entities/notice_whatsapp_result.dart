import 'package:equatable/equatable.dart';

/// Outcome of broadcasting a notice over WhatsApp.
class NoticeWhatsAppResult extends Equatable {
  const NoticeWhatsAppResult({
    required this.total,
    required this.sent,
    required this.failed,
    required this.noCredit,
  });

  final int total;
  final int sent;
  final int failed;

  /// Recipients skipped because the owner ran out of credits.
  final int noCredit;

  factory NoticeWhatsAppResult.fromMap(Map<String, dynamic> map) {
    int read(String key) => (map[key] as num?)?.toInt() ?? 0;
    return NoticeWhatsAppResult(
      total: read('total'),
      sent: read('sent'),
      failed: read('failed'),
      noCredit: read('noCredit'),
    );
  }

  @override
  List<Object?> get props => [total, sent, failed, noCredit];
}
