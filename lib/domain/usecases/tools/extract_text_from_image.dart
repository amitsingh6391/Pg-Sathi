import 'package:dartz/dartz.dart';

import '../../core/failure.dart';
import '../../core/usecase.dart';
import '../../entities/tool_params.dart';
import '../../entities/tool_result.dart';
import '../../repositories/tools_repository.dart';

/// Use case for extracting text from image using OCR.
class ExtractTextFromImage implements UseCase<OcrResult, OcrParams> {
  const ExtractTextFromImage({required this.repository});

  final ToolsRepository repository;

  @override
  Future<Either<Failure, OcrResult>> call(OcrParams params) async {
    return await repository.extractTextFromImage(params);
  }
}
