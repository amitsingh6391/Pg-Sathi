import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/bulk_import_cubit.dart';
import '../cubit/bulk_import_state.dart';
import '../widgets/bulk_import/completion_section.dart';
import '../widgets/bulk_import/error_section.dart';
import '../widgets/bulk_import/file_picker_section.dart';
import '../widgets/bulk_import/importing_section.dart';
import '../widgets/bulk_import/loading_section.dart';
import '../widgets/bulk_import/preview_section.dart';

/// Screen for bulk importing students and memberships from Excel.
class BulkImportScreen extends StatelessWidget {
  const BulkImportScreen({
    super.key,
    required this.library,
    required this.ownerId,
  });

  final Library library;
  final String ownerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<BulkImportCubit>()
            ..initialize(libraryId: library.id, ownerId: ownerId),
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        appBar: AppBar(
          title: const Text('Bulk Import'),
          backgroundColor: AppUIConstants.primary,
          foregroundColor: Colors.white,
        ),
        body: const _BulkImportBody(),
      ),
    );
  }
}

class _BulkImportBody extends StatelessWidget {
  const _BulkImportBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BulkImportCubit, BulkImportState>(
      listener: (context, state) {
        // Show error snackbar
        if (state.status == BulkImportStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        return switch (state.status) {
          BulkImportStatus.initial => const FilePickerSection(),
          BulkImportStatus.parsing => const LoadingSection(
            message: 'Parsing Excel file...',
          ),
          BulkImportStatus.preview => PreviewSection(state: state),
          BulkImportStatus.importing => ImportingSection(state: state),
          BulkImportStatus.complete => CompletionSection(state: state),
          BulkImportStatus.error => ErrorSection(state: state),
        };
      },
    );
  }
}
