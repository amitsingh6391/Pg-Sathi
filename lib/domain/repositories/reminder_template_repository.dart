import 'package:dartz/dartz.dart';

import '../core/failure.dart';

/// Stores the owner's saved reminder message on this device.
abstract class ReminderTemplateRepository {
  /// Returns the saved template, or null when none is saved.
  Future<Either<Failure, String?>> getTemplate();

  Future<Either<Failure, void>> saveTemplate(String template);

  Future<Either<Failure, void>> clearTemplate();
}
