import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/extracted_job_fields.dart';
import '../../../../domain/entities/job_alert.dart';
import '../../../../domain/entities/job_alert_candidate.dart';
import '../../../../domain/entities/labeled_link.dart';
import '../../../core/app_ui_constants.dart';
import '../../cubit/jobs/admin_job_candidates_cubit.dart';
import '../../cubit/jobs/admin_jobs_cubit.dart';
import '../../widgets/jobs/admin_job_form_widgets.dart';

/// Reusable create / edit form for [JobAlert].
///
/// Three entry points:
/// - **edit**: pass [existing] — every field hydrates from the live alert.
/// - **publish from candidate**: pass [sourceCandidate] — fields pre-fill
///   from the scraper's [ExtractedJobFields] when available, with an
///   "auto-filled N fields" banner so the admin verifies before saving.
/// - **blank create**: pass neither — empty form with sensible defaults.
///
/// Stays under 600 LOC by delegating all field/section primitives to
/// `admin_job_form_widgets.dart`. The state class only owns controllers,
/// dates, links, priority — and the publish/save side effect.
class AdminJobFormScreen extends StatefulWidget {
  const AdminJobFormScreen({
    super.key,
    required this.adminId,
    this.existing,
    this.sourceCandidate,
  });

  final String adminId;
  final JobAlert? existing;
  final JobAlertCandidate? sourceCandidate;

  @override
  State<AdminJobFormScreen> createState() => _AdminJobFormScreenState();
}

class _AdminJobFormScreenState extends State<AdminJobFormScreen> {
  static const _kApplyLabel = 'Apply on Official Site';
  static const _kSourceLabel = 'Source (admin reference)';

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _organization;
  late final TextEditingController _summary;
  late final TextEditingController _details;
  late final TextEditingController _vacancies;
  late final TextEditingController _eligibility;
  late final TextEditingController _ageLimit;
  late final TextEditingController _feeGeneral;
  late final TextEditingController _feeReserved;
  late final TextEditingController _stateCode;

  /// Canonical URL students use when they tap "Apply". Must point to
  /// the official government / exam portal, not the aggregator site.
  late final TextEditingController _applyUrl;

  /// Aggregator URL we fetched this candidate from. Admin-only
  /// reference — never surfaced as a primary CTA to students.
  late final TextEditingController _sourceUrl;

  JobCategory _category = JobCategory.ssc;
  JobStatus _status = JobStatus.openForApplication;
  int _priority = 5;
  DateTime? _applicationStart;
  DateTime? _applicationEnd;
  DateTime? _examDate;
  final List<LabeledLink> _extraLinks = [];

  /// Number of fields the auto-fill hydration touched. Drives the
  /// "verify before publishing" banner at the top of the form.
  int _autoFilledCount = 0;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final cand = widget.sourceCandidate;
    _title = TextEditingController(text: e?.title ?? cand?.rawTitle ?? '');
    _organization = TextEditingController(text: e?.organization ?? '');
    _summary = TextEditingController(
      text: e?.summary ?? cand?.rawDescription ?? '',
    );
    _details = TextEditingController(text: e?.detailsMarkdown ?? '');
    _vacancies = TextEditingController(text: e?.vacancies?.toString() ?? '');
    _eligibility = TextEditingController(text: e?.eligibility ?? '');
    _ageLimit = TextEditingController(text: e?.ageLimit ?? '');
    _feeGeneral = TextEditingController(
      text: _paiseToRupeesString(e?.applicationFeeGeneralPaise),
    );
    _feeReserved = TextEditingController(
      text: _paiseToRupeesString(e?.applicationFeeReservedPaise),
    );
    _stateCode = TextEditingController(text: e?.state ?? '');
    _applyUrl = TextEditingController();
    _sourceUrl = TextEditingController();

