import 'package:equatable/equatable.dart';

import '../models/import_row_data.dart';

/// State for bulk import feature.
class BulkImportState extends Equatable {
  const BulkImportState({
    this.status = BulkImportStatus.initial,
    this.fileName,
    this.parsedRows = const [],
    this.validRows = const [],
    this.invalidRows = const [],
    this.importProgress = 0,
    this.currentRowIndex = 0,
    this.importSummary,
    this.errorMessage,
  });

  /// Current status of the import process.
  final BulkImportStatus status;

  /// Name of the selected file.
  final String? fileName;

  /// All parsed rows from Excel.
  final List<ImportRowData> parsedRows;

  /// Rows that passed validation.
  final List<ImportRowData> validRows;

  /// Rows that failed validation.
  final List<ImportRowData> invalidRows;

  /// Import progress (0.0 to 1.0).
  final double importProgress;

  /// Current row being processed.
  final int currentRowIndex;

  /// Summary of import results.
  final ImportSummary? importSummary;

  /// Error message if something went wrong.
  final String? errorMessage;

  /// Total number of rows parsed.
  int get totalRows => parsedRows.length;

  /// Number of valid rows ready for import.
  int get validRowCount => validRows.length;

  /// Number of invalid rows.
  int get invalidRowCount => invalidRows.length;

  /// Whether file is selected and parsed.
  bool get hasParsedData => parsedRows.isNotEmpty;

  /// Whether there are valid rows to import.
  bool get canImport => validRows.isNotEmpty;

  /// Whether import is in progress.
  bool get isImporting => status == BulkImportStatus.importing;

  /// Whether import is complete.
  bool get isComplete => status == BulkImportStatus.complete;

  BulkImportState copyWith({
    BulkImportStatus? status,
    String? fileName,
    List<ImportRowData>? parsedRows,
    List<ImportRowData>? validRows,
    List<ImportRowData>? invalidRows,
    double? importProgress,
    int? currentRowIndex,
    ImportSummary? importSummary,
    String? errorMessage,
    bool clearFileName = false,
    bool clearError = false,
    bool clearSummary = false,
  }) {
    return BulkImportState(
      status: status ?? this.status,
      fileName: clearFileName ? null : (fileName ?? this.fileName),
      parsedRows: parsedRows ?? this.parsedRows,
      validRows: validRows ?? this.validRows,
      invalidRows: invalidRows ?? this.invalidRows,
      importProgress: importProgress ?? this.importProgress,
      currentRowIndex: currentRowIndex ?? this.currentRowIndex,
      importSummary: clearSummary ? null : (importSummary ?? this.importSummary),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        fileName,
        parsedRows,
        validRows,
        invalidRows,
        importProgress,
        currentRowIndex,
        importSummary,
        errorMessage,
      ];
}

/// Status of the bulk import process.
enum BulkImportStatus {
  /// Initial state, no file selected.
  initial,

  /// Parsing Excel file.
  parsing,

  /// File parsed, showing preview.
  preview,

  /// Import in progress.
  importing,

  /// Import complete.
  complete,

  /// Error occurred.
  error,
}
