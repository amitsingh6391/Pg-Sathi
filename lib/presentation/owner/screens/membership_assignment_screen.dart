import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pg_manager/presentation/core/app_ui_constants.dart';
import 'package:pg_manager/presentation/core/widgets/premium_kit.dart';

import '../../../core/di/injection_container.dart' as di;
import '../../../core/di/injection_container.dart';
import '../../../data/services/review_prompt_service.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/membership.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/entities/payment_breakdown.dart';
import '../../../domain/entities/subscription_plan.dart';
import '../../../domain/failures/subscription_failures.dart';
import '../../../domain/repositories/user_repository.dart';
import '../cubit/bulk_import_cubit.dart';
import '../cubit/membership_assignment_cubit.dart';
import '../cubit/membership_assignment_state.dart';
import '../screens/bulk_import_screen.dart';
import '../screens/owner_in_app_purchase_screen.dart';
import '../widgets/membership_assignment/membership_assignment_widgets.dart';

/// Screen for assigning tenant stays.
/// Stepped flow: Resident details -> Choose bed -> Rent & plan.
class MembershipAssignmentScreen extends StatefulWidget {
  const MembershipAssignmentScreen({
    super.key,
    required this.library,
    this.prefilledSeatId,
    this.prefilledSlotId,
    this.prefilledMembership,
  });

  final Library library;
  final String? prefilledSeatId;
  final String? prefilledSlotId;

  /// Prefilled membership data (for reassignment from expired seats)
  final Membership? prefilledMembership;

  @override
  State<MembershipAssignmentScreen> createState() =>
      _MembershipAssignmentScreenState();
}

