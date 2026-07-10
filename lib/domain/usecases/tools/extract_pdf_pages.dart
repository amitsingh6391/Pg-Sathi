import 'package:dartz/dartz.dart';

import '../../core/failure.dart';
import '../../core/usecase.dart';
import '../../entities/tool_params.dart';
import '../../entities/tool_result.dart';
import '../../repositories/tools_repository.dart';

/// Use case for extracting pages from PDF.
class ExtractPdfPages implements UseCase<PdfPageExtractionResult, PdfPageExtractionParams> {
  const ExtractPdfPages({required this.repository});

  final ToolsRepository repository;

  @override
  Future<Either<Failure, PdfPageExtractionResult>> call(
    PdfPageExtractionParams params,
  ) async {
    return await repository.extractPdfPages(params);
  }
}
