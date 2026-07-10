import '../../domain/entities/job_alert.dart';
import '../../domain/entities/job_alert_candidate.dart';
import '../../domain/entities/labeled_link.dart';

class CandidateToJobAlertMapper {
  const CandidateToJobAlertMapper();

  JobAlert call(JobAlertCandidate candidate, String adminId) {
    final now = DateTime.now();
    final category = JobCategory.values.firstWhere(
      (c) => c.name == candidate.suggestedCategory,
      orElse: () => JobCategory.other,
    );

    final ex = candidate.extractedFields;
    final importantLinks = ex != null
        ? ex.toImportantLinks(aggregatorUrl: candidate.rawLink)
        : _legacyMinimalLinks(candidate);

    return JobAlert(
      id: '',
      title: candidate.rawTitle,
      organization: _inferOrganization(candidate.rawTitle),
      category: category,
      type: candidate.type,
      status: _statusFor(candidate.type),
      postedAt: candidate.rawPublishedAt ?? now,
      updatedAt: now,
      isActive: true,
      summary: ex?.shortInfo ?? candidate.rawDescription,
      vacancies: ex?.vacancies,
      ageLimit: _formatAgeRange(ex?.ageMin, ex?.ageMax),
      applicationStartDate: ex?.applicationStartDate,
      applicationEndDate: ex?.applicationEndDate,
      examDate: null,
      applicationFeeGeneralPaise: _rupeesToPaise(ex?.generalFeeRupees),
      applicationFeeReservedPaise: _rupeesToPaise(ex?.reservedFeeRupees),
      importantLinks: importantLinks,
      createdBy: adminId,
      sourceCandidateId: candidate.id,
    );
  }

  List<LabeledLink> _legacyMinimalLinks(JobAlertCandidate candidate) {
    final links = <LabeledLink>[];
    final applyUrl = candidate.suggestedApplyUrl;
    if (applyUrl != null && applyUrl.isNotEmpty) {
      links.add(LabeledLink(label: 'Apply on Official Site', url: applyUrl));
    }
    if (candidate.rawLink.isNotEmpty) {
      links.add(LabeledLink(
        label: 'Source (admin reference)',
        url: candidate.rawLink,
      ));
    }
    return List.unmodifiable(links);
  }

  String? _formatAgeRange(int? min, int? max) {
    if (min == null && max == null) return null;
    if (min != null && max != null) return '$min–$max years';
    if (min != null) return 'Min $min years';
    return 'Max $max years';
  }

  int? _rupeesToPaise(int? rupees) => rupees == null ? null : rupees * 100;

  JobStatus _statusFor(JobAlertType type) {
    switch (type) {
      case JobAlertType.recruitment:
        return JobStatus.openForApplication;
      case JobAlertType.result:
        return JobStatus.resultDeclared;
      case JobAlertType.admitCard:
        return JobStatus.admitCardOut;
    }
  }

  String _inferOrganization(String title) {
    final caps =
        RegExp(r'\b([A-Z]{2,}(?:\s*/\s*[A-Z]{2,})?)\b').firstMatch(title);
    if (caps != null) return caps.group(1)!;
    final words = title.trim().split(RegExp(r'\s+'));
    return words.take(3).join(' ');
  }
}
