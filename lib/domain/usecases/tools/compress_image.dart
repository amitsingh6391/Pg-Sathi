import 'package:dartz/dartz.dart';

import '../../core/failure.dart';
import '../../core/usecase.dart';
import '../../entities/tool_params.dart';
import '../../entities/tool_result.dart';
import '../../repositories/tools_repository.dart';

/// Use case for compressing images to target size.
class CompressImage implements UseCase<ImageCompressionResult, ImageCompressionParams> {
  const CompressImage({required this.repository});

  final ToolsRepository repository;

  @override
  Future<Either<Failure, ImageCompressionResult>> call(
    ImageCompressionParams params,
  ) async {
    return await repository.compressImage(params);
  }
}
