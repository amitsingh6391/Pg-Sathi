import 'package:equatable/equatable.dart';

import '../../../domain/entities/library.dart';

/// State for library form cubit.
class LibraryFormState extends Equatable {
  const LibraryFormState({
    this.status = LibraryFormStatus.initial,
    this.library,
    this.currentSection = 0,
    this.errorMessage,
    this.validationErrors = const [],
    this.isEditing = false,
  });

  final LibraryFormStatus status;
  final Library? library;
  final int currentSection;
  final String? errorMessage;
  final List<String> validationErrors;
  final bool isEditing;

  bool get isLoading => status == LibraryFormStatus.loading;
  bool get isSuccess => status == LibraryFormStatus.success;
  bool get isError => status == LibraryFormStatus.error;
  bool get isSaving => status == LibraryFormStatus.saving;

  /// Total number of form sections.
  static const int totalSections = 6;

  /// Section names.
  static const List<String> sectionNames = [
    'Basic Info',
    'Location',
    'Facilities',
    'Payment Settings',
    'Bed Groups',
    'PG Photos',
  ];

  String get currentSectionName =>
      currentSection < sectionNames.length ? sectionNames[currentSection] : '';

  bool get isFirstSection => currentSection == 0;
  bool get isLastSection => currentSection == totalSections - 1;

  /// Progress percentage (0.0 - 1.0).
  double get progress => (currentSection + 1) / totalSections;

  LibraryFormState copyWith({
    LibraryFormStatus? status,
    Library? library,
    int? currentSection,
    String? errorMessage,
    List<String>? validationErrors,
    bool? isEditing,
    bool clearError = false,
  }) {
    return LibraryFormState(
      status: status ?? this.status,
      library: library ?? this.library,
      currentSection: currentSection ?? this.currentSection,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      validationErrors: validationErrors ?? this.validationErrors,
      isEditing: isEditing ?? this.isEditing,
    );
  }

  @override
  List<Object?> get props => [
    status,
    library,
    currentSection,
    errorMessage,
    validationErrors,
    isEditing,
  ];
}

/// Status for library form.
enum LibraryFormStatus { initial, loading, loaded, saving, success, error }