    if (e != null) {
      _category = e.category;
      _status = e.status;
      _priority = e.priority;
      _applicationStart = e.applicationStartDate;
      _applicationEnd = e.applicationEndDate;
      _examDate = e.examDate;
      _hydrateLinksFromEntity(e.importantLinks);
    } else if (cand != null) {
      _category = JobCategory.values.firstWhere(
        (c) => c.name == cand.suggestedCategory,
        orElse: () => JobCategory.other,
      );
      if (cand.rawLink.isNotEmpty) _sourceUrl.text = cand.rawLink;
      _hydrateFromExtractedFields(cand);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _organization.dispose();
    _summary.dispose();
    _details.dispose();
    _vacancies.dispose();
    _eligibility.dispose();
    _ageLimit.dispose();
    _feeGeneral.dispose();
    _feeReserved.dispose();
    _stateCode.dispose();
    _applyUrl.dispose();
    _sourceUrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Hydration
  // ---------------------------------------------------------------------------

  void _hydrateLinksFromEntity(List<LabeledLink> links) {
    for (final link in links) {
      if (link.label == _kApplyLabel && _applyUrl.text.isEmpty) {
        _applyUrl.text = link.url;
      } else if (link.label == _kSourceLabel && _sourceUrl.text.isEmpty) {
        _sourceUrl.text = link.url;
      } else {
        _extraLinks.add(link);
      }
    }
  }

  /// Pulls every value the scraper extracted into the matching form
  /// controller / state field. Tracks how many fields actually got
  /// populated so the banner is accurate (no "auto-filled 0 fields").
  void _hydrateFromExtractedFields(JobAlertCandidate cand) {
    int filled = 0;

    final applySuggestion = cand.suggestedApplyUrl;
    if (applySuggestion != null && applySuggestion.isNotEmpty) {
      _applyUrl.text = applySuggestion;
      filled += 1;
    }

    final ex = cand.extractedFields;
    if (ex == null) {
      _autoFilledCount = filled;
      return;
    }

    if (_organization.text.isEmpty) {
      final inferred = _inferOrgFromTitle(cand.rawTitle);
      if (inferred.isNotEmpty) {
        _organization.text = inferred;
        filled += 1;
      }
    }
    if (_summary.text.isEmpty && (ex.shortInfo ?? '').isNotEmpty) {
      _summary.text = ex.shortInfo!;
      filled += 1;
    }
    if (ex.vacancies != null) {
      _vacancies.text = ex.vacancies!.toString();
      filled += 1;
    }
    final ageRange = _formatAgeRange(ex.ageMin, ex.ageMax);
    if (ageRange != null) {
      _ageLimit.text = ageRange;
      filled += 1;
    }
    if (ex.generalFeeRupees != null) {
      _feeGeneral.text = ex.generalFeeRupees!.toString();
      filled += 1;
    }
    if (ex.reservedFeeRupees != null) {
      _feeReserved.text = ex.reservedFeeRupees!.toString();
      filled += 1;
    }
    if (ex.applicationStartDate != null) {
      _applicationStart = ex.applicationStartDate;
      filled += 1;
    }
    if (ex.applicationEndDate != null) {
      _applicationEnd = ex.applicationEndDate;
      filled += 1;
    }

    final adoptedExtras = ex.links
        .where((l) =>
            l.kind != null &&
            l.kind != 'apply' &&
            l.kind != 'official' &&
            l.url.isNotEmpty)
        .map((l) => LabeledLink(label: _kindLabel(l.kind!), url: l.url));
    _extraLinks.addAll(adoptedExtras);
    if (adoptedExtras.isNotEmpty) filled += adoptedExtras.length;

    _autoFilledCount = filled;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isEdit ? 'Edit Job' : 'Publish Job',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_autoFilledCount > 0)
              JobFormAutoFillBanner(filledCount: _autoFilledCount),
            JobFormSection(title: 'Basics', children: [
              JobFormField(
                label: 'Title *',
                controller: _title,
                maxLines: 2,
                validator: jobFormNonEmpty('Title'),
              ),
              JobFormField(
                label: 'Organization *',
                controller: _organization,
                validator: jobFormNonEmpty('Organization'),
              ),
              JobFormDropdown<JobCategory>(
                label: 'Category',
                value: _category,
                options: JobCategory.values,
                optionLabel: (c) => c.label,
                onChanged: (v) => setState(() => _category = v),
              ),
              JobFormDropdown<JobStatus>(
                label: 'Status',
                value: _status,
                options: JobStatus.values,
                optionLabel: (s) => s.label,
                onChanged: (v) => setState(() => _status = v),
              ),
              JobFormField(
                label: 'State (optional)',
                controller: _stateCode,
                hint: 'e.g. Bihar (for state-specific roles)',
              ),
            ]),
            JobFormSection(title: 'Numbers', children: [
              JobFormField(
                label: 'Vacancies',
                controller: _vacancies,
                keyboardType: TextInputType.number,
              ),
              JobFormField(
                label: 'Application fee ₹ (General)',
                controller: _feeGeneral,
                keyboardType: TextInputType.number,
              ),
              JobFormField(
                label: 'Application fee ₹ (SC/ST/Women)',
                controller: _feeReserved,
                keyboardType: TextInputType.number,
              ),
              JobFormField(
                label: 'Age limit',
                controller: _ageLimit,
                hint: 'e.g. 18-32 years',
              ),
            ]),
            JobFormSection(title: 'Dates', children: [
              JobFormDateField(
                label: 'Application start',
                value: _applicationStart,
                onChanged: (d) => setState(() => _applicationStart = d),
              ),
              JobFormDateField(
                label: 'Last date to apply',
                value: _applicationEnd,
                onChanged: (d) => setState(() => _applicationEnd = d),
              ),
              JobFormDateField(
                label: 'Exam date',
                value: _examDate,
                onChanged: (d) => setState(() => _examDate = d),
              ),
            ]),
            JobFormSection(title: 'Content', children: [
              JobFormField(
                label: 'Summary',
                controller: _summary,
                maxLines: 3,
              ),
              JobFormField(
                label: 'Full details (markdown)',
                controller: _details,
                maxLines: 8,
              ),
              JobFormField(
                label: 'Eligibility',
                controller: _eligibility,
                maxLines: 2,
              ),
            ]),
            _buildApplyUrlSection(),
            JobFormExtrasSection(
              links: _extraLinks,
              onAdd: _addLink,
              onRemove: (i) => setState(() => _extraLinks.removeAt(i)),
            ),
            JobFormPrioritySection(
              value: _priority,
              onChanged: (v) => setState(() => _priority = v),
            ),
            const SizedBox(height: 20),
            _buildSaveButton(isEdit),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyUrlSection() {
    return JobFormSection(title: 'Apply URL *', children: [
      const JobFormApplyUrlWarning(),
      const SizedBox(height: 10),
      JobFormField(
        label: 'Official apply URL *',
        controller: _applyUrl,
        hint: 'https://www.official-site.gov.in/...',
        keyboardType: TextInputType.url,
        validator: jobFormValidateApplyUrl,
      ),
      if (_sourceUrl.text.isNotEmpty) ...[
        const SizedBox(height: 10),
        JobFormField(
          label: 'Source (aggregator — admin reference)',
          controller: _sourceUrl,
          hint: 'Where we fetched this lead from',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 4),
        Text(
          'Not shown to students. Use to cross-check details.',
          style: AppUIConstants.caption.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ]);
  }

  Widget _buildSaveButton(bool isEdit) {
    return BlocBuilder<AdminJobsCubit, dynamic>(
      builder: (context, _) {
        final isSaving = context.select<AdminJobsCubit, bool>(
          (c) => c.state.isSaving,
        );
        return SizedBox(
          height: 48,
          child: ElevatedButton(
            style: AppUIConstants.primaryButtonStyle,
            onPressed: isSaving ? null : () => _submit(isEdit),
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(isEdit ? 'Save Changes' : 'Publish Job'),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<void> _addLink() async {
    final link = await showAddLinkDialog(context);
    if (link == null || !mounted) return;
    setState(() => _extraLinks.add(link));
  }

  Future<void> _submit(bool isEdit) async {
    if (!_formKey.currentState!.validate()) return;
    final draft = _buildDraft();
    final cubit = context.read<AdminJobsCubit>();

    final success = isEdit
        ? await cubit.update(draft)
        : await cubit.publish(
            draft: draft,
            adminId: widget.adminId,
            candidateId: widget.sourceCandidate?.id,
          );

    if (!mounted) return;

    if (!success) {
      final msg = cubit.state.failure?.message ?? 'Could not save job';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppUIConstants.error,
        ),
      );
      return;
    }

    final candidateId = widget.sourceCandidate?.id;
    if (!isEdit && candidateId != null) {
      try {
        context
            .read<AdminJobCandidatesCubit>()
            .markPublishedLocally(candidateId);
      } catch (_) {
        // Candidate cubit may not be in the widget tree when editing
        // from the Manage list — that path is expected to be a no-op.
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEdit ? 'Job updated' : 'Job published'),
        backgroundColor: AppUIConstants.success,
      ),
    );
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // Draft assembly
  // ---------------------------------------------------------------------------

  JobAlert _buildDraft() {
    final now = DateTime.now();
    final existing = widget.existing;
    return JobAlert(
      id: existing?.id ?? '',
      title: _title.text.trim(),
      organization: _organization.text.trim(),
      category: _category,
      state: _stateCode.text.trim().isEmpty ? null : _stateCode.text.trim(),
      status: _status,
      vacancies: int.tryParse(_vacancies.text.trim()),
      eligibility: _eligibility.text.trim().isEmpty
          ? null
          : _eligibility.text.trim(),
      ageLimit:
          _ageLimit.text.trim().isEmpty ? null : _ageLimit.text.trim(),
      applicationStartDate: _applicationStart,
      applicationEndDate: _applicationEnd,
      examDate: _examDate,
      applicationFeeGeneralPaise: _rupeesStringToPaise(_feeGeneral.text),
      applicationFeeReservedPaise: _rupeesStringToPaise(_feeReserved.text),
      summary: _summary.text.trim().isEmpty ? null : _summary.text.trim(),
      detailsMarkdown:
          _details.text.trim().isEmpty ? null : _details.text.trim(),
      coverImageUrl: existing?.coverImageUrl,
      importantLinks: _collectLinks(),
      sponsoredByPartnerId: existing?.sponsoredByPartnerId,
      priority: _priority,
      viewCount: existing?.viewCount ?? 0,
      applyClickCount: existing?.applyClickCount ?? 0,
      bookmarkCount: existing?.bookmarkCount ?? 0,
      postedAt: existing?.postedAt ?? now,
      updatedAt: now,
      isActive: existing?.isActive ?? true,
      sourceCandidateId:
          existing?.sourceCandidateId ?? widget.sourceCandidate?.id,
      createdBy: existing?.createdBy ?? widget.adminId,
    );
  }

  /// Reassembles the flat `importantLinks` list in a stable order:
  ///   1) the official apply URL first (students' primary CTA),
  ///   2) any admin-added extras next (admit card, syllabus, etc.),
  ///   3) the aggregator source URL last, preserved for traceability.
  List<LabeledLink> _collectLinks() {
    final links = <LabeledLink>[
      LabeledLink(label: _kApplyLabel, url: _applyUrl.text.trim()),
      ..._extraLinks,
    ];
    final source = _sourceUrl.text.trim();
    if (source.isNotEmpty) {
      links.add(LabeledLink(label: _kSourceLabel, url: source));
    }
    return List.unmodifiable(links);
  }

  // ---------------------------------------------------------------------------
  // Pure helpers
  // ---------------------------------------------------------------------------

  String _paiseToRupeesString(int? paise) =>
      paise == null ? '' : (paise / 100).toStringAsFixed(0);

  int? _rupeesStringToPaise(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final rupees = int.tryParse(trimmed);
    return rupees == null ? null : rupees * 100;
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'notification':
        return 'Notification PDF';
      case 'syllabus':
        return 'Syllabus PDF';
      case 'admitCard':
        return 'Admit Card';
      case 'result':
        return 'Result';
      case 'examDate':
        return 'Exam Date Notice';
      default:
        return kind;
    }
  }

  String? _formatAgeRange(int? min, int? max) {
    if (min == null && max == null) return null;
    if (min != null && max != null) return '$min–$max years';
    if (min != null) return 'Min $min years';
    return 'Max $max years';
  }

  String _inferOrgFromTitle(String title) {
    final caps =
        RegExp(r'\b([A-Z]{2,}(?:\s*/\s*[A-Z]{2,})?)\b').firstMatch(title);
    if (caps != null) return caps.group(1)!;
    final words = title.trim().split(RegExp(r'\s+'));
    return words.take(3).join(' ');
  }
}
