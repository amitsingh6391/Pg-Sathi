import 'package:equatable/equatable.dart';

/// Events for OwnerLibraryBloc.
sealed class OwnerLibraryEvent extends Equatable {
  const OwnerLibraryEvent();

  @override
  List<Object?> get props => [];
}

/// Load the owner's library and stats.
final class LoadOwnerLibrary extends OwnerLibraryEvent {
  const LoadOwnerLibrary({required this.ownerId});

  final String ownerId;

  @override
  List<Object?> get props => [ownerId];
}

/// Create a new library.
final class CreateLibraryRequested extends OwnerLibraryEvent {
  const CreateLibraryRequested({
    required this.name,
    required this.location,
    required this.capacity,
  });

  final String name;
  final String location;
  final int capacity;

  @override
  List<Object?> get props => [name, location, capacity];
}

/// Update existing library.
final class UpdateLibraryRequested extends OwnerLibraryEvent {
  const UpdateLibraryRequested({
    required this.name,
    required this.location,
    required this.capacity,
  });

  final String name;
  final String location;
  final int capacity;

  @override
  List<Object?> get props => [name, location, capacity];
}

/// Refresh library stats.
final class RefreshLibraryStats extends OwnerLibraryEvent {
  const RefreshLibraryStats();
}
