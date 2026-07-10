import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/version_check_cubit.dart';
import 'force_update_dialog.dart';

/// Wrapper widget that listens to version check state and shows dialog
/// when update is required. Should be used inside route screens where
/// Navigator context is available.
class VersionCheckWrapper extends StatefulWidget {
  const VersionCheckWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<VersionCheckWrapper> createState() => _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends State<VersionCheckWrapper> {
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<VersionCheckCubit, VersionCheckState>(
      listener: (context, state) {
        if (state.isUpdateRequired && !_dialogShown) {
          _dialogShown = true;
          // Show dialog after current frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && context.mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const ForceUpdateDialog(),
              );
            }
          });
        }
      },
      child: widget.child,
    );
  }
}
