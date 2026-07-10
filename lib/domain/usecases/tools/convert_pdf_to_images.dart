import 'package:dartz/dartz.dart';

import '../../core/failure.dart';
import '../../core/usecase.dart';
import '../../entities/tool_params.dart';
import '../../entities/tool_result.dart';
import '../../repositories/tools_repository.dart';

/// Use case for converting PDF to images.
class ConvertPdfToImages implements UseCase<PdfToImagesResult, PdfToImagesParams> {
  const ConvertPdfToImages({required this.repository});

  final ToolsRepository repository;

  @override
  Future<Either<Failure, PdfToImagesResult>> call(
    PdfToImagesParams params,
  ) async {
    return await repository.convertPdfToImages(params);
  }
}
