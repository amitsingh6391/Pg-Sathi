import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../domain/entities/manager_access.dart';
import '../../../core/app_ui_constants.dart';
import '../../../core/widgets/premium_kit.dart';
import '../../cubit/managers_cubit.dart';
import '../../cubit/managers_state.dart';

/// Owner settings group for giving managers access to the PG.
class OwnerManagersSection extends StatelessWidget {
  const OwnerManagersSection({super.key, required this.ownerId});

  final String ownerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ManagersCubit>()..load(ownerId),
      child: _ManagersCard(ownerId: ownerId),
    );
  }
}

class _ManagersCard extends StatefulWidget {
  const _ManagersCard({required this.ownerId});

  final String ownerId;

  @override
  State<_ManagersCard> createState() => _ManagersCardState();
}

class _ManagersCardState extends State<_ManagersCard> {
  final _mobileController = TextEditingController();
  String? _libraryId;

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  void _submit(ManagersCubit cubit) {
    cubit.invite(
      ownerId: widget.ownerId,
      libraryId: _libraryId,
      mobile: _mobileController.text,
    );
    FocusScope.of(context).unfocus();
    _mobileController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ManagersCubit, ManagersState>(
      listenWhen: (prev, curr) =>
          (curr.status == ManagersStatus.error && curr.errorMessage != null) ||
          prev.libraries != curr.libraries,
      listener: (context, state) {
        if (state.status == ManagersStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppUIConstants.error,
            ),
          );
        }
        if (_libraryId == null && state.libraries.isNotEmpty) {
          setState(() => _libraryId = state.libraries.first.id);
        }
      },
      builder: (context, state) {
        final cubit = context.read<ManagersCubit>();
        final saving = state.status == ManagersStatus.saving;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PremiumSectionHeader('PG Managers'),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Give a manager access to one or more of your PGs. Add the '
                    'same number again to give another branch. They sign in '
                    'with their own mobile number and see only the branches '
                    'you add.',
                    style: AppUIConstants.bodySm.copyWith(
                      color: AppUIConstants.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppUIConstants.spacingMd),
                  if (state.status == ManagersStatus.loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppUIConstants.spacingSm),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else if (state.managers.isEmpty)
                    Text(
                      'No managers added yet.',
                      style: AppUIConstants.bodySm.copyWith(
                        color: AppUIConstants.textSecondary,
                      ),
                    )
                  else
                    for (final access in state.managers)
                      _ManagerTile(
                        access: access,
                        libraryName: state.libraries.length > 1
                            ? _libraryName(state, access.libraryId)
                            : null,
                        onRevoke: saving
                            ? null
                            : () => _confirmRevoke(context, cubit, access),
                      ),
                  const Divider(height: 24, color: AppUIConstants.divider),
                  TextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    maxLength: 10,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onChanged: (value) {
                      if (value.length == 10) FocusScope.of(context).unfocus();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Manager mobile number',
                      prefixText: '+91 ',
                      counterText: '',
                    ),
                  ),
                  if (state.libraries.length > 1) ...[
                    const SizedBox(height: AppUIConstants.spacingSm),
                    DropdownButtonFormField<String>(
                      initialValue: _libraryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Branch'),
                      items: [
                        for (final library in state.libraries)
                          DropdownMenuItem(
                            value: library.id,
                            child: Text(
                              library.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _libraryId = value),
                    ),
                  ],
                  const SizedBox(height: AppUIConstants.spacingMd),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving || _libraryId == null
                          ? null
                          : () => _submit(cubit),
                      child: Text(saving ? 'Saving...' : 'Give access'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    ManagersCubit cubit,
    ManagerAccess access,
  ) async {
    final target = cubit.state.libraries.length > 1
        ? _libraryName(cubit.state, access.libraryId)
        : 'your PG';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove manager?'),
        content: Text(
          '${access.name ?? access.phone} will lose access to $target.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppUIConstants.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      cubit.revoke(ownerId: widget.ownerId, access: access);
    }
  }

  String _libraryName(ManagersState state, String libraryId) {
    for (final library in state.libraries) {
      if (library.id == libraryId) return library.name;
    }
    return 'Unknown PG';
  }
}

class _ManagerTile extends StatelessWidget {
  const _ManagerTile({
    required this.access,
    required this.onRevoke,
    this.libraryName,
  });

  final ManagerAccess access;

  /// Branch this access is for; shown only when the owner has several PGs.
  final String? libraryName;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.manage_accounts_rounded,
        color: AppUIConstants.primaryLight,
      ),
      title: Text(
        access.name ?? access.phone,
        style: AppUIConstants.bodyMd,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (libraryName != null) libraryName!,
          access.isPending ? 'Pending sign-in' : access.phone,
        ].join(' · '),
        style: AppUIConstants.bodySm.copyWith(
          color: AppUIConstants.textSecondary,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.person_remove_outlined),
        color: AppUIConstants.error,
        tooltip: 'Remove access',
        onPressed: onRevoke,
      ),
    );
  }
}