class _MembershipAssignmentScreenState extends State<MembershipAssignmentScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _amountRemainingController = TextEditingController();
  final _paymentNotesController = TextEditingController();
  final _discountController = TextEditingController();
  final _customDurationDaysController = TextEditingController();
  final _customDurationMonthsController = TextEditingController();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  DateTime _startDate = DateTime.now();
  DateTime _paymentReceivedDate = DateTime.now();
  MembershipPlan _selectedPlan = MembershipPlan.monthly;
  PaymentMode? _paymentMethod = PaymentMode.cash;
  bool _markCashReceived = true;
  bool _isPartialPayment = false;
  bool _useCustomDuration = false;
  int? _customDurationDays;
  int? _customDurationMonths;
  String?
  _excludeMembershipId; // For excluding expired membership when reassigning

  late AnimationController _animationController;
  final _scrollController = ScrollController();
  final _planSectionKey = GlobalKey();
  final _residentSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    context.read<MembershipAssignmentCubit>().loadMemberships(
      libraryId: widget.library.id,
      ownerId: widget.library.ownerId,
    );

    // Prefill all fields if membership data is provided (for reassignment from expired seats)
    if (widget.prefilledMembership != null) {
      _prefillFromExpiredMembership(widget.prefilledMembership!);
    } else if (widget.prefilledSeatId != null) {
      // Only seat/slot prefilled (legacy case)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MembershipAssignmentCubit>().selectSeat(
          widget.prefilledSeatId!,
        );
        if (widget.prefilledSlotId != null) {
          context.read<MembershipAssignmentCubit>().selectCustomSlot(
            widget.prefilledSlotId!,
          );
        }
      });
    }

    // Listen to amount paid and discount changes to calculate remaining amount
    _amountPaidController.addListener(_calculateRemainingAmount);
    _discountController.addListener(_calculateRemainingAmount);

    // Listen to phone number changes to auto-populate name if tenant exists
    _phoneController.addListener(_onPhoneNumberChanged);
  }

  void _prefillFromExpiredMembership(Membership expiredMembership) {
    setState(() {
      // Store expired membership ID to exclude it from conflict check
      _excludeMembershipId = expiredMembership.id;

      // Prefill basic info
      final phoneNumber = expiredMembership.phoneNumber.replaceAll(
        RegExp(r'[+\s-]'),
        '',
      );
      final cleanPhoneNumber = phoneNumber.startsWith('91')
          ? phoneNumber.substring(2)
          : phoneNumber;
      _phoneController.text = cleanPhoneNumber;

      // Prefill name from membership if available
      if (expiredMembership.studentName != null &&
          expiredMembership.studentName!.isNotEmpty) {
        _nameController.text = expiredMembership.studentName!;
      }

      // Prefill plan
      _selectedPlan = expiredMembership.plan;

      // Prefill payment method
      _paymentMethod = expiredMembership.paymentMethod ?? PaymentMode.cash;

      // Calculate new dates: start from expiry date, end date based on plan
      final now = DateTime.now();
      final newStartDate = expiredMembership.endDate.isBefore(now)
          ? now
          : expiredMembership.endDate;
      _startDate = newStartDate;

      // Calculate end date based on plan or custom duration
      if (expiredMembership.customDurationMonths != null) {
        _useCustomDuration = true;
        _customDurationMonths = expiredMembership.customDurationMonths;
        _customDurationMonthsController.text = expiredMembership
            .customDurationMonths
            .toString();
        _expiryDate = DateTime(
          newStartDate.year,
          newStartDate.month + expiredMembership.customDurationMonths!,
          newStartDate.day,
        );
      } else if (expiredMembership.customDurationDays != null) {
        _useCustomDuration = true;
        _customDurationDays = expiredMembership.customDurationDays;
        _customDurationDaysController.text = expiredMembership
            .customDurationDays
            .toString();
        _expiryDate = newStartDate.add(
          Duration(days: expiredMembership.customDurationDays!),
        );
      } else {
        // Use plan duration
        final durationInDays = expiredMembership.plan.durationInDays;
        _expiryDate = newStartDate.add(Duration(days: durationInDays));
      }

      // Prefill payment breakdown if exists
      if (expiredMembership.paymentBreakdown != null) {
        final breakdown = expiredMembership.paymentBreakdown!;
        if (breakdown.isPartial) {
          _isPartialPayment = true;
          _amountPaidController.text = breakdown.amountPaid.toStringAsFixed(0);
          _amountRemainingController.text = breakdown.amountRemaining
              .toStringAsFixed(0);
          if (breakdown.discount > 0) {
            _discountController.text = breakdown.discount.toStringAsFixed(0);
          }
          if (breakdown.notes != null && breakdown.notes!.isNotEmpty) {
            _paymentNotesController.text = breakdown.notes!;
          }
        }
      }
    });

    // Prefill bed and plan, and fetch tenant name if registered (after setState to ensure UI is ready)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.prefilledSeatId != null) {
        context.read<MembershipAssignmentCubit>().selectSeat(
          widget.prefilledSeatId!,
        );
      }
      if (widget.prefilledSlotId != null) {
        context.read<MembershipAssignmentCubit>().selectCustomSlot(
          widget.prefilledSlotId!,
        );
      }

      // If name is not prefilled and phone number is available, try to fetch from user repository.
      // This handles cases where tenant is registered but name was not stored in the stay.
      if (_nameController.text.trim().isEmpty) {
        final phoneNumber = _phoneController.text.trim();
        if (phoneNumber.length == 10) {
          _checkAndPopulateStudentName(phoneNumber);
        }
      }
    });
  }

  void _onPhoneNumberChanged() {
    if (!mounted) return;

    final phoneNumber = _phoneController.text.trim();

    // Only check if phone number is complete (10 digits)
    if (phoneNumber.length == 10) {
      _checkAndPopulateStudentName(phoneNumber);
    } else if (phoneNumber.isEmpty) {
      // Clear name field if phone is cleared
      if (_nameController.text.isNotEmpty) {
        _nameController.clear();
      }
    }
  }

  Future<void> _checkAndPopulateStudentName(String phoneNumber) async {
    try {
      final formattedPhone = '+91$phoneNumber';
      final userRepository = di.sl<UserRepository>();

      final userResult = await userRepository.getUserByPhone(formattedPhone);

      userResult.fold(
        (_) {
          // Error or user not found - do nothing
        },
        (user) {
          if (user != null && mounted) {
            // Check if user has a name in their profile
            if (user.name.isNotEmpty && user.isProfileComplete) {
              // Only auto-populate if name field is empty
              // This allows owner to override if needed
              if (_nameController.text.trim().isEmpty) {
                _nameController.text = user.name;
              }
            }
          }
        },
      );
    } catch (e) {
      // Silently fail - don't show error for auto-population
      if (mounted) {
        debugPrint('Error checking tenant name: $e');
      }
    }
  }

  void _calculateRemainingAmount() {
    if (!mounted) return;

    final state = context.read<MembershipAssignmentCubit>().state;
    final slot = state.selectedCustomSlot;

    if (slot != null && _isPartialPayment) {
      final amountPaid = double.tryParse(_amountPaidController.text) ?? 0.0;
      final discount = double.tryParse(_discountController.text) ?? 0.0;
      final slotPrice = slot.price; // Monthly price

      // Calculate total price based on effective duration
      final durationInDays = _getEffectiveDurationInDays();
      final totalPriceBeforeDiscount = slotPrice * (durationInDays / 30.0);
      final totalPriceAfterDiscount = (totalPriceBeforeDiscount - discount)
          .clamp(0.0, double.infinity);

      final remaining = (totalPriceAfterDiscount - amountPaid).clamp(
        0.0,
        double.infinity,
      );

      // Update remaining amount controller without triggering listener
      if (_amountRemainingController.text != remaining.toStringAsFixed(2)) {
        _amountRemainingController.text = remaining.toStringAsFixed(2);
      }
    }
  }

  void _updateExpiryDate() {
    int durationInDays;
    if (_useCustomDuration) {
      if (_customDurationMonths != null && _customDurationMonths! > 0) {
        durationInDays = _customDurationMonths! * 30;
      } else if (_customDurationDays != null && _customDurationDays! > 0) {
        durationInDays = _customDurationDays!;
      } else {
        durationInDays = _selectedPlan.durationInDays;
      }
    } else {
      durationInDays = _selectedPlan.durationInDays;
    }
    _expiryDate = _startDate.add(Duration(days: durationInDays));
  }

  int _getEffectiveDurationInDays() {
    if (_useCustomDuration) {
      if (_customDurationMonths != null && _customDurationMonths! > 0) {
        return _customDurationMonths! * 30;
      } else if (_customDurationDays != null && _customDurationDays! > 0) {
        return _customDurationDays!;
      }
    }
    return _selectedPlan.durationInDays;
  }

  double _calculateTotalPrice() {
    final state = context.read<MembershipAssignmentCubit>().state;
    final slot = state.selectedCustomSlot;

    if (slot != null) {
      final slotPrice = slot.price;
      final durationInDays = _getEffectiveDurationInDays();
      return slotPrice * (durationInDays / 30.0);
    }

    // Fallback to hardcoded values for legacy slots
    switch (_selectedPlan) {
      case MembershipPlan.daily:
        return 50.0;
      case MembershipPlan.weekly:
        return 300.0;
      case MembershipPlan.monthly:
        return 1000.0;
      case MembershipPlan.quarterly:
        return 2500.0;
      case MembershipPlan.yearly:
        return 8000.0;
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneNumberChanged);
    _amountPaidController.removeListener(_calculateRemainingAmount);
    _discountController.removeListener(_calculateRemainingAmount);
    _nameController.dispose();
    _phoneController.dispose();
    _amountPaidController.dispose();
    _amountRemainingController.dispose();
    _paymentNotesController.dispose();
    _discountController.dispose();
    _customDurationDaysController.dispose();
    _customDurationMonthsController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToPlanSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      final targetContext = _planSectionKey.currentContext;
      if (targetContext == null || !targetContext.mounted) return;

      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: BlocConsumer<MembershipAssignmentCubit, MembershipAssignmentState>(
        listener: _handleStateChange,
        builder: (context, state) {
          if (state.isLoading) {
            return _buildLoadingState();
          }

          final seatDone =
              state.selectedSeatId != null &&
              state.selectedCustomSlotId != null;

          return Column(
            children: [
              // Hero header with step indicator
              AnimatedBuilder(
                animation: _phoneController,
                builder: (context, _) {
                  final residentDone =
                      _phoneController.text.trim().length == 10;
                  final done = [residentDone, seatDone, false];
                  final current = !residentDone ? 0 : (!seatDone ? 1 : 2);
                  return MembershipAppHeader(
                    library: widget.library,
                    stepper: MembershipStepper(done: done, current: current),
                  );
                },
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: FadeTransition(
                    opacity: _animationController,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.05),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: Curves.easeOut,
                            ),
                          ),
                      child: Column(
                        children: [
                          _buildBulkImportButton(context),
                          const SizedBox(height: 16),
                          _buildMainContent(state),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Sticky summary + CTA
              AnimatedBuilder(
                animation: Listenable.merge([
                  _discountController,
                  _phoneController,
                ]),
                builder: (context, _) => _buildStickyBar(state, seatDone),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStickyBar(MembershipAssignmentState state, bool seatDone) {
    double? total;
    if (seatDone) {
      final discount = double.tryParse(_discountController.text) ?? 0.0;
      total = (_calculateTotalPrice() - discount).clamp(0.0, double.infinity);
    }
    final residentDone = _phoneController.text.trim().length == 10;
    final String cta;
    if (!seatDone) {
      cta = 'Choose bed';
    } else if (!residentDone) {
      cta = 'Add phone';
    } else {
      cta = 'Review & assign';
    }
    return MembershipStickyBar(
      bedLabel: state.selectedSeatId,
      roomLabel: state.selectedCustomSlot?.name,
      total: total,
      ctaLabel: cta,
      ready: seatDone && residentDone,
      isSubmitting: state.isSubmitting,
      onPressed: () {
        if (!seatDone) {
          HapticFeedback.selectionClick();
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
        _onSubmit();
      },
    );
  }

  Widget _buildBulkImportButton(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (_) => di.sl<BulkImportCubit>()
                ..initialize(
                  libraryId: widget.library.id,
                  ownerId: widget.library.ownerId,
                ),
              child: BulkImportScreen(
                library: widget.library,
                ownerId: widget.library.ownerId,
              ),
            ),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppUIConstants.primaryLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              color: AppUIConstants.primaryLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bulk upload residents', style: AppUIConstants.bodyLg),
                Text(
                  'Import many tenants at once from an Excel file',
                  style: AppUIConstants.bodySm,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppUIConstants.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        MembershipAppHeader(
          library: widget.library,
          stepper: const MembershipStepper(
            done: [false, false, false],
            current: 0,
          ),
        ),
        Expanded(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: const [
              _SkeletonBlock(height: 64),
              SizedBox(height: 16),
              _SkeletonBlock(height: 170),
              SizedBox(height: 16),
              _SkeletonBlock(height: 260),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOccupiedSeatHint(MembershipAssignmentState state) {
    if (state.selectedSeatId == null || state.selectedCustomSlotId == null) {
      return const SizedBox.shrink();
    }
    final existing = state.existingMembershipForSeat(
      state.selectedSeatId!,
      state.selectedCustomSlotId!,
    );
    if (existing == null) return const SizedBox.shrink();

    final d = existing.endDate;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final endStr = '${d.day} ${months[d.month - 1]} ${d.year}';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppUIConstants.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          border: Border.all(
            color: AppUIConstants.warning.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppUIConstants.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This bed is occupied until $endStr. Set a start date after that to book in advance.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppUIConstants.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds either the resident or rent part of the form with all the
  /// existing wiring (controllers, callbacks, validation).
  Widget _buildFormPart(
    MembershipAssignmentState state,
    MembershipFormPart part,
  ) {
    return MembershipAssignmentFormCard(
      part: part,
      formKey: _formKey,
      phoneController: _phoneController,
      nameController: _nameController,
      selectedSeatId: state.selectedSeatId ?? '',
      selectedCustomSlotId: state.selectedCustomSlotId,
      selectedCustomSlot: state.selectedCustomSlot,
      expiryDate: _expiryDate,
      selectedPlan: _selectedPlan,
      isSubmitting: state.isSubmitting,
      paymentMethod: _paymentMethod,
      markCashReceived: _markCashReceived,
      startDate: _startDate,
      onStartDateChanged: (date) {
        setState(() {
          _startDate = date;
          _updateExpiryDate();
        });
      },
      customDurationDays: _customDurationDays,
      onCustomDurationDaysChanged: (days) {
        setState(() {
          _customDurationDays = days;
          if (days != null) {
            _customDurationDaysController.text = days.toString();
          }
          _updateExpiryDate();
        });
      },
      customDurationMonths: _customDurationMonths,
      onCustomDurationMonthsChanged: (months) {
        setState(() {
          _customDurationMonths = months;
          if (months != null) {
            _customDurationMonthsController.text = months.toString();
          }
          _updateExpiryDate();
        });
      },
      useCustomDuration: _useCustomDuration,
      onUseCustomDurationChanged: (value) {
        setState(() {
          _useCustomDuration = value;
          if (!value) {
            _customDurationDays = null;
            _customDurationMonths = null;
            _customDurationDaysController.clear();
            _customDurationMonthsController.clear();
          }
          _updateExpiryDate();
        });
      },
      customDurationDaysController: _customDurationDaysController,
      customDurationMonthsController: _customDurationMonthsController,
      onExpiryDateChanged: (date) => setState(() => _expiryDate = date),
      onPlanChanged: (plan) {
        setState(() {
          _selectedPlan = plan;
          _updateExpiryDate();
        });
        if (_isPartialPayment) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _calculateRemainingAmount();
          });
        }
      },
      onPaymentMethodChanged: (method) {
        setState(() {
          _paymentMethod = method;
          if (method != PaymentMode.cash && method != PaymentMode.upi) {
            _markCashReceived = false;
          }
        });
      },
      onMarkCashReceivedChanged: (value) {
        setState(() => _markCashReceived = value);
      },
      paymentReceivedDate: _paymentReceivedDate,
      onPaymentReceivedDateChanged: (date) {
        setState(() => _paymentReceivedDate = date);
      },
      amountPaidController: _amountPaidController,
      amountRemainingController: _amountRemainingController,
      paymentNotesController: _paymentNotesController,
      discountController: _discountController,
      isPartialPayment: _isPartialPayment,
      onPartialPaymentChanged: (value) {
        setState(() {
          _isPartialPayment = value;
          if (value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _calculateRemainingAmount();
            });
          } else {
            _amountPaidController.clear();
            _amountRemainingController.clear();
            _discountController.clear();
          }
        });
      },
      onSubmit: _onSubmit,
      onCalculateTotalPrice: _calculateTotalPrice,
      onCancel: () {
        context.read<MembershipAssignmentCubit>().clearSelection();
      },
    );
  }

  Widget _buildMainContent(MembershipAssignmentState state) {
    final hasSeatSelected = state.selectedSeatId != null;
    final isSelectionComplete =
        hasSeatSelected && state.selectedCustomSlotId != null;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Step 1: Resident details
          MembershipStepCard(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Resident details',
            subtitle: 'Phone number is required, name is optional',
            child: Container(
              key: _residentSectionKey,
              child: _buildFormPart(state, MembershipFormPart.resident),
            ),
          ),
          const SizedBox(height: 16),

          // Step 2: Bed map + room plan
          SeatSelectionCard(
            library: widget.library,
            state: state,
            isCollapsed: isSelectionComplete,
            enabled: !state.isSubmitting,
            useNewLayout: true,
            slotSectionKey: _planSectionKey,
            onCustomSlotSelected: (slotId) {
              HapticFeedback.selectionClick();
              context.read<MembershipAssignmentCubit>().selectCustomSlot(
                slotId,
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_isPartialPayment) {
                  _calculateRemainingAmount();
                }
              });
            },
            onSeatSelected: (seatId) {
              HapticFeedback.mediumImpact();
              context.read<MembershipAssignmentCubit>().selectSeat(
                seatId,
                clearCustomSlot: true,
              );
              _scrollToPlanSection();
            },
            onChangeSelection: () {
              context.read<MembershipAssignmentCubit>().clearSelection();
            },
          ),

          // Advance booking hint when an occupied bed+plan is selected
          if (isSelectionComplete) _buildOccupiedSeatHint(state),
          const SizedBox(height: 16),

          // Step 3: Rent & plan (unlocks after bed and plan selection)
          if (!isSelectionComplete)
            const MembershipStepCard(
              icon: Icons.payments_rounded,
              iconColor: AppUIConstants.primaryLight,
              title: 'Rent & plan',
              subtitle: 'Choose a bed and room type to unlock',
              dimmed: true,
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: AppUIConstants.textTertiary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stay duration, rent and payment details appear here.',
                      style: AppUIConstants.bodySm,
                    ),
                  ),
                ],
              ),
            )
          else
            AnimatedFadeSlide(
              child:
                  BlocBuilder<
                    MembershipAssignmentCubit,
                    MembershipAssignmentState
                  >(
                    buildWhen: (previous, current) =>
                        previous.selectedCustomSlotId !=
                        current.selectedCustomSlotId,
                    builder: (context, slotState) {
                      if (_isPartialPayment &&
                          slotState.selectedCustomSlot != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _calculateRemainingAmount();
                        });
                      }
                      return MembershipStepCard(
                        icon: Icons.payments_rounded,
                        iconColor: AppUIConstants.primaryLight,
                        title: 'Rent & plan',
                        subtitle:
                            '${state.selectedCustomSlot?.name ?? 'Room type'} · ${state.selectedCustomSlot?.displayTime ?? ''}',
                        child: _buildFormPart(state, MembershipFormPart.rent),
                      );
                    },
                  ),
            ),
        ],
      ),
    );
  }

  void _handleStateChange(
    BuildContext context,
    MembershipAssignmentState state,
  ) {
    if (state.isSuccess && state.savedMembership != null) {
      HapticFeedback.heavyImpact();
      sl<ReviewPromptService>().recordPositiveAction();
      _showSuccessMessage();
      _resetForm();
    } else if (state.isError && state.failure != null) {
      // Check if it is a bed limit exceeded failure
      if (state.failure is SeatLimitExceededFailure) {
        _showSeatLimitExceededDialog(state.failure as SeatLimitExceededFailure);
      } else {
        _showErrorMessage(state.failure!.message ?? 'An error occurred');
      }
    }
  }

  void _showSeatLimitExceededDialog(SeatLimitExceededFailure failure) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppUIConstants.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  size: 48,
                  color: AppUIConstants.warning,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Free Quota Reached',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppUIConstants.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'You have used all ${SubscriptionPlan.freeSeatsLimit} free beds. Subscribe to a plan to add more residents.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppUIConstants.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppUIConstants.primaryLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppUIConstants.primaryLight,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Plans start at just ₹149/month',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppUIConstants.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _navigateToSubscription();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppUIConstants.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'View Plans',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: AppUIConstants.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSubscription() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OwnerInAppPurchaseScreen(library: widget.library),
      ),
    );
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(
              'Tenant added to bed successfully!',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: AppUIConstants.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppUIConstants.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _onSubmit() {
    final state = context.read<MembershipAssignmentCubit>().state;

    // Validate room/bed plan selection
    if (state.selectedCustomSlotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a room type and a bed'),
          backgroundColor: AppUIConstants.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      HapticFeedback.mediumImpact();

      // Calculate values
      final totalPrice = _calculateTotalPrice();
      final discount = double.tryParse(_discountController.text) ?? 0.0;
      final finalPayable = (totalPrice - discount).clamp(0.0, double.infinity);

      // amountPaid logic:
      // - If partial payment: use the entered amount
      // - If not partial payment: always 0 (stay remains pending)
      // - Discount is tracked separately in paymentBreakdown
      final amountPaid = _isPartialPayment
          ? (double.tryParse(_amountPaidController.text) ?? 0.0)
          : 0.0;
      final amountRemaining = _isPartialPayment
          ? (double.tryParse(_amountRemainingController.text) ?? 0.0)
          : (discount > 0 ? finalPayable : 0.0);

      // Show confirmation dialog
      _showConfirmationDialog(
        totalPrice: totalPrice,
        discount: discount,
        amountPaid: amountPaid,
        amountRemaining: amountRemaining,
        state: state,
      );
    } else {
      final target = _residentSectionKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      }
    }
  }

  void _showConfirmationDialog({
    required double totalPrice,
    required double discount,
    required double amountPaid,
    required double amountRemaining,
    required MembershipAssignmentState state,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AssignmentConfirmationBottomSheet(
        totalPrice: totalPrice,
        discount: discount,
        amountPaid: amountPaid,
        amountRemaining: amountRemaining,
        isPartialPayment: _isPartialPayment,
        onConfirm: () {
          Navigator.of(sheetContext).pop();
          _executeAssignment(
            totalPrice: totalPrice,
            discount: discount,
            amountPaid: amountPaid,
            amountRemaining: amountRemaining,
          );
        },
        onCancel: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  void _executeAssignment({
    required double totalPrice,
    required double discount,
    required double amountPaid,
    required double amountRemaining,
  }) {
    final formattedPhone = '+91${_phoneController.text.trim()}';
    final studentName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : null;

    // Create payment breakdown
    PaymentBreakdown? paymentBreakdown;
    if (_isPartialPayment || discount > 0) {
      paymentBreakdown = PaymentBreakdown(
        amountPaid: amountPaid,
        amountRemaining: amountRemaining,
        notes: _paymentNotesController.text.trim(),
        discount: discount,
      );
    }

    context.read<MembershipAssignmentCubit>().assign(
      studentPhone: formattedPhone,
      studentName: studentName,
      expiryDate: _expiryDate,
      plan: _selectedPlan,
      paymentMethod: _paymentMethod,
      markCashReceived: _markCashReceived,
      paymentBreakdown: paymentBreakdown,
      startDate: _startDate,
      customDurationDays: _useCustomDuration ? _customDurationDays : null,
      customDurationMonths: _useCustomDuration ? _customDurationMonths : null,
      excludeMembershipId: _excludeMembershipId,
      paymentReceivedDate: _markCashReceived ? _paymentReceivedDate : null,
    );
  }

  void _resetForm() {
    _nameController.clear();
    _phoneController.clear();
    _amountPaidController.clear();
    _amountRemainingController.clear();
    _paymentNotesController.clear();
    _discountController.clear();
    setState(() {
      _startDate = DateTime.now();
      _expiryDate = DateTime.now().add(const Duration(days: 30));
      _paymentReceivedDate = DateTime.now();
      _selectedPlan = MembershipPlan.monthly;
      _paymentMethod = PaymentMode.cash;
      _markCashReceived = true;
      _isPartialPayment = false;
      _useCustomDuration = false;
      _customDurationDays = null;
      _customDurationMonths = null;
    });
    _customDurationDaysController.clear();
    _customDurationMonthsController.clear();
    context.read<MembershipAssignmentCubit>().resetForm();
  }
}

/// Confirmation bottom sheet showing payment summary before assignment.
class _AssignmentConfirmationBottomSheet extends StatelessWidget {
  const _AssignmentConfirmationBottomSheet({
    required this.totalPrice,
    required this.discount,
    required this.amountPaid,
    required this.amountRemaining,
    required this.isPartialPayment,
    required this.onConfirm,
    required this.onCancel,
  });

  final double totalPrice;
  final double discount;
  final double amountPaid;
  final double amountRemaining;
  final bool isPartialPayment;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final finalPayable = totalPrice - discount;

    return Container(
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppUIConstants.border,
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.center,
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppUIConstants.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppUIConstants.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Payment Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppUIConstants.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppUIConstants.divider),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Original Amount
                  _SummaryRow(
                    label: 'Original Amount',
                    value: '₹${totalPrice.toStringAsFixed(0)}',
                    isHighlighted: false,
                  ),
                  const SizedBox(height: 12),

                  // Discount
                  if (discount > 0) ...[
                    _SummaryRow(
                      label: 'Discount',
                      value: '-₹${discount.toStringAsFixed(0)}',
                      isHighlighted: false,
                      valueColor: AppUIConstants.success,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Final Payable
                  _SummaryRow(
                    label: 'Final Payable',
                    value: '₹${finalPayable.toStringAsFixed(0)}',
                    isHighlighted: true,
                  ),
                  const SizedBox(height: 16),

                  const Divider(height: 1, color: AppUIConstants.divider),
                  const SizedBox(height: 16),

                  // Partial Payment Details
                  if (isPartialPayment) ...[
                    _SummaryRow(
                      label: 'Amount Already Paid',
                      value: '₹${amountPaid.toStringAsFixed(0)}',
                      isHighlighted: false,
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      label: 'Remaining Balance',
                      value: '₹${amountRemaining.toStringAsFixed(0)}',
                      isHighlighted: true,
                      valueColor: AppUIConstants.error,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: discount > 0 ? 1 : 2,
                        child: OutlinedButton(
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: AppUIConstants.border),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      if (discount > 0) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: onCancel,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(
                                color: AppUIConstants.success,
                              ),
                              foregroundColor: AppUIConstants.success,
                            ),
                            child: const Text(
                              'Apply Discount',
                              style: TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        flex: discount > 0 ? 1 : 2,
                        child: ElevatedButton(
                          onPressed: onConfirm,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppUIConstants.success,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Assign Bed',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isHighlighted = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isHighlighted;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlighted ? 15 : 14,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: AppUIConstants.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlighted ? 18 : 15,
            fontWeight: FontWeight.bold,
            color:
                valueColor ??
                (isHighlighted
                    ? AppUIConstants.textPrimary
                    : AppUIConstants.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// Pulsing placeholder block for the loading skeleton.
class _SkeletonBlock extends StatefulWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  State<_SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<_SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            AppUIConstants.surface,
            AppUIConstants.surfaceMuted,
            _c.value,
          ),
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
          border: Border.all(color: AppUIConstants.border),
        ),
      ),
    );
  }
}
