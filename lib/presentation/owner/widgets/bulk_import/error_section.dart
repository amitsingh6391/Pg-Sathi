import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app_ui_constants.dart';
import '../../cubit/bulk_import_cubit.dart';
import '../../cubit/bulk_import_state.dart';

/// Error section widget.
class ErrorSection extends StatelessWidget {
  const ErrorSection({required this.state, super.key});

  final BulkImportState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppUIConstants.error.withValues(alpha: 0.14),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppUIConstants.error,
              ),
            ),
            const SizedBox(height: 24),
            const Text('Import Error', style: AppUIConstants.headingLg),
            const SizedBox(height: 12),
            Text(
              state.errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: AppUIConstants.bodyMd,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.read<BulkImportCubit>().reset(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: AppUIConstants.primaryButtonStyle,
            ),
          ],
        ),
      ),
    );
  }
}
