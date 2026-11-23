import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../../domain/entities/notice.dart';
import '../../../core/app_ui_constants.dart';

/// Asks for a link title + URL; returns null when cancelled.
Future<NoticeLink?> showNoticeAddLinkDialog(BuildContext context) {
  return showDialog<NoticeLink>(
    context: context,
    builder: (_) => const _AddLinkDialog(),
  );
}

class _AddLinkDialog extends StatefulWidget {
  const _AddLinkDialog();

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    var url = _urlController.text.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    Navigator.pop(
      context,
      NoticeLink(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        url: url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
      ),
      title: const Text('Add link', style: AppUIConstants.headingMd),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Fee payment form',
              ),
              validator: _required,
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            TextFormField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
              ),
              validator: _required,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppUIConstants.primary,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
