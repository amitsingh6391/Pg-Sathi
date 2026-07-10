import 'package:dartz/dartz.dart';

import 'failure.dart';

/// Base contract for all use cases.
/// Each use case has a single responsibility: execute one business operation.
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Marker class for use cases that require no parameters.
class NoParams {
  const NoParams();
}
