import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:unicons/unicons.dart';

import '../../../../domain/entities/reminder_template.dart';
import '../../../core/app_ui_constants.dart';
import '../../cubit/reminder_template_cubit.dart';
import '../../cubit/reminder_template_state.dart';

/// Save and remove actions for the owner's reminder template. A saved template
/// is applied to the message box automatically, so no apply action is needed.
/// Feedback is shown inline because a snackbar would sit behind this sheet.
class ReminderTemplateActions extends StatefulWidget {
  const ReminderTemplateActions({
    super.key,
    required this.bodyController,
    required this.values,
  });

  final TextEditingController bodyController;
  final ReminderTemplateValues values;

  @override
  State<ReminderTemplateActions> createState() =>
      _ReminderTemplateActionsState();
}

class _ReminderTemplateActionsState extends State<ReminderTemplateActions> {
  String? _feedback;
  Color _feedbackColor = AppUIConstants.success;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReminderTemplateCubit, ReminderTemplateState>(
      builder: (context, state) {
        final hasTemplate = state.hasTemplate;
        return Row(
          children: [
            Expanded(
              child: Text(
                _feedback ?? _hint(hasTemplate),
                style: AppUIConstants.caption.copyWith(
                  color: _feedback == null
                      ? AppUIConstants.textSecondary
                      : _feedbackColor,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _save(context),
              icon: const Icon(UniconsLine.bookmark, size: 18),
              label: const Text('Save'),
              style: TextButton.styleFrom(
                foregroundColor: AppUIConstants.primary,
                textStyle: AppUIConstants.labelMd,
              ),
            ),
            if (hasTemplate)
              IconButton(
                tooltip: 'Remove saved template',
                onPressed: () => _remove(context),
                icon: const Icon(
                  UniconsLine.trash_alt,
                  size: 20,
                  color: AppUIConstants.error,
                ),
              ),
          ],
        );
      },
    );
  }

  String _hint(bool hasTemplate) {
    return hasTemplate
        ? 'Your saved template is applied automatically.'
        : 'Save this message to reuse it for other residents.';
  }

  void _setFeedback(String message, {bool isError = false}) {
    setState(() {
      _feedback = message;
      _feedbackColor = isError ? AppUIConstants.error : AppUIConstants.success;
    });
  }

  Future<void> _save(BuildContext context) async {
    final template = ReminderTemplate.fromMessage(
      widget.bodyController.text,
      widget.values,
    );
    final saved = await context.read<ReminderTemplateCubit>().save(template);
    if (!mounted) return;
    _setFeedback(
      saved ? 'Template saved.' : 'Could not save the template.',
      isError: !saved,
    );
  }

  Future<void> _remove(BuildContext context) async {
    final removed = await context.read<ReminderTemplateCubit>().clear();
    if (!mounted) return;
    _setFeedback(
      removed ? 'Template removed.' : 'Could not remove the template.',
      isError: !removed,
    );
  }
}
