import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/user.dart';
import '../../auth/cubit/phone_auth_cubit.dart';
import '../../auth/cubit/phone_auth_state.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/web_content_constraint.dart';
import 'admin_intelligence_screen.dart';

/// Hidden admin login screen.
/// Uses same phone auth as regular users but sets role to admin.
/// Access by tapping logo 7 times on phone auth screen.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  static const _countryCode = '+91';

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PhoneAuthCubit>()..setRole(UserRole.admin),
      child: Scaffold(
        backgroundColor: AppUIConstants.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
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
                authenticated: (authState) {
                  // Check if user is admin
                  if (authState.user.role == UserRole.admin) {
                    // Navigate to admin intelligence screen
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => kIsWeb
                            ? const WebContentConstraint(
                                child: AdminIntelligenceScreen(),
                              )
                            : const AdminIntelligenceScreen(),
                      ),
                    );
                  } else {
                    // Not an admin - show error
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Access denied. This account is not an admin.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    // Sign out and go back
                    context.read<PhoneAuthCubit>().signOut();
                  }
                },
              );
            },
            builder: (context, state) {
              return state.map(
                initial: (_) => _buildPhoneInput(context),
                sendingOtp: (_) => _buildLoading('Sending OTP...'),
                otpSent: (s) => _buildOtpInput(context, s),
                verifyingOtp: (_) => _buildLoading('Verifying...'),
                checkingAuth: (_) => _buildLoading('Checking...'),
                authenticated: (_) => _buildLoading('Redirecting...'),
                signingOut: (_) => _buildLoading('...'),
                signedOut: (_) => _buildPhoneInput(context),
                error: (_) => _buildPhoneInput(context),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: AppUIConstants.bodyMd),
        ],
      ),
    );
  }

  Widget _buildPhoneInput(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),

          // Admin Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppUIConstants.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.admin_panel_settings,
              color: AppUIConstants.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: AppUIConstants.spacingLg),

          Text(
            'Admin Access',
            style: AppUIConstants.headingLg,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppUIConstants.spacingSm),
          Text(
            'Sign in with your admin phone number',
            style: AppUIConstants.bodySm.copyWith(
              color: AppUIConstants.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppUIConstants.spacing2Xl),

          // Phone Input
          Container(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            decoration: AppUIConstants.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phone Number', style: AppUIConstants.labelMd),
                const SizedBox(height: AppUIConstants.spacingSm),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    hintText: '10-digit mobile number',
                    hintStyle: AppUIConstants.bodyMd.copyWith(
                      color: AppUIConstants.textTertiary,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _countryCode,
                            style: AppUIConstants.bodyMd.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            color: AppUIConstants.border,
                          ),
                        ],
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0),
                    filled: true,
                    fillColor: AppUIConstants.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusMd,
                      ),
                      borderSide: BorderSide(color: AppUIConstants.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusMd,
                      ),
                      borderSide: BorderSide(color: AppUIConstants.border),
                    ),
                    counterText: '',
                  ),
                ),

                const SizedBox(height: AppUIConstants.spacingLg),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final phone = _phoneController.text.trim();
                      if (phone.length == 10) {
                        context.read<PhoneAuthCubit>().sendOtp(
                          '$_countryCode$phone',
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter valid 10-digit number'),
                          ),
                        );
                      }
                    },
                    style: AppUIConstants.primaryButtonStyle,
                    child: const Text(
                      'Send OTP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInput(BuildContext context, PhoneAuthOtpSent state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),

          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppUIConstants.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline,
              color: AppUIConstants.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: AppUIConstants.spacingLg),

          Text(
            'Enter OTP',
            style: AppUIConstants.headingLg,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppUIConstants.spacingSm),
          Text(
            'Enter the 6-digit code sent to\n${state.phoneNumber}',
            style: AppUIConstants.bodySm.copyWith(
              color: AppUIConstants.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppUIConstants.spacing2Xl),

          Container(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            decoration: AppUIConstants.cardDecoration,
            child: Column(
              children: [
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '123456',
                    hintStyle: TextStyle(
                      color: AppUIConstants.textTertiary,
                      fontSize: 24,
                      letterSpacing: 8,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: AppUIConstants.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusMd,
                      ),
                      borderSide: BorderSide(color: AppUIConstants.border),
                    ),
                  ),
                ),

                const SizedBox(height: AppUIConstants.spacingLg),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final otp = _otpController.text.trim();
                      if (otp.length == 6) {
                        context.read<PhoneAuthCubit>().verifyOtp(otp);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter 6-digit OTP')),
                        );
                      }
                    },
                    style: AppUIConstants.primaryButtonStyle,
                    child: const Text(
                      'Verify',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppUIConstants.spacingMd),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        _otpController.clear();
                        context.read<PhoneAuthCubit>().goBackToPhoneInput();
                      },
                      child: Text(
                        'Change Number',
                        style: TextStyle(color: AppUIConstants.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.read<PhoneAuthCubit>().resendOtp(),
                      child: const Text('Resend OTP'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
