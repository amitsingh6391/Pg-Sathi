import 'package:equatable/equatable.dart';

import 'labeled_link.dart';

class ExtractedJobFields extends Equatable {
  const ExtractedJobFields({
    this.title,
    this.postDate,
    this.shortInfo,
    this.vacancies,
    this.applicationStartDate,
    this.applicationEndDate,
    this.feeLastDate,
    this.examDateText,
    this.ageMin,
    this.ageMax,
    this.fees = const {},
    this.links = const [],
  });


  final String? title;

  final String? postDate;

  final String? shortInfo;

  final int? vacancies;

  final DateTime? applicationStartDate;
  final DateTime? applicationEndDate;
  final DateTime? feeLastDate;
  final String? examDateText;

  final int? ageMin;
  final int? ageMax;
  final Map<String, int> fees;

  final List<ExtractedLink> links;

  
  String? get applyUrl {
    final apply = _findByKind('apply');
    if (apply != null) return apply.url;
    return _findByKind('official')?.url;
  }

  String? get officialUrl => _findByKind('official')?.url;
  String? get notificationPdfUrl => _findByKind('notification')?.url;
  String? get syllabusPdfUrl => _findByKind('syllabus')?.url;

  /// "General / OBC / EWS" → fee in rupees, falling back to the first
  /// non-reserved bucket if that exact label isn't present.
  int? get generalFeeRupees {
    if (fees.isEmpty) return null;
    for (final key in fees.keys) {
      final l = key.toLowerCase();
      if (l.contains('general') && !l.contains('female')) return fees[key];
    }
    return fees.values.first;
  }

  /// "SC / ST" / reserved bucket → fee in rupees. Returns null when no
  /// reserved-category entry was found (some posts charge a flat fee).
  int? get reservedFeeRupees {
    for (final key in fees.keys) {
      final l = key.toLowerCase();
      if (l.contains('sc') || l.contains('st') || l.contains('ph') ||
          l.contains('female') || l.contains('divyang')) {
        return fees[key];
      }
    }
    return null;
  }

  /// True when the scraper produced enough data that the publish form
  /// will be meaningfully pre-filled. Used by the inbox to render a
  /// "rich data available" badge.
  bool get hasMeaningfulData =>
      vacancies != null ||
      applicationEndDate != null ||
      fees.isNotEmpty ||
      ageMin != null ||
      ageMax != null;

  ExtractedLink? _findByKind(String kind) {
    for (final link in links) {
      if (link.kind == kind && link.url.isNotEmpty) return link;
    }
    return null;
  }
  List<LabeledLink> toImportantLinks({required String aggregatorUrl}) {
    const sourceLabel = 'Source (admin reference)';

    final ordered = <LabeledLink>[];
    final seen = <String>{};

    void add(String label, String? url) {
      if (url == null || url.isEmpty) return;
      if (!seen.add(url)) return;
      ordered.add(LabeledLink(label: label, url: url));
    }
    add('Apply on Official Site', applyUrl);
    add('View Result', _findByKind('result')?.url);
    add('Download Admit Card', _findByKind('admitCard')?.url);

    // Supporting documents — always after the primary CTA so they
    // never out-rank the action a student came for.
    add('Notification PDF', notificationPdfUrl);
    add('Syllabus PDF', syllabusPdfUrl);
    if (officialUrl != null && applyUrl != officialUrl) {
      add('Official Website', officialUrl);
    }

    add(sourceLabel, aggregatorUrl);
    return List.unmodifiable(ordered);
  }

  ExtractedJobFields copyWith({
    String? title,
    String? postDate,
    String? shortInfo,
    int? vacancies,
    DateTime? applicationStartDate,
    DateTime? applicationEndDate,
    DateTime? feeLastDate,
    String? examDateText,
    int? ageMin,
    int? ageMax,
    Map<String, int>? fees,
    List<ExtractedLink>? links,
  }) {
    return ExtractedJobFields(
      title: title ?? this.title,
      postDate: postDate ?? this.postDate,
      shortInfo: shortInfo ?? this.shortInfo,
      vacancies: vacancies ?? this.vacancies,
      applicationStartDate: applicationStartDate ?? this.applicationStartDate,
      applicationEndDate: applicationEndDate ?? this.applicationEndDate,
      feeLastDate: feeLastDate ?? this.feeLastDate,
      examDateText: examDateText ?? this.examDateText,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      fees: fees ?? this.fees,
      links: links ?? this.links,
    );
  }

  @override
  List<Object?> get props => [
        title,
        postDate,
        shortInfo,
        vacancies,
        applicationStartDate,
        applicationEndDate,
        feeLastDate,
        examDateText,
        ageMin,
        ageMax,
        fees,
        links,
      ];
}

class ExtractedLink extends Equatable {
  const ExtractedLink({
    required this.label,
    required this.url,
    this.kind,
  });

  final String label;
  final String url;

  final String? kind;

  @override
  List<Object?> get props => [label, url, kind];
}
