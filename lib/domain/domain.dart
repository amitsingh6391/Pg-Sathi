/// Domain layer barrel export.
///
/// This layer contains pure business logic with no framework dependencies.
/// - Entities: Core business objects
/// - Repositories: Interfaces for data access (implemented in data layer)
/// - Use Cases: Business operations
/// - Failures: Explicit domain errors
library;

export 'core/core.dart';
export 'entities/entities.dart';
export 'failures/failures.dart';
export 'repositories/repositories.dart';
export 'usecases/usecases.dart';
export 'validators/validators.dart';
