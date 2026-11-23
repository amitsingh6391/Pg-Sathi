import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/bulk_import_cubit.dart';
import '../cubit/bulk_import_state.dart';
import '../widgets/bulk_import/completion_section.dart';
import '../widgets/bulk_import/error_section.dart';
import '../widgets/bulk_import/file_picker_section.dart';
import '../widgets/bulk_import/import_stepper.dart';
import '../widgets/bulk_import/importing_section.dart';
import '../widgets/bulk_import/loading_section.dart';
import '../widgets/bulk_import/preview_section.dart';

/// Screen for bulk importing residents and stays from Excel.
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
          title: const Text(
            'Import Residents',
            style: AppUIConstants.headingMd,
          ),
          backgroundColor: AppUIConstants.surface,
          foregroundColor: AppUIConstants.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
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
              backgroundColor: AppUIConstants.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final step = switch (state.status) {
          BulkImportStatus.initial ||
          BulkImportStatus.parsing ||
          BulkImportStatus.error => 0,
          BulkImportStatus.preview => 1,
          BulkImportStatus.importing => 2,
          BulkImportStatus.complete => 3,
        };
        final body = switch (state.status) {
          BulkImportStatus.initial => const FilePickerSection(),
          BulkImportStatus.parsing => const LoadingSection(
            message: 'Reading your Excel file...',
          ),
          BulkImportStatus.preview => PreviewSection(state: state),
          BulkImportStatus.importing => ImportingSection(state: state),
          BulkImportStatus.complete => CompletionSection(state: state),
          BulkImportStatus.error => ErrorSection(state: state),
        };
        return Column(
          children: [
            ImportStepper(currentStep: step),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(key: ValueKey(state.status), child: body),
              ),
            ),
          ],
        );
      },
    );
  }
}
