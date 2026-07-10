import 'package:equatable/equatable.dart';

/// Base class for all domain failures.
/// Framework-agnostic, pure Dart.
abstract class Failure extends Equatable {
  const Failure({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}
