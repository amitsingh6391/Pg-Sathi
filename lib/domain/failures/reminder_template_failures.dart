import '../core/failure.dart';

/// Failure when the device cannot read or store the reminder template.
class ReminderTemplateStorageFailure extends Failure {
  const ReminderTemplateStorageFailure({String? message})
    : super(message: message ?? 'Could not access the saved template');
}
