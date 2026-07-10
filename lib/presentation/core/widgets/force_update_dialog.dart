import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/version_check_cubit.dart';

/// Dialog shown when force update is required.
/// Prevents user from using the app until they update.
class ForceUpdateDialog extends StatelessWidget {
  const ForceUpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VersionCheckCubit, VersionCheckState>(
      builder: (context, state) {
        final appVersion = state.appVersion;
        final message =
            appVersion?.updateMessage ??
            'A new version of the app is available. Please update to continue using the app.';

        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.system_update_rounded, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Update Required',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: const TextStyle(fontSize: 15)),
                  if (appVersion != null) ...[
                    const SizedBox(height: 16),
                    _VersionInfo(
                      currentVersion: appVersion.currentVersion,
                      requiredVersion: appVersion.minimumRequiredVersion,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<VersionCheckCubit>().openUpdateUrl(),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Update Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VersionInfo extends StatelessWidget {
  const _VersionInfo({
    required this.currentVersion,
    required this.requiredVersion,
  });

  final String currentVersion;
  final String requiredVersion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Version: $currentVersion',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            'Required Version: $requiredVersion',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
