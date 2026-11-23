import 'package:dartz/dartz.dart';

import '../core/core.dart';
import '../repositories/reminder_template_repository.dart';

/// Reads the owner's saved reminder template.
class GetReminderTemplate implements UseCase<String?, NoParams> {
  const GetReminderTemplate({required this.repository});

  final ReminderTemplateRepository repository;

  @override
  Future<Either<Failure, String?>> call(NoParams params) {
    return repository.getTemplate();
  }
}

/// Saves the owner's reminder template, replacing any previous one.
class SaveReminderTemplate implements UseCase<void, String> {
  const SaveReminderTemplate({required this.repository});

  final ReminderTemplateRepository repository;

  @override
  Future<Either<Failure, void>> call(String template) {
    return repository.saveTemplate(template);
  }
}

/// Removes the saved reminder template.
class ClearReminderTemplate implements UseCase<void, NoParams> {
  const ClearReminderTemplate({required this.repository});

  final ReminderTemplateRepository repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return repository.clearTemplate();
  }
}
