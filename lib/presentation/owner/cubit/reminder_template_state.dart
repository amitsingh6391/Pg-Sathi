import 'package:equatable/equatable.dart';

/// Saved reminder template. A null [template] means none is saved.
class ReminderTemplateState extends Equatable {
  const ReminderTemplateState({this.template});

  final String? template;

  bool get hasTemplate => template != null;

  @override
  List<Object?> get props => [template];
}
