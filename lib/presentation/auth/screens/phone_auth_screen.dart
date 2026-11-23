import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:unicons/unicons.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/post_login_redirect.dart';
import '../../../domain/entities/user.dart';
import '../../admin/screens/admin_intelligence_screen.dart';
import '../../admin/screens/admin_login_screen.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/phone_auth_cubit.dart';
import '../cubit/phone_auth_state.dart';
import '../widgets/auth_brand_header.dart';
import '../widgets/role_selector.dart';

/// Phone authentication screen with OTP verification.
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// India country code - fixed prefix for all phone numbers.
  static const _countryCode = '+91';

  static const _resendSeconds = 30;
  Timer? _resendTimer;
  int _resendLeft = 0;

  /// Counter for hidden admin login trigger.
  int _logoTapCount = 0;
  DateTime? _lastLogoTap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PhoneAuthCubit>().checkAuthStatus();
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendLeft = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendLeft--);
      if (_resendLeft <= 0) t.cancel();
    });
  }

  /// Validates that phone number is exactly 10 digits.
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (value.length != 10) {
      return 'Phone number must be exactly 10 digits';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
      return 'Phone number must contain only digits';
    }
    return null;
  }

  /// Formats phone number with country code for Firebase.
  String _formatPhoneNumber(String rawNumber) {
    return '$_countryCode$rawNumber';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: SafeArea(
        child: BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
          listener: (context, state) {
            state.mapOrNull(
              error: (errorState) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      errorState.failure.message ?? 'An error occurred',
                    ),
                    backgroundColor: AppUIConstants.error,
                  ),
                );
              },
              otpSent: (_) => _startResendTimer(),
              authenticated: (authState) {
                _navigateBasedOnRole(context, authState.user);
              },
              signedOut: (_) {
                // Stay on this screen after sign out
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Signed out successfully'),
                    backgroundColor: AppUIConstants.success,
                  ),
                );
              },
            );
          },
          builder: (context, state) {
            return state.map(
              initial: (s) => _buildPhoneInput(context, s.selectedRole),
              sendingOtp: (s) => _buildLoading('Sending OTP...'),
              otpSent: (s) => _buildOtpInput(context, s),
              verifyingOtp: (s) => _buildLoading('Verifying OTP...'),
              checkingAuth: (_) => _buildLoading('Checking authentication...'),
              authenticated: (s) => _buildLoading('Redirecting...'),
              signingOut: (_) => _buildLoading('Signing out...'),
              signedOut: (_) => _buildPhoneInput(context, UserRole.owner),
              error: (s) => _buildPhoneInput(context, s.selectedRole),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppUIConstants.primary),
          const SizedBox(height: AppUIConstants.spacingLg),
          Text(message, style: AppUIConstants.bodyMd),
        ],
      ),
    );
  }

  Widget _buildPhoneInput(BuildContext context, UserRole selectedRole) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthBrandHeader(
              title: 'Welcome back',
              subtitle: 'Sign in with your phone number',
              onLogoTap: _handleLogoTap,
            ),
            const SizedBox(height: 40),
            Text('I am a', style: AppUIConstants.labelMd),
            const SizedBox(height: AppUIConstants.spacingSm),
            RoleSelector(
              selectedRole: selectedRole,
              onChanged: (role) => context.read<PhoneAuthCubit>().setRole(role),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _phoneController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Phone number',
                hintText: '10-digit mobile number',
                filled: true,
                fillColor: AppUIConstants.primary.withValues(alpha: 0.04),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                  borderSide: const BorderSide(
                    color: AppUIConstants.primary,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                  borderSide: const BorderSide(
                    color: AppUIConstants.accent,
                    width: 2,
                  ),
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        UniconsLine.phone,
                        size: 20,
                        color: AppUIConstants.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(_countryCode, style: AppUIConstants.bodyLg),
                      Container(
                        height: 24,
                        width: 1,
                        margin: const EdgeInsets.only(left: 8),
                        color: AppUIConstants.border,
                      ),
                    ],
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0),
              ),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: _validatePhoneNumber,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: AppUIConstants.primaryButtonStyle.copyWith(
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
              ),
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  final rawPhone = _phoneController.text.trim();
                  final formattedPhone = _formatPhoneNumber(rawPhone);
                  context.read<PhoneAuthCubit>().sendOtp(formattedPhone);
                }
              },
              icon: const Icon(UniconsLine.arrow_right, size: 20),
              label: const Text(
                'Send OTP',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  UniconsLine.shield_check,
                  size: 16,
                  color: AppUIConstants.textTertiary,
                ),
                const SizedBox(width: AppUIConstants.spacingXs),
                Text(
                  'We will send a 6-digit code to verify your number',
                  style: AppUIConstants.bodySm.copyWith(
                    color: AppUIConstants.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpInput(BuildContext context, PhoneAuthOtpSent state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthBrandHeader(
            title: 'Verify your number',
            subtitle: 'Enter the 6-digit code sent to\n${state.phoneNumber}',
            onLogoTap: _handleLogoTap,
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _otpController,
            decoration: InputDecoration(
              labelText: 'OTP code',
              hintText: '123456',
              hintStyle: TextStyle(
                color: AppUIConstants.disabled,
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: const Icon(UniconsLine.lock_alt, size: 20),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: AppUIConstants.statValue.copyWith(
              fontSize: 24,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: AppUIConstants.primaryButtonStyle.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
            ),
            onPressed: () {
              final otp = _otpController.text.trim();
              if (otp.length == 6) {
                context.read<PhoneAuthCubit>().verifyOtp(otp);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter 6-digit OTP')),
                );
              }
            },
            icon: const Icon(UniconsLine.check, size: 20),
            label: const Text(
              'Verify & continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: AppUIConstants.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  _otpController.clear();
                  context.read<PhoneAuthCubit>().goBackToPhoneInput();
                },
                icon: const Icon(UniconsLine.arrow_left, size: 18),
                label: const Text('Change number'),
              ),
              TextButton.icon(
                onPressed: _resendLeft > 0
                    ? null
                    : () {
                        _otpController.clear();
                        context.read<PhoneAuthCubit>().resendOtp();
                      },
                icon: const Icon(UniconsLine.redo, size: 18),
                label: Text(
                  _resendLeft > 0 ? 'Resend in ${_resendLeft}s' : 'Resend OTP',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateBasedOnRole(BuildContext context, User user) {
    switch (user.role) {
      case UserRole.admin:
        // Admin users go to admin intelligence screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminIntelligenceScreen()),
        );
        break;
      case UserRole.owner:
        context.goToOwnerDashboard();
        break;
      case UserRole.student:
        final router = GoRouter.of(context);
        context.goToStudentHome(userId: user.id);
        final redirect = PostLoginRedirect.take();
        if (redirect != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => router.push(redirect),
          );
        }
        break;
    }
  }

  /// Handles logo tap for hidden admin login.
  /// Tapping 7 times within 3 seconds opens admin login.
  void _handleLogoTap() {
    final now = DateTime.now();
    if (_lastLogoTap != null && now.difference(_lastLogoTap!).inSeconds > 3) {
      _logoTapCount = 0;
    }
    _lastLogoTap = now;
    _logoTapCount++;
    if (_logoTapCount >= 7) {
      _logoTapCount = 0;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
    }
  }
}
