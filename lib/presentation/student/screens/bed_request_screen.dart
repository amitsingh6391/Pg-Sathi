import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/entities/user.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/bed_request_cubit.dart';
import '../cubit/bed_request_state.dart';

/// Resident flow: choose a room type and bed, pick a stay, send the request to
/// the owner. Pops with `true` once the request has been sent.
class BedRequestScreen extends StatelessWidget {
  const BedRequestScreen({
    super.key,
    required this.library,
    required this.user,
    this.prefetched,
  });

  final Library library;
  final User user;

  /// Data the opening screen already loaded; skips the initial fetch.
  final BedRequestPrefetch? prefetched;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<BedRequestCubit>()
            ..load(library: library, user: user, prefetched: prefetched),
      child: _BedRequestView(library: library, user: user),
    );
  }
}

class _BedRequestView extends StatefulWidget {
  const _BedRequestView({required this.library, required this.user});

  final Library library;
  final User user;

  @override
  State<_BedRequestView> createState() => _BedRequestViewState();
}

class _BedRequestViewState extends State<_BedRequestView> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.user.name);
  final _utrController = TextEditingController();

  /// UPI is preselected when the owner accepts it (same as Library Manager).
  late PaymentMode _payMethod = widget.library.acceptsUpi
      ? PaymentMode.upi
      : PaymentMode.cash;

  @override
  void dispose() {
    _nameController.dispose();
    _utrController.dispose();
    super.dispose();
  }

  void _copyUpiId() {
    final upiId = widget.library.ownerUpiId?.trim() ?? '';
    if (upiId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: upiId));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('UPI ID copied'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  void _showQrFullScreen(String qrUrl) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              qrUrl,
              fit: BoxFit.contain,
              // Show via an <img> tag on web if the CORS fetch is blocked.
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, DateTime current) async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: first,
      lastDate: first.add(const Duration(days: 90)),
    );
    if (picked != null && context.mounted) {
      context.read<BedRequestCubit>().setStartDate(picked);
    }
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<BedRequestCubit>().submit(
      name: _nameController.text.trim(),
      phone: widget.user.phone,
      paymentMethod: _payMethod,
      upiTransactionId: _utrController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BedRequestCubit, BedRequestState>(
      listener: (context, state) {
        if (state.errorMessage != null &&
            state.status == BedRequestStatus.ready) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppUIConstants.error,
              ),
            );
        }
      },
      builder: (context, state) {
        if (state.status == BedRequestStatus.submitted) {
          return _SuccessView(pgName: widget.library.name);
        }
        return Scaffold(
          backgroundColor: AppUIConstants.background,
          appBar: AppBar(title: const Text('Request a bed')),
          body: _body(context, state),
          bottomNavigationBar:
              state.status == BedRequestStatus.loading ||
                  state.existingRequest != null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppUIConstants.spacingLg,
                      AppUIConstants.spacingSm,
                      AppUIConstants.spacingLg,
                      AppUIConstants.spacingLg,
                    ),
                    child: FilledButton(
                      onPressed:
                          state.canSubmit &&
                              state.status != BedRequestStatus.submitting
                          ? () => _submit(context)
                          : null,
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
                      child: state.status == BedRequestStatus.submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send request'),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _body(BuildContext context, BedRequestState state) {
    if (state.status == BedRequestStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppUIConstants.primaryLight),
      );
    }
    if (state.status == BedRequestStatus.error && state.slots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppUIConstants.spacing2Xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: AppUIConstants.bodyMd,
              ),
              const SizedBox(height: AppUIConstants.spacingLg),
              OutlinedButton(
                onPressed: () => context.read<BedRequestCubit>().load(
                  library: widget.library,
                  user: widget.user,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.existingRequest != null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppUIConstants.spacing2Xl),
          child: Text(
            'You already have a request waiting for approval at this PG.',
            textAlign: TextAlign.center,
            style: AppUIConstants.bodyMd,
          ),
        ),
      );
    }

    final cubit = context.read<BedRequestCubit>();
    final slot = state.selectedSlot;
    final freeBeds = slot == null ? <String>[] : state.freeBedsFor(slot);
    final start = state.startDate ?? DateTime.now();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppUIConstants.spacingLg,
          0,
          AppUIConstants.spacingLg,
          AppUIConstants.spacing3Xl,
        ),
        children: [
          const PremiumSectionHeader('Your details'),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (v) =>
                (v == null || v.trim().length < 2) ? 'Enter your name' : null,
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          TextFormField(
            initialValue: widget.user.phone,
            enabled: false,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const PremiumSectionHeader('Room type'),
          if (state.slots.isEmpty)
            const Text(
              'This PG has no room types available yet.',
              style: AppUIConstants.bodyMd,
            ),
          for (final s in state.slots)
            Padding(
              padding: const EdgeInsets.only(bottom: AppUIConstants.spacingSm),
              child: _SelectableCard(
                selected: s.id == state.selectedSlotId,
                enabled: state.freeBedsFor(s).isNotEmpty,
                onTap: () => cubit.selectSlot(s.id),
                title: s.name,
                subtitle: '₹${s.price.toStringAsFixed(0)} / month',
                trailing: state.freeBedsFor(s).isEmpty
                    ? 'Full'
                    : '${state.freeBedsFor(s).length} free',
              ),
            ),
          if (slot != null) ...[
            const PremiumSectionHeader('Choose a bed'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final bed in freeBeds)
                  ChoiceChip(
                    label: Text(bed),
                    selected: bed == state.selectedBed,
                    onSelected: (_) => cubit.selectBed(bed),
                    selectedColor: AppUIConstants.primarySoft,
                    backgroundColor: AppUIConstants.surfaceMuted,
                    side: BorderSide(
                      color: bed == state.selectedBed
                          ? AppUIConstants.primaryLight
                          : AppUIConstants.border,
                    ),
                    labelStyle: TextStyle(
                      color: bed == state.selectedBed
                          ? AppUIConstants.primaryLight
                          : AppUIConstants.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    showCheckmark: false,
                  ),
              ],
            ),
          ],
          const PremiumSectionHeader('Stay'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in BedRequestCubit.monthOptions)
                ChoiceChip(
                  label: Text(
                    m == 12 ? '1 year' : '$m ${m == 1 ? 'month' : 'months'}',
                  ),
                  selected: state.months == m,
                  onSelected: (_) => cubit.setMonths(m),
                  selectedColor: AppUIConstants.primarySoft,
                  backgroundColor: AppUIConstants.surfaceMuted,
                  side: BorderSide(
                    color: state.months == m
                        ? AppUIConstants.primaryLight
                        : AppUIConstants.border,
                  ),
                  labelStyle: TextStyle(
                    color: state.months == m
                        ? AppUIConstants.primaryLight
                        : AppUIConstants.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          PremiumCard(
            onTap: () => _pickDate(context, start),
            child: Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  color: AppUIConstants.textSecondary,
                ),
                const SizedBox(width: AppUIConstants.spacingMd),
                const Expanded(
                  child: Text('Move-in date', style: AppUIConstants.bodyMd),
                ),
                Text(
                  DateFormat('d MMM yyyy').format(start),
                  style: AppUIConstants.bodyLg,
                ),
              ],
            ),
          ),
          if (state.estimatedRent != null) ...[
            const SizedBox(height: AppUIConstants.spacingLg),
            PremiumCard(
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Estimated rent', style: AppUIConstants.bodyMd),
                  ),
                  Text(
                    '₹${state.estimatedRent!.toStringAsFixed(0)}',
                    style: AppUIConstants.headingMd,
                  ),
                ],
              ),
            ),
          ],
          ..._paymentSection(state),
        ],
      ),
    );
  }

  /// How the resident will pay: cash at the PG, or UPI straight to the owner
  /// (UPI ID with copy, QR to scan, optional transaction ID) - mirrors
  /// Library Manager's seat request flow.
  List<Widget> _paymentSection(BedRequestState state) {
    final lib = widget.library;
    final upiId = lib.ownerUpiId?.trim() ?? '';
    final qrUrl = lib.ownerUpiQrUrl;
    final rent = state.estimatedRent;
    final isUpi = _payMethod == PaymentMode.upi;

    return [
      const PremiumSectionHeader('Payment'),
      if (lib.acceptsUpi)
        Row(
          children: [
            Expanded(
              child: _SelectableCard(
                selected: isUpi,
                enabled: true,
                onTap: () => setState(() => _payMethod = PaymentMode.upi),
                title: 'UPI',
                subtitle: 'Pay the owner now',
                trailing: '',
              ),
            ),
            const SizedBox(width: AppUIConstants.spacingSm),
            Expanded(
              child: _SelectableCard(
                selected: !isUpi,
                enabled: true,
                onTap: () => setState(() => _payMethod = PaymentMode.cash),
                title: 'Cash',
                subtitle: 'Pay at the PG',
                trailing: '',
              ),
            ),
          ],
        ),
      const SizedBox(height: AppUIConstants.spacingMd),
      if (isUpi && lib.acceptsUpi)
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                rent == null
                    ? 'Pay the owner by UPI'
                    : 'Pay ₹${rent.toStringAsFixed(0)} to the owner by UPI',
                style: AppUIConstants.headingSm,
              ),
              if (upiId.isNotEmpty) ...[
                const SizedBox(height: AppUIConstants.spacingMd),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  decoration: BoxDecoration(
                    color: AppUIConstants.background,
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusSm,
                    ),
                    border: Border.all(color: AppUIConstants.border),
                  ),
                  child: Row(
                    children: [
                      const Text('UPI ID', style: AppUIConstants.bodySm),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          upiId,
                          style: AppUIConstants.bodyLg.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _copyUpiId,
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy'),
                      ),
                    ],
                  ),
                ),
              ],
              if (lib.hasUpiQr && qrUrl != null) ...[
                const SizedBox(height: AppUIConstants.spacingLg),
                Center(
                  child: GestureDetector(
                    onTap: () => _showQrFullScreen(qrUrl),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusMd,
                        ),
                        border: Border.all(color: AppUIConstants.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusSm,
                        ),
                        child: Image.network(
                          qrUrl,
                          width: 180,
                          height: 180,
                          fit: BoxFit.contain,
                          // Show via an <img> tag on web if the CORS fetch
                          // is blocked.
                          webHtmlElementStrategy:
                              WebHtmlElementStrategy.fallback,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : const SizedBox(
                                  width: 180,
                                  height: 180,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 180,
                            height: 180,
                            child: Center(
                              child: Text(
                                'QR code unavailable',
                                style: AppUIConstants.bodySm,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Tap to enlarge · Scan with any UPI app',
                    style: AppUIConstants.caption,
                  ),
                ),
              ],
              const SizedBox(height: AppUIConstants.spacingLg),
              TextFormField(
                controller: _utrController,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'UPI transaction ID (optional)',
                  hintText: '12-digit UTR from your UPI app',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: AppUIConstants.spacingSm),
      Text(
        isUpi && lib.acceptsUpi
            ? 'The owner checks your payment and approves your request.'
            : 'The owner reviews your request. Pay rent and deposit at the PG.',
        style: AppUIConstants.caption,
      ),
    ];
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: selected ? AppUIConstants.primarySoft : AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              border: Border.all(
                color: selected
                    ? AppUIConstants.primaryLight
                    : AppUIConstants.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppUIConstants.bodyLg),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppUIConstants.bodySm),
                    ],
                  ),
                ),
                Text(trailing, style: AppUIConstants.bodySm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.pgName});

  final String pgName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacing2Xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 64,
                  color: AppUIConstants.success,
                ),
                const SizedBox(height: AppUIConstants.spacingLg),
                const Text('Request sent', style: AppUIConstants.headingLg),
                const SizedBox(height: AppUIConstants.spacingSm),
                Text(
                  'The owner of $pgName will review your request. You will '
                  'get a notification once it is approved.',
                  textAlign: TextAlign.center,
                  style: AppUIConstants.bodyMd,
                ),
                const SizedBox(height: AppUIConstants.spacing2Xl),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppUIConstants.primaryLight,
                    foregroundColor: AppUIConstants.background,
                    minimumSize: const Size(200, 48),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
