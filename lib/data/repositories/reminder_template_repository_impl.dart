import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/core/failure.dart';
import '../../domain/failures/reminder_template_failures.dart';
import '../../domain/repositories/reminder_template_repository.dart';

/// Keeps the reminder template in on-device SharedPreferences.
class ReminderTemplateRepositoryImpl implements ReminderTemplateRepository {
  ReminderTemplateRepositoryImpl(this._prefs);

  static const _keyTemplate = 'reminder_message_template';

  final SharedPreferences _prefs;

  @override
  Future<Either<Failure, String?>> getTemplate() async {
    try {
      return Right(_prefs.getString(_keyTemplate));
    } catch (_) {
      return const Left(ReminderTemplateStorageFailure());
    }
  }

  @override
  Future<Either<Failure, void>> saveTemplate(String template) async {
    try {
      await _prefs.setString(_keyTemplate, template);
      return const Right(null);
    } catch (_) {
      return const Left(ReminderTemplateStorageFailure());
    }
  }

  @override
  Future<Either<Failure, void>> clearTemplate() async {
    try {
      await _prefs.remove(_keyTemplate);
      return const Right(null);
    } catch (_) {
      return const Left(ReminderTemplateStorageFailure());
    }
  }
}
