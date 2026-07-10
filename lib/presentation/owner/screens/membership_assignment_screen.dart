import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pg_manager/presentation/core/app_ui_constants.dart';

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
/// Premium, guided two-phase UX: Select Bed -> Add Tenant.
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocConsumer<MembershipAssignmentCubit, MembershipAssignmentState>(
        listener: _handleStateChange,
        builder: (context, state) {
          if (state.isLoading) {
            return _buildLoadingState();
          }

          return Column(
            children: [
              // Fixed Header
              MembershipAppHeader(library: widget.library),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
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
                          // Bulk Import Prominent Button
                          _buildBulkImportButton(context),
                          const SizedBox(height: 20),

                          // Progress Indicator
                          MembershipProgressIndicator(
                            step1Complete:
                                state.selectedSeatId != null &&
                                state.selectedCustomSlotId != null,
                          ),
                          const SizedBox(height: 20),

                          // Main Content Area
                          _buildMainContent(state),

                          const SizedBox(height: 20),

                          // Banner Ad - Clean placement at bottom
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBulkImportButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppUIConstants.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
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
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.upload_file_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bulk Upload Tenants',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Import multiple tenants from Excel file',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        MembershipAppHeader(library: widget.library),
        const Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFF6366F1),
                  strokeWidth: 3,
                ),
                SizedBox(height: 16),
                Text(
                  'Loading beds...',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
              ],
            ),
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
    final months = [
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
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: Colors.blue.shade700,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This bed is occupied until $endStr. Set a start date after that to book in advance.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade800,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(MembershipAssignmentState state) {
    final hasSeatSelected = state.selectedSeatId != null;
    final isSelectionComplete =
        hasSeatSelected && state.selectedCustomSlotId != null;

    return Column(
      children: [
        // Phase 1: Plan & Bed Selection
        SeatSelectionCard(
          library: widget.library,
          state: state,
          isCollapsed: isSelectionComplete,
          enabled: !state.isSubmitting,
          useNewLayout: true,
          slotSectionKey: _planSectionKey,
          onCustomSlotSelected: (slotId) {
            HapticFeedback.selectionClick();
            context.read<MembershipAssignmentCubit>().selectCustomSlot(slotId);
            // Recalculate remaining amount when slot changes
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

        // Phase 2: Assignment Form (appears after bed and plan selection)
        if (isSelectionComplete) ...[
          const SizedBox(height: 16),
          AnimatedFadeSlide(
            child: BlocBuilder<MembershipAssignmentCubit, MembershipAssignmentState>(
              buildWhen: (previous, current) =>
                  previous.selectedCustomSlotId != current.selectedCustomSlotId,
              builder: (context, slotState) {
                // Recalculate remaining amount when slot changes
                if (_isPartialPayment && slotState.selectedCustomSlot != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _calculateRemainingAmount();
                  });
                }
                return MembershipAssignmentFormCard(
                  formKey: _formKey,
                  phoneController: _phoneController,
                  nameController: _nameController,
                  selectedSeatId: state.selectedSeatId!,
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
                      // Recalculate expiry date based on new start date
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
                        _customDurationMonthsController.text = months
                            .toString();
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
                  customDurationMonthsController:
                      _customDurationMonthsController,
                  onExpiryDateChanged: (date) =>
                      setState(() => _expiryDate = date),
                  onPlanChanged: (plan) {
                    setState(() {
                      _selectedPlan = plan;
                      _updateExpiryDate();
                    });
                    // Recalculate remaining amount when plan changes
                    if (_isPartialPayment) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _calculateRemainingAmount();
                      });
                    }
                  },
                  onPaymentMethodChanged: (method) {
                    setState(() {
                      _paymentMethod = method;
                      // Reset cash received toggle when changing payment method
                      if (method != PaymentMode.cash &&
                          method != PaymentMode.upi) {
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
                        // Calculate remaining when partial payment is enabled
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _calculateRemainingAmount();
                        });
                      } else {
                        // Clear fields when disabled
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
              },
            ),
          ),
        ],
      ],
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'You have used all ${SubscriptionPlan.freeSeatsLimit} free beds. Subscribe to a plan to add more tenants.',
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
                  color: AppUIConstants.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppUIConstants.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Plans start at just ₹149/month',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppUIConstants.primary,
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
              'Tenant stay assigned successfully!',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
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
        backgroundColor: const Color(0xFFDC2626),
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
          content: Text('Please select a room or bed plan'),
          backgroundColor: Color(0xFFDC2626),
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
        color: Colors.white,
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
                color: Colors.grey.shade300,
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
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Payment Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

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
                      valueColor: const Color(0xFF10B981),
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

                  const Divider(height: 1),
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
                      valueColor: const Color(0xFFDC2626),
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
                            side: BorderSide(color: Colors.grey.shade300),
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
                              side: const BorderSide(color: Color(0xFF10B981)),
                              foregroundColor: const Color(0xFF10B981),
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
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Assign Stay',
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
            color: Colors.grey.shade700,
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
                    ? const Color(0xFF1E293B)
                    : Colors.grey.shade800),
          ),
        ),
      ],
    );
  }
}
