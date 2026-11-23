import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../../../data/services/app_rating_service.dart';
import '../../../data/services/device_info_service.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/get_owner_library.dart';
import '../../admin/screens/admin_login_screen.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../../core/widgets/web_content_constraint.dart';
import '../../owner/cubit/device_sessions_cubit.dart';
import '../../owner/cubit/owner_settings_cubit.dart';
import '../../owner/cubit/owner_settings_state.dart';
import '../../auth/cubit/phone_auth_cubit.dart';
import '../../auth/cubit/phone_auth_state.dart';
import '../../owner/screens/active_devices_screen.dart';
import '../../owner/screens/library_form_screen.dart';
import '../../owner/widgets/managers/owner_managers_section.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import '../widgets/profile_widgets.dart';
import 'profile_form_screen.dart';

/// Resident profile: an ID-card hero with completion ring, quick facts and
/// grouped settings.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.user});

  final User user;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Library? _library;
  late User _currentUser;

  bool get _isOwner => _currentUser.role == UserRole.owner;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;

    // Initialize ProfileCubit with user data (including avatar URL)
    if (mounted) {
      final profileCubit = context.read<ProfileCubit>();
      profileCubit.loadUser(_currentUser);
    }

    // Load PG for owners
    if (_currentUser.role == UserRole.owner) {
      _loadLibrary();
    }
  }

  Future<void> _loadLibrary() async {
    final getOwnerLibrary = sl<GetOwnerLibrary>();
    final result = await getOwnerLibrary(
      GetOwnerLibraryParams(ownerId: _currentUser.ownerAccountId),
    );
    result.fold((_) {}, (library) {
      if (!mounted) return;
      setState(() {
        _library = library;
      });
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local user when widget is rebuilt with new data
    // (e.g., after profile completion from home screen)
    if (oldWidget.user != widget.user) {
      setState(() {
        _currentUser = widget.user;
      });
      context.read<ProfileCubit>().loadUser(widget.user);
    }
  }

  void _openPgDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LibraryFormScreen(
          ownerId: _currentUser.ownerAccountId,
          ownerPhone: _currentUser.phone,
        ),
      ),
    );
  }

  /// Fraction (0..1) of profile fields that are filled in.
  double _completion(String? avatarUrl) {
    final checks = <bool>[
      _currentUser.isProfileComplete,
      _currentUser.isPhoneVerified,
      avatarUrl != null,
      if (!_isOwner) ...[
        _currentUser.address != null,
        _currentUser.gender != null,
      ],
    ];
    return checks.where((c) => c).length / checks.length;
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          final progress = _completion(state.avatarUrl);
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHero(context, state, progress),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).padding.bottom + 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!user.isProfileComplete) ...[
                      _Reveal(
                        index: 0,
                        child: ProfileCompletionCard(
                          onComplete: () => _navigateToEdit(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Owners: the header already shows role, phone and
                    // verification, so the quick-fact tiles would repeat it.
                    if (!_isOwner) ...[
                      _Reveal(index: 1, child: _buildQuickFacts(progress)),
                      const SizedBox(height: 4),
                    ],
                    _Reveal(index: 2, child: _buildDetailsCard(context)),
                    if (_isOwner) _Reveal(index: 3, child: _buildMyPgGroup()),
                    // Owner settings and managers: owners only, not managers.
                    if (_isOwner && !user.isManager) ...[
                      _Reveal(
                        index: 3,
                        child: BlocProvider(
                          create: (_) {
                            final cubit = sl<OwnerSettingsCubit>();
                            cubit.loadSettings(user);
                            return cubit;
                          },
                          child: const _OwnerSettingsSection(),
                        ),
                      ),
                      _Reveal(
                        index: 3,
                        child: OwnerManagersSection(ownerId: user.id),
                      ),
                    ],
                    _Reveal(index: 4, child: _SecuritySection(userId: user.id)),
                    const _Reveal(index: 5, child: _AccountDeletionSection()),
                    const _Reveal(index: 6, child: _AppInfoSection()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero: ID card
  // ---------------------------------------------------------------------------

  Widget _buildHero(BuildContext context, ProfileState state, double progress) {
    final user = _currentUser;
    final percent = (progress * 100).round();
    final pgName = _isOwner ? _library?.name : null;
    const muted = AppUIConstants.textSecondary;

    return PremiumHero(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'My Profile',
                  style: TextStyle(
                    color: AppUIConstants.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Tooltip(
                message: 'Edit profile',
                child: Material(
                  color: AppUIConstants.surfaceMuted,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _navigateToEdit(context);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.edit_rounded,
                        color: AppUIConstants.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppUIConstants.surface,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusXl),
              border: Border.all(color: AppUIConstants.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CompletionRing(
                      progress: progress,
                      size: 88,
                      strokeWidth: 4,
                      color: AppUIConstants.primary,
                      child: ProfileAvatar(
                        user: user,
                        avatarUrl: state.avatarUrl,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppUIConstants.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (pgName != null) ...[
                            const SizedBox(height: 4),
                            _HeroLine(
                              icon: Icons.apartment_rounded,
                              text: pgName,
                              color: muted,
                            ),
                          ],
                          const SizedBox(height: 4),
                          _HeroLine(
                            icon: Icons.phone_rounded,
                            text: user.phone,
                            color: muted,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              PremiumStatusPill(
                                _isOwner
                                    ? (user.isManager
                                          ? 'PG MANAGER'
                                          : 'PG OWNER')
                                    : 'RESIDENT',
                                color: AppUIConstants.primary,
                              ),
                              if (user.isPhoneVerified)
                                const PremiumStatusPill(
                                  'VERIFIED',
                                  color: AppUIConstants.success,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppUIConstants.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      user.isProfileComplete
                          ? Icons.verified_rounded
                          : Icons.donut_large_rounded,
                      size: 16,
                      color: AppUIConstants.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Profile $percent% complete',
                        style: const TextStyle(
                          color: AppUIConstants.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (user.createdAt != null)
                      Text(
                        'Since ${DateFormat('MMM yyyy').format(user.createdAt!)}',
                        style: const TextStyle(color: muted, fontSize: 12),
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

  /// Owners: a single, clearly labelled entry point to edit the PG.
  Widget _buildMyPgGroup() {
    final pgName = _library?.name;
    return SettingsGroup(
      title: 'My PG',
      children: [
        SettingsTile(
          icon: Icons.apartment_rounded,
          title: 'PG details',
          subtitle: pgName == null
              ? 'Name, address, photos, amenities and UPI'
              : '$pgName · photos, amenities and UPI',
          onTap: _openPgDetails,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Quick facts
  // ---------------------------------------------------------------------------

  Widget _buildQuickFacts(double progress) {
    final user = _currentUser;
    return Row(
      children: [
        Expanded(
          child: PremiumStatTile(
            icon: Icons.donut_large_rounded,
            value: '${(progress * 100).round()}%',
            label: 'Profile',
            color: AppUIConstants.primaryLight,
            onTap: () => _isOwner ? _openPgDetails() : _navigateToEdit(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PremiumStatTile(
            icon: user.isPhoneVerified
                ? Icons.verified_rounded
                : Icons.warning_amber_rounded,
            value: user.isPhoneVerified ? 'Yes' : 'Pending',
            label: 'Phone verified',
            color: user.isPhoneVerified
                ? AppUIConstants.primaryLight
                : AppUIConstants.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _isOwner
              ? PremiumStatTile(
                  icon: Icons.workspace_premium_rounded,
                  value: 'Owner',
                  label: 'Account type',
                  color: AppUIConstants.primaryLight,
                )
              : PremiumStatTile(
                  icon: Icons.credit_card_rounded,
                  value: user.isAccessCardIssued ? 'Issued' : 'No',
                  label: 'Access card',
                  color: user.isAccessCardIssued
                      ? AppUIConstants.primaryLight
                      : AppUIConstants.textSecondary,
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Details
  // ---------------------------------------------------------------------------

  Widget _buildDetailsCard(BuildContext context) {
    final user = _currentUser;
    // (icon, label, value, value colour)
    final details = <(IconData, String, String, Color?)>[
      (
        Icons.badge_rounded,
        'Full Name',
        user.isProfileComplete ? user.name : 'Not set',
        user.isProfileComplete ? null : AppUIConstants.textTertiary,
      ),
      (Icons.phone_rounded, 'Phone Number', user.phone, null),
      if (user.email != null) (Icons.email_rounded, 'Email', user.email!, null),
      if (!_isOwner) ...[
        (
          Icons.credit_card_rounded,
          'Access Card Issued',
          user.isAccessCardIssued ? 'Yes' : 'No',
          user.isAccessCardIssued
              ? AppUIConstants.success
              : AppUIConstants.warning,
        ),
        if (user.address != null)
          (Icons.location_on_rounded, 'Address', user.address!, null),
        if (user.gender != null)
          (Icons.person_outline_rounded, 'Gender', user.gender!, null),
      ],
      if (user.createdAt != null)
        (
          Icons.calendar_today_rounded,
          _isOwner ? 'Member Since' : 'Resident Since',
          DateFormat('MMMM dd, yyyy').format(user.createdAt!),
          null,
        ),
    ];
    final rows = [
      for (var i = 0; i < details.length; i++)
        InfoTile(
          icon: details[i].$1,
          label: details[i].$2,
          value: details[i].$3,
          valueColor: details[i].$4,
          showDivider: i != details.length - 1,
        ),
    ];

    return SectionCard(
      title: 'Personal Information',
      icon: Icons.person_rounded,
      delay: 60,
      onTap: () => _navigateToEdit(context),
      actionButton: const Icon(
        Icons.edit_outlined,
        size: 18,
        color: AppUIConstants.textTertiary,
      ),
      children: rows,
    );
  }

  void _navigateToEdit(BuildContext context) async {
    final updatedUser = await Navigator.of(context).push<User>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => BlocProvider(
          create: (_) => sl<ProfileCubit>(),
          child: ProfileFormScreen(user: _currentUser),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
      ),
    );

    // Update local state with the updated user data to reflect changes immediately
    if (updatedUser != null && context.mounted) {
      setState(() {
        _currentUser = updatedUser;
      });
      // Also update the ProfileCubit to ensure avatar and other data updates
      context.read<ProfileCubit>().loadUser(updatedUser);
      // Update PhoneAuthCubit so the rest of the app has the latest user data
      context.read<PhoneAuthCubit>().updateUser(updatedUser);
    }
  }
}

/// Staggered fade/slide entrance.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 420 + index * 70),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Owner settings section widget.
class _OwnerSettingsSection extends StatelessWidget {
  const _OwnerSettingsSection();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OwnerSettingsCubit, OwnerSettingsState>(
      listener: (context, state) {
        final user = state.user;
        if (state.status == OwnerSettingsStatus.success && user != null) {
          context.read<PhoneAuthCubit>().updateUser(user);
        }
      },
      builder: (context, state) {
        final isSaving = state.status == OwnerSettingsStatus.loading;
        final cubit = context.read<OwnerSettingsCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsGroup(
              title: 'Visibility',
              children: [
                _SwitchTile(
                  icon: Icons.apartment_rounded,
                  title: 'Allow residents to see PG listing',
                  subtitle: 'Residents can explore other PGs',
                  value: state.showOtherLibraries,
                  onChanged: isSaving ? null : cubit.updateShowOtherLibraries,
                ),
                _SwitchTile(
                  icon: Icons.storefront_rounded,
                  title: 'Show my PG in marketplace',
                  subtitle: 'Your PG appears in resident listings',
                  value: state.showMyLibraryInListing,
                  onChanged: isSaving
                      ? null
                      : cubit.updateShowMyLibraryInListing,
                ),
              ],
            ),
            SettingsGroup(
              title: 'WhatsApp Automation',
              children: [
                _SwitchTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'Auto-send invoices',
                  subtitle: 'Send invoice PDF on WhatsApp after payment',
                  value: state.autoWhatsAppInvoicesEnabled,
                  color: AppUIConstants.success,
                  onChanged: isSaving ? null : cubit.updateAutoWhatsAppInvoices,
                ),
                _SwitchTile(
                  icon: Icons.notifications_active_rounded,
                  title: 'Auto-send payment reminders',
                  subtitle: 'Send fee reminders on WhatsApp automatically',
                  value: state.autoWhatsAppFeeRemindersEnabled,
                  color: AppUIConstants.success,
                  onChanged: isSaving
                      ? null
                      : cubit.updateAutoWhatsAppFeeReminders,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.color = AppUIConstants.primaryLight,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      color: color,
      onTap: onChanged == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onChanged!(!value);
            },
      trailing: Switch(
        value: value,
        onChanged: onChanged == null
            ? null
            : (v) {
                HapticFeedback.selectionClick();
                onChanged!(v);
              },
      ),
    );
  }
}

/// Account deletion section required for users who can create accounts.
class _AccountDeletionSection extends StatefulWidget {
  const _AccountDeletionSection();

  @override
  State<_AccountDeletionSection> createState() =>
      _AccountDeletionSectionState();
}

class _AccountDeletionSectionState extends State<_AccountDeletionSection> {
  bool _isDeleting = false;

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppUIConstants.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUIConstants.radiusXl),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppUIConstants.error.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppUIConstants.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Delete account?', style: AppUIConstants.headingMd),
              const SizedBox(height: 8),
              const Text(
                'This permanently deletes your account and signs you out. This action cannot be undone.',
                textAlign: TextAlign.center,
                style: AppUIConstants.bodyMd,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppUIConstants.textPrimary,
                        side: const BorderSide(color: AppUIConstants.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: const Text('Keep account'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppUIConstants.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.mediumImpact();
    setState(() => _isDeleting = true);
    final authCubit = context.read<PhoneAuthCubit>();
    await authCubit.deleteAccount();

    if (!mounted) return;
    setState(() => _isDeleting = false);

    final authState = authCubit.state;
    if (authState is PhoneAuthError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.failure.message ?? 'Account deletion failed'),
          backgroundColor: AppUIConstants.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account deleted successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      title: 'Danger zone',
      children: [
        SettingsTile(
          icon: Icons.delete_forever_rounded,
          title: 'Delete Account',
          subtitle: 'Permanently remove your account from PG Sathi',
          color: AppUIConstants.error,
          onTap: _isDeleting ? null : _confirmDeleteAccount,
          trailing: _isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppUIConstants.error,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

const _supportEmail = 'support@pgsathi.in';
const _supportPhone = '9548582776';

/// One icon + text line on the dark profile header.
class _HeroLine extends StatelessWidget {
  const _HeroLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 13, letterSpacing: 0.2),
          ),
        ),
      ],
    );
  }
}

/// App information section with version, privacy policy, and terms.
/// Hidden admin access: tap version number 7 times.
class _AppInfoSection extends StatefulWidget {
  const _AppInfoSection();

  @override
  State<_AppInfoSection> createState() => _AppInfoSectionState();
}

class _AppInfoSectionState extends State<_AppInfoSection> {
  int _versionTapCount = 0;
  DateTime? _lastTapTime;

  void _handleVersionTap() {
    final now = DateTime.now();

    // Reset counter if more than 3 seconds between taps
    if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds > 3) {
      _versionTapCount = 0;
    }

    _lastTapTime = now;
    _versionTapCount++;

    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      _openAdminLogin();
    }
  }

  Future<void> _handleRateApp() async {
    final success = await sl<AppRatingService>().requestReview();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open store listing')),
      );
    }
  }

  void _openAdminLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _AdminLoginWrapper()));
  }

  @override
  Widget build(BuildContext context) {
    final packageInfo = sl<PackageInfo>();
    final version = '${packageInfo.version} (${packageInfo.buildNumber})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroup(
          title: 'About',
          children: [
            // App Version - tap 7 times for admin access
            SettingsTile(
              icon: Icons.phone_android_rounded,
              title: 'Version',
              subtitle: version,
              color: AppUIConstants.secondary,
              onTap: _handleVersionTap,
              showChevron: false,
            ),
            SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              color: AppUIConstants.secondary,
              onTap: () => context.push('/privacy-policy'),
            ),
            SettingsTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              color: AppUIConstants.secondary,
              onTap: () => context.push('/terms-of-service'),
            ),
            if (!kIsWeb)
              SettingsTile(
                icon: Icons.star_rate_rounded,
                title: 'Rate Our App',
                color: AppUIConstants.primaryLight,
                onTap: _handleRateApp,
              ),
          ],
        ),
        SettingsGroup(
          title: 'Need help?',
          children: [
            SettingsTile(
              icon: Icons.email_outlined,
              title: 'Email support',
              subtitle: _supportEmail,
              color: AppUIConstants.secondary,
              onTap: () => launchUrl(Uri.parse('mailto:$_supportEmail')),
            ),
            SettingsTile(
              icon: Icons.phone_outlined,
              title: 'Call support',
              subtitle: _supportPhone,
              color: AppUIConstants.secondary,
              onTap: () => launchUrl(Uri.parse('tel:$_supportPhone')),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'PG Sathi - made for better PG living',
            style: AppUIConstants.caption,
          ),
        ),
      ],
    );
  }
}

/// Wrapper for admin login to ensure proper navigation.
class _AdminLoginWrapper extends StatelessWidget {
  const _AdminLoginWrapper();

  @override
  Widget build(BuildContext context) {
    return kIsWeb
        ? const WebContentConstraint(child: AdminLoginScreen())
        : const AdminLoginScreen();
  }
}

/// Security section with device management.
class _SecuritySection extends StatelessWidget {
  const _SecuritySection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      title: 'Security',
      children: [
        SettingsTile(
          icon: Icons.devices_rounded,
          title: 'Active Devices',
          subtitle: 'Manage devices with access to your account',
          color: AppUIConstants.primaryLight,
          onTap: () => _navigateToActiveDevices(context),
        ),
      ],
    );
  }

  void _navigateToActiveDevices(BuildContext context) async {
    // Get current device ID
    final deviceInfoService = sl<DeviceInfoService>();
    final deviceIdResult = await deviceInfoService.getDeviceId();
    final currentDeviceId = deviceIdResult.fold(
      (failure) => null,
      (deviceId) => deviceId,
    );

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<DeviceSessionsCubit>(),
            child: ActiveDevicesScreen(
              userId: userId,
              currentDeviceId: currentDeviceId,
            ),
          ),
        ),
      );
    }
  }
}
