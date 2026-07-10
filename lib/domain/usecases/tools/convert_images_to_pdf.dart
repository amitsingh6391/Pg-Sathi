import 'package:dartz/dartz.dart';

import '../../core/failure.dart';
import '../../core/usecase.dart';
import '../../entities/tool_params.dart';
import '../../entities/tool_result.dart';
import '../../repositories/tools_repository.dart';

/// Use case for converting images to PDF.
class ConvertImagesToPdf implements UseCase<ImagesToPdfResult, ImagesToPdfParams> {
  const ConvertImagesToPdf({required this.repository});

  final ToolsRepository repository;

  @override
  Future<Either<Failure, ImagesToPdfResult>> call(
    ImagesToPdfParams params,
  ) async {
    return await repository.convertImagesToPdf(params);
  }
}
