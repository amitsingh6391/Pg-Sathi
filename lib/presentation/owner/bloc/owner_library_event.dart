import 'package:equatable/equatable.dart';

/// Events for OwnerLibraryBloc.
sealed class OwnerLibraryEvent extends Equatable {
  const OwnerLibraryEvent();

  @override
  List<Object?> get props => [];
}

/// Load all libraries for the owner and select the first/default one.
final class LoadOwnerLibrary extends OwnerLibraryEvent {
  const LoadOwnerLibrary({required this.ownerId, this.managedLibraryIds});

  final String ownerId;

  /// Set for managers: restricts the branches to these libraries.
  final List<String>? managedLibraryIds;

  @override
  List<Object?> get props => [ownerId, managedLibraryIds];
}

/// Select a library by index in the list.
final class SelectLibrary extends OwnerLibraryEvent {
  const SelectLibrary({required this.index});

  final int index;

  @override
  List<Object?> get props => [index];
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
