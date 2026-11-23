import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/version_check_cubit.dart';
import 'package:pg_manager/presentation/core/app_ui_constants.dart';

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
          child: Dialog(
            backgroundColor: AppUIConstants.surface,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
              side: const BorderSide(color: AppUIConstants.border),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppUIConstants.surfaceMuted,
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      size: 34,
                      color: AppUIConstants.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Update required',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppUIConstants.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: AppUIConstants.textSecondary,
                    ),
                  ),
                  if (appVersion != null) ...[
                    const SizedBox(height: 18),
                    _VersionInfo(
                      currentVersion: appVersion.currentVersion,
                      requiredVersion: appVersion.minimumRequiredVersion,
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.read<VersionCheckCubit>().openUpdateUrl(),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text(
                        'Update now',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      style: AppUIConstants.accentButtonStyle.copyWith(
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    Widget cell(String label, String value, Color color) => Expanded(
      child: Column(
        children: [
          Text(label, style: AppUIConstants.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      ),
      child: Row(
        children: [
          cell('Installed', currentVersion, AppUIConstants.textSecondary),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: AppUIConstants.textTertiary,
          ),
          cell('Required', requiredVersion, AppUIConstants.primaryLight),
        ],
      ),
    );
  }
}
