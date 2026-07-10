import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/extracted_job_fields.dart';

/// Firestore (de)serialization for [ExtractedJobFields].
class ExtractedJobFieldsModel {
  const ExtractedJobFieldsModel._();

  static ExtractedJobFields? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    return ExtractedJobFields(
      title: _string(data['title']),
      postDate: _string(data['postDate']),
      shortInfo: _string(data['shortInfo']),
      vacancies: _int(data['vacancies']),
      applicationStartDate: _date(data['applicationStartDate']),
      applicationEndDate: _date(data['applicationEndDate']),
      feeLastDate: _date(data['feeLastDate']),
      examDateText: _string(data['examDateText']),
      ageMin: _int(data['ageMin']),
      ageMax: _int(data['ageMax']),
      fees: _fees(data['fees']),
      links: _links(data['links']),
    );
  }

  static Map<String, dynamic>? toMap(ExtractedJobFields? entity) {
    if (entity == null) return null;
    return {
      'title': entity.title,
      'postDate': entity.postDate,
      'shortInfo': entity.shortInfo,
      'vacancies': entity.vacancies,
      'applicationStartDate': entity.applicationStartDate == null
          ? null
          : Timestamp.fromDate(entity.applicationStartDate!),
      'applicationEndDate': entity.applicationEndDate == null
          ? null
          : Timestamp.fromDate(entity.applicationEndDate!),
      'feeLastDate': entity.feeLastDate == null
          ? null
          : Timestamp.fromDate(entity.feeLastDate!),
      'examDateText': entity.examDateText,
      'ageMin': entity.ageMin,
      'ageMax': entity.ageMax,
      'fees': entity.fees,
      'links': entity.links
          .map((l) => {
                'label': l.label,
                'url': l.url,
                'kind': l.kind,
              })
          .toList(growable: false),
    };
  }

  // ---------------------------------------------------------------------------
  // Defensive coercion helpers
  // ---------------------------------------------------------------------------

  static String? _string(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static DateTime? _date(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static Map<String, int> _fees(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, int>{};
    raw.forEach((key, value) {
      final amount = _int(value);
      if (amount == null) return;
      final label = key?.toString().trim() ?? '';
      if (label.isEmpty) return;
      out[label] = amount;
    });
    return out;
  }

  static List<ExtractedLink> _links(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ExtractedLink>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final label = _string(item['label']);
      final url = _string(item['url']);
      if (label == null || url == null) continue;
      out.add(ExtractedLink(
        label: label,
        url: url,
        kind: _string(item['kind']),
      ));
    }
    return List.unmodifiable(out);
  }
}
