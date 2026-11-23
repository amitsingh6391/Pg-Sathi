import 'package:equatable/equatable.dart';

/// A manager's access to one PG (library). Pending until they first sign in.
class ManagerAccess extends Equatable {
  const ManagerAccess({
    required this.phone,
    required this.libraryId,
    this.userId,
    this.name,
  });

  /// E.164 phone number, e.g. +919876543210.
  final String phone;
  final String libraryId;

  /// Null while the invite is pending.
  final String? userId;
  final String? name;

  bool get isPending => userId == null;

  @override
  List<Object?> get props => [phone, libraryId, userId, name];
}
