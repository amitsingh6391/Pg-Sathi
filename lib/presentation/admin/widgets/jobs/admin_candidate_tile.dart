import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../domain/entities/extracted_job_fields.dart';
import '../../../../domain/entities/job_alert_candidate.dart';
import '../../../core/app_ui_constants.dart';
import '../../cubit/jobs/admin_job_candidates_cubit.dart';
import '../../cubit/jobs/admin_jobs_cubit.dart';
import '../../screens/jobs/admin_job_form_screen.dart';

/// Inbox row for one [JobAlertCandidate]. Surfaces the scraper's
/// extracted vacancies / fees / deadline as muted preview chips so the
/// admin can decide whether to publish without opening the form.
///
/// Visual contract:
/// - Single hairline border, no shadows. Cards stack like a dense list.
/// - Selected state lifts to a 1.5px primary border (no fill change).
/// - Long-press anywhere enters multi-select; tap is publish-form.
class AdminCandidateTile extends StatelessWidget {
  const AdminCandidateTile({
    super.key,
    required this.candidate,
    required this.adminId,
    required this.isSelected,
    required this.selectionMode,
  });

  final JobAlertCandidate candidate;
  final String adminId;
  final bool isSelected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminJobCandidatesCubit>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: isSelected
              ? AppUIConstants.primary
              : AppUIConstants.border,
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          onTap: () {
            if (selectionMode) {
              cubit.toggleSelection(candidate.id);
            } else {
              _openForm(context);
            }
          },
          onLongPress: () => cubit.enterSelectionMode(
            initialId: candidate.id,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 10, top: 2),
                    child: _Checkbox(
                      checked: isSelected,
                      onChanged: (_) => cubit.toggleSelection(candidate.id),
                    ),
                  ),
                Expanded(child: _Body(candidate: candidate, adminId: adminId, selectionMode: selectionMode)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openForm(BuildContext context) {
    final jobsCubit = context.read<AdminJobsCubit>();
    final candidatesCubit = context.read<AdminJobCandidatesCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: jobsCubit),
            BlocProvider.value(value: candidatesCubit),
          ],
          child: AdminJobFormScreen(
            adminId: adminId,
            sourceCandidate: candidate,
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.candidate,
    required this.adminId,
    required this.selectionMode,
  });

  final JobAlertCandidate candidate;
  final String adminId;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final ex = candidate.extractedFields;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetaRow(candidate: candidate, hasRichData: ex?.hasMeaningfulData ?? false),
        const SizedBox(height: 10),
        Text(
          candidate.rawTitle,
          style: AppUIConstants.bodyLg,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (ex != null && ex.hasMeaningfulData) ...[
          const SizedBox(height: 10),
          _ExtractedPreview(fields: ex),
        ] else if ((candidate.rawDescription ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            candidate.rawDescription!,
            style: AppUIConstants.bodySm,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (!selectionMode) ...[
          const SizedBox(height: 12),
          _ActionRow(candidate: candidate, adminId: adminId),
        ],
      ],
    );
  }
}

/// Top meta line: category + scraper-data badge + fetched-at timestamp.
/// Uses muted neutrals so the row reads as supporting metadata, not a
/// primary affordance.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.candidate, required this.hasRichData});

  final JobAlertCandidate candidate;
  final bool hasRichData;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (candidate.suggestedCategory != null)
          _MutedBadge(text: candidate.suggestedCategory!.toUpperCase()),
        if (hasRichData) ...[
          const SizedBox(width: 6),
          _MutedBadge(
            text: 'AUTO-FILLED',
            tone: _BadgeTone.accent,
          ),
        ],
        const SizedBox(width: 8),
        Text(
          DateFormat('dd MMM').format(candidate.fetchedAt),
          style: AppUIConstants.caption,
        ),
      ],
    );
  }
}

/// Compact horizontal preview of the most decision-driving extracted
/// values: vacancies, deadline, fees. Hidden when nothing was scraped.
class _ExtractedPreview extends StatelessWidget {
  const _ExtractedPreview({required this.fields});

  final ExtractedJobFields fields;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (fields.vacancies != null) {
      chips.add(_PreviewChip(
        icon: Icons.people_outline_rounded,
        text: '${fields.vacancies} posts',
      ));
    }
    final endDate = fields.applicationEndDate;
    if (endDate != null) {
      chips.add(_PreviewChip(
        icon: Icons.event_rounded,
        text: 'Apply by ${DateFormat('dd MMM').format(endDate)}',
      ));
    }
    final general = fields.generalFeeRupees;
    if (general != null) {
      chips.add(_PreviewChip(
        icon: Icons.currency_rupee_rounded,
        text: general == 0 ? 'Free' : '₹$general',
      ));
    }
    if (fields.ageMin != null || fields.ageMax != null) {
      final min = fields.ageMin;
      final max = fields.ageMax;
      final text = (min != null && max != null)
          ? '$min–$max yrs'
          : (min != null ? 'Min $min yrs' : 'Max $max yrs');
      chips.add(_PreviewChip(icon: Icons.cake_outlined, text: text));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.candidate, required this.adminId});

  final JobAlertCandidate candidate;
  final String adminId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconAction(
          icon: Icons.open_in_new_rounded,
          label: 'View source',
          onTap: () => _openSource(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.close, size: 14),
            label: const Text('Ignore'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppUIConstants.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            onPressed: () => context
                .read<AdminJobCandidatesCubit>()
                .ignore(candidateId: candidate.id, adminId: adminId),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
            label: const Text('Publish'),
            style: FilledButton.styleFrom(
              backgroundColor: AppUIConstants.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            onPressed: () => _openForm(context),
          ),
        ),
      ],
    );
  }

  Future<void> _openSource(BuildContext context) async {
    final url = candidate.rawLink;
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open source page')),
      );
    }
  }

  void _openForm(BuildContext context) {
    final jobsCubit = context.read<AdminJobsCubit>();
    final candidatesCubit = context.read<AdminJobCandidatesCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: jobsCubit),
            BlocProvider.value(value: candidatesCubit),
          ],
          child: AdminJobFormScreen(
            adminId: adminId,
            sourceCandidate: candidate,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Muted UI primitives (kept private — used only here)
// =============================================================================

enum _BadgeTone { neutral, accent }

class _MutedBadge extends StatelessWidget {
  const _MutedBadge({required this.text, this.tone = _BadgeTone.neutral});

  final String text;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final fg = tone == _BadgeTone.accent
        ? AppUIConstants.accent
        : AppUIConstants.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        border: Border.all(color: AppUIConstants.border, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppUIConstants.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppUIConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked, required this.onChanged});
  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Checkbox(
        value: checked,
        onChanged: onChanged,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        activeColor: AppUIConstants.primary,
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(36, 36),
          padding: const EdgeInsets.all(0),
          foregroundColor: AppUIConstants.textSecondary,
          side: BorderSide(color: AppUIConstants.border),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}
