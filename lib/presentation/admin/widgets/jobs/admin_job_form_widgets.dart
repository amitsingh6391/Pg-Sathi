import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/labeled_link.dart';
import '../../../core/app_ui_constants.dart';

/// Reusable building blocks for [AdminJobFormScreen].
///
/// Kept as private-style flat widgets in a dedicated file so the form
/// screen can stay focused on state + persistence (clean separation
/// between presentation primitives and orchestration).
///
/// Every widget here is stateless and pure — it accepts the data /
/// callbacks it needs and renders them. State (controllers, dates,
/// links, priority value) lives in the parent screen.

// =============================================================================
// Section card
// =============================================================================

class JobFormSection extends StatelessWidget {
  const JobFormSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppUIConstants.cardDecorationFlat,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppUIConstants.headingSm),
            const SizedBox(height: 10),
            for (final c in children)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: c,
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Auto-fill banner
// =============================================================================

class JobFormAutoFillBanner extends StatelessWidget {
  const JobFormAutoFillBanner({super.key, required this.filledCount});

  final int filledCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          border: Border.all(color: AppUIConstants.border),
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 16, color: AppUIConstants.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-filled $filledCount '
                    '${filledCount == 1 ? 'field' : 'fields'} from source',
                    style: AppUIConstants.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cross-check each value against the official notification before publishing.',
                    style: AppUIConstants.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Form field primitives
// =============================================================================

class JobFormField extends StatelessWidget {
  const JobFormField({
    super.key,
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.hint,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final String? hint;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppUIConstants.labelMd),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppUIConstants.textTertiary),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: _outlineBorder(),
            enabledBorder: _outlineBorder(),
            focusedBorder: _outlineBorder(focused: true),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}

class JobFormDropdown<T> extends StatelessWidget {
  const JobFormDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T) optionLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppUIConstants.labelMd),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          onChanged: (v) => onChanged(v as T),
          items: options
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(optionLabel(o)),
                  ))
              .toList(),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: _outlineBorder(),
            enabledBorder: _outlineBorder(),
            focusedBorder: _outlineBorder(focused: true),
          ),
        ),
      ],
    );
  }
}

class JobFormDateField extends StatelessWidget {
  const JobFormDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Not set'
        : DateFormat('dd MMM yyyy').format(value!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppUIConstants.labelMd),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              initialDate: value ?? DateTime.now(),
            );
            onChanged(picked);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppUIConstants.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 16, color: AppUIConstants.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(text, style: AppUIConstants.bodyMd)),
                if (value != null)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => onChanged(null),
                    icon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

OutlineInputBorder _outlineBorder({bool focused = false}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(
      color: focused ? AppUIConstants.primary : AppUIConstants.border,
      width: focused ? 1.5 : 1,
    ),
  );
}

// =============================================================================
// Apply URL warning header
// =============================================================================

class JobFormApplyUrlWarning extends StatelessWidget {
  const JobFormApplyUrlWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppUIConstants.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppUIConstants.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppUIConstants.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This must be the official government portal (e.g. '
              'ssc.nic.in, upsc.gov.in). Do not paste aggregator links '
              'like freejobalert.com — students tap this as "Apply".',
              style: AppUIConstants.caption,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Extras link list + add dialog
// =============================================================================

class JobFormExtrasSection extends StatelessWidget {
  const JobFormExtrasSection({
    super.key,
    required this.links,
    required this.onAdd,
    required this.onRemove,
  });

  final List<LabeledLink> links;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return JobFormSection(
      title: 'Extra links (optional)',
      children: [
        Text(
          'Add admit card, syllabus, notification PDF, etc.',
          style: AppUIConstants.caption,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < links.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LinkRow(
              link: links[i],
              onRemove: () => onRemove(i),
            ),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add link'),
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, required this.onRemove});

  final LabeledLink link;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppUIConstants.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  link.label,
                  style: AppUIConstants.bodyMd
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  link.url,
                  style: AppUIConstants.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppUIConstants.error,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Shows a modal to capture a (label, url) pair. Returns the new
/// [LabeledLink] or null if the user cancels / leaves either field empty.
Future<LabeledLink?> showAddLinkDialog(BuildContext context) async {
  final labelCtrl = TextEditingController();
  final urlCtrl = TextEditingController();
  try {
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (added != true) return null;
    final label = labelCtrl.text.trim();
    final url = urlCtrl.text.trim();
    if (label.isEmpty || url.isEmpty) return null;
    return LabeledLink(label: label, url: url);
  } finally {
    labelCtrl.dispose();
    urlCtrl.dispose();
  }
}

// =============================================================================
// Priority slider
// =============================================================================

class JobFormPrioritySection extends StatelessWidget {
  const JobFormPrioritySection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return JobFormSection(
      title: 'Priority',
      children: [
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: '$value',
                activeColor: AppUIConstants.accent,
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
            Container(
              width: 36,
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppUIConstants.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$value',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppUIConstants.accent,
                ),
              ),
            ),
          ],
        ),
        Text(
          'Higher priority jobs appear first and trigger urgent pushes.',
          style: AppUIConstants.bodySm,
        ),
      ],
    );
  }
}

// =============================================================================
// Validators
// =============================================================================

FormFieldValidator<String> jobFormNonEmpty(String fieldName) =>
    (value) => (value ?? '').trim().isEmpty ? '$fieldName is required' : null;

String? jobFormValidateApplyUrl(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return 'Official apply URL is required';
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.isAbsolute || !uri.hasScheme) {
    return 'Enter a full URL (https://...)';
  }
  return null;
}
