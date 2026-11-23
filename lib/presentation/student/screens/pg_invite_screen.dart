import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/post_login_redirect.dart';
import '../../../core/utils/pg_invite_link.dart';
import '../../../domain/entities/library.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/bed_request_cubit.dart';
import '../cubit/pg_invite_cubit.dart';
import '../cubit/pg_invite_state.dart';
import 'bed_request_screen.dart';

/// Landing screen for a PG QR link (`/pg/:id`).
///
/// Logged-in residents see the PG's details and can request a bed; everyone
/// else is sent to login and returned here afterwards.
class PgInviteScreen extends StatelessWidget {
  const PgInviteScreen({super.key, required this.pgId});

  final String pgId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PgInviteCubit>()..load(pgId),
      child: BlocConsumer<PgInviteCubit, PgInviteState>(
        listener: (context, state) {
          if (state.status != PgInviteStatus.needsLogin) return;
          PostLoginRedirect.set(PgInviteLink.route(pgId));
          context.go(AppRoutes.auth);
        },
        builder: (context, state) {
          final library = state.library;
          if (state.status == PgInviteStatus.ready && library != null) {
            return _InviteView(state: state, library: library, pgId: pgId);
          }
          if (state.status == PgInviteStatus.notFound ||
              state.status == PgInviteStatus.error) {
            return _InviteMessage(
              notFound: state.status == PgInviteStatus.notFound,
              onRetry: () => context.read<PgInviteCubit>().load(pgId),
            );
          }
          return const Scaffold(
            backgroundColor: AppUIConstants.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AppUIConstants.primaryLight,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InviteView extends StatelessWidget {
  const _InviteView({
    required this.state,
    required this.library,
    required this.pgId,
  });

  final PgInviteState state;
  final Library library;
  final String pgId;

  Future<void> _openRequest(BuildContext context) async {
    final user = state.user;
    if (user == null) return;
    final cubit = context.read<PgInviteCubit>();
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BedRequestScreen(
          library: library,
          user: user,
          prefetched: state.occupied == null
              ? null
              : BedRequestPrefetch(
                  slots: state.slots,
                  occupied: state.occupied!,
                  existingRequest: state.pendingRequest,
                ),
        ),
      ),
    );
    if (sent == true) cubit.load(pgId, silent: true);
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('${AppRoutes.studentHome}?userId=${state.user?.id ?? ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = library.photos.isNotEmpty ? library.photos.first : null;
    final place = library.area ?? library.fullAddress ?? library.location;
    final pending = state.pendingRequest;
    final canRequest =
        !state.isOwner && pending == null && state.totalFreeBeds > 0;

    String ctaLabel = 'Request a bed';
    if (state.isOwner) {
      ctaLabel = 'Owners cannot request a bed';
    } else if (pending != null) {
      ctaLabel = 'Request pending approval';
    } else if (state.slots.isEmpty || state.totalFreeBeds == 0) {
      ctaLabel = 'No beds available right now';
    }

    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _leave(context),
        ),
        title: const Text('PG invite'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppUIConstants.spacingLg,
          AppUIConstants.spacingSm,
          AppUIConstants.spacingLg,
          AppUIConstants.spacing3Xl,
        ),
        children: [
          if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: Image.network(
                  photo,
                  fit: BoxFit.cover,
                  // Show via an <img> tag on web if the CORS fetch is blocked.
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (_, _, _) =>
                      Container(color: AppUIConstants.surfaceMuted),
                ),
              ),
            ),
          const SizedBox(height: AppUIConstants.spacingLg),
          Text(library.name, style: AppUIConstants.headingLg),
          if (place.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: AppUIConstants.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(child: Text(place, style: AppUIConstants.bodyMd)),
              ],
            ),
          ],
          if (library.enabledFacilities.isNotEmpty) ...[
            const SizedBox(height: AppUIConstants.spacingMd),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in library.enabledFacilities) _Chip(f.displayName),
              ],
            ),
          ],
          if (pending != null) ...[
            const SizedBox(height: AppUIConstants.spacingLg),
            PremiumCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    color: AppUIConstants.warning,
                  ),
                  const SizedBox(width: AppUIConstants.spacingMd),
                  const Expanded(
                    child: Text(
                      'Your request is with the owner. You will be notified '
                      'once it is approved.',
                      style: AppUIConstants.bodyMd,
                    ),
                  ),
                  const PremiumStatusPill(
                    'Pending',
                    color: AppUIConstants.warning,
                  ),
                ],
              ),
            ),
          ],
          const PremiumSectionHeader('Room types'),
          if (state.slots.isEmpty)
            const PremiumCard(
              child: Text(
                'The owner has not published room types yet.',
                style: AppUIConstants.bodyMd,
              ),
            )
          else
            for (final slot in state.slots)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AppUIConstants.spacingSm,
                ),
                child: PremiumCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(slot.name, style: AppUIConstants.bodyLg),
                            const SizedBox(height: 2),
                            Text(
                              '₹${slot.price.toStringAsFixed(0)} / month',
                              style: AppUIConstants.bodyMd,
                            ),
                          ],
                        ),
                      ),
                      if ((state.freeBedsBySlot[slot.id] ?? 0) > 0)
                        PremiumStatusPill(
                          '${state.freeBedsBySlot[slot.id]} free',
                          color: AppUIConstants.success,
                        )
                      else
                        const PremiumStatusPill(
                          'Full',
                          color: AppUIConstants.textTertiary,
                        ),
                    ],
                  ),
                ),
              ),
          if (library.ownerPhone != null && library.ownerPhone!.isNotEmpty) ...[
            const PremiumSectionHeader('Contact'),
            PremiumCard(
              onTap: () => launchUrl(Uri.parse('tel:${library.ownerPhone}')),
              child: Row(
                children: [
                  const Icon(
                    Icons.call_outlined,
                    color: AppUIConstants.textSecondary,
                  ),
                  const SizedBox(width: AppUIConstants.spacingMd),
                  Expanded(
                    child: Text(
                      library.ownerPhone!,
                      style: AppUIConstants.bodyLg,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppUIConstants.textTertiary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppUIConstants.spacingLg,
            AppUIConstants.spacingSm,
            AppUIConstants.spacingLg,
            AppUIConstants.spacingLg,
          ),
          child: FilledButton(
            onPressed: canRequest ? () => _openRequest(context) : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppUIConstants.primaryLight,
              foregroundColor: AppUIConstants.background,
              disabledBackgroundColor: AppUIConstants.surfaceMuted,
              disabledForegroundColor: AppUIConstants.textTertiary,
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(ctaLabel),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppUIConstants.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InviteMessage extends StatelessWidget {
  const _InviteMessage({required this.notFound, required this.onRetry});

  final bool notFound;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(title: const Text('PG')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppUIConstants.spacing2Xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.apartment_rounded,
                size: 52,
                color: AppUIConstants.textTertiary,
              ),
              const SizedBox(height: AppUIConstants.spacingLg),
              Text(
                notFound
                    ? 'This PG could not be found.'
                    : 'Could not load this PG.',
                textAlign: TextAlign.center,
                style: AppUIConstants.headingSm,
              ),
              const SizedBox(height: AppUIConstants.spacingLg),
              if (notFound)
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.auth),
                  child: const Text('Go to Home'),
                )
              else
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
