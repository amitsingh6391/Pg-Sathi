import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unicons/unicons.dart';

import '../../../core/di/injection_container.dart';
import '../../../data/services/app_rating_service.dart';
import '../../../data/services/device_info_service.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/get_owner_library.dart';
import '../../admin/screens/admin_login_screen.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/web_content_constraint.dart';
import '../../owner/cubit/device_sessions_cubit.dart';
import '../../owner/cubit/owner_settings_cubit.dart';
import '../../owner/cubit/owner_settings_state.dart';
import '../../auth/cubit/phone_auth_cubit.dart';
import '../../auth/cubit/phone_auth_state.dart';
import '../../owner/screens/active_devices_screen.dart';
import '../../owner/screens/library_form_screen.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import '../widgets/profile_widgets.dart';
import 'profile_form_screen.dart';

/// Screen for viewing and editing user profile.
/// Premium, modern design with smooth animations.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.user});

  final User user;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Library? _library;
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    // Initialize ProfileCubit with user data (including avatar URL)
    if (mounted) {
      final profileCubit = context.read<ProfileCubit>();
      profileCubit.loadUser(_currentUser);
    }

    // Load library for owners
    if (_currentUser.role == UserRole.owner) {
      _loadLibrary();
    }
  }

  Future<void> _loadLibrary() async {
    final getOwnerLibrary = sl<GetOwnerLibrary>();
    final result = await getOwnerLibrary(
      GetOwnerLibraryParams(ownerId: _currentUser.id),
    );
    result.fold(
      (_) {},
      (library) => setState(() {
        _library = library;
      }),
    );
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with gradient
          SliverAppBar(
            expandedHeight: 240,
            floating: false,
            pinned: true,
            backgroundColor: AppUIConstants.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppUIConstants.primary,
                      AppUIConstants.primary.withValues(alpha: 0.85),
                      AppUIConstants.primaryLight,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      GestureDetector(
                        onTap: _currentUser.role == UserRole.owner
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => LibraryFormScreen(
                                      ownerId: _currentUser.id,
                                      ownerPhone: _currentUser.phone,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: BlocBuilder<ProfileCubit, ProfileState>(
                          builder: (context, state) => _AnimatedAvatar(
                            user: _currentUser,
                            avatarUrl: state.avatarUrl,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _currentUser.role == UserRole.owner && _library != null
                            ? _library!.name
                            : _currentUser.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _ProfileStatusBadge(
                        isComplete: _currentUser.isProfileComplete,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: _currentUser.role == UserRole.owner
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => LibraryFormScreen(
                              ownerId: _currentUser.id,
                              ownerPhone: _currentUser.phone,
                            ),
                          ),
                        );
                      }
                    : () => _navigateToEdit(context),
                tooltip: _currentUser.role == UserRole.owner
                    ? 'Edit Library Details'
                    : 'Edit Profile',
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Profile Completion Card (if incomplete)
                        if (!_currentUser.isProfileComplete)
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 400),
                            tween: Tween(begin: 0, end: 1),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: ProfileCompletionCard(
                              onComplete: () => _navigateToEdit(context),
                            ),
                          ),
                        if (!_currentUser.isProfileComplete)
                          const SizedBox(height: 20),

                        // Personal Information Card
                        InkWell(
                          onTap: () => _navigateToEdit(context),
                          borderRadius: BorderRadius.circular(20),
                          child: _SectionCard(
                            title: 'Personal Information',
                            icon: UniconsLine.user_circle,
                            delay: 100,
                            actionButton: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                            children: [
                              _InfoTile(
                                icon: Icons.badge_rounded,
                                label: 'Full Name',
                                value: _currentUser.isProfileComplete
                                    ? _currentUser.name
                                    : 'Not set',
                                valueColor: _currentUser.isProfileComplete
                                    ? null
                                    : Colors.grey,
                              ),
                              _InfoTile(
                                icon: Icons.phone_rounded,
                                label: 'Phone Number',
                                value: _currentUser.phone,
                                showDivider:
                                    _currentUser.email != null ||
                                    (_currentUser.role != UserRole.owner &&
                                        _currentUser.examPreparingFor != null),
                              ),
                              if (_currentUser.email != null)
                                _InfoTile(
                                  icon: Icons.email_rounded,
                                  label: 'Email',
                                  value: _currentUser.email!,
                                  showDivider:
                                      _currentUser.role != UserRole.owner,
                                ),
                              // Student-only fields
                              if (_currentUser.role != UserRole.owner) ...[
                                if (_currentUser.examPreparingFor != null)
                                  _InfoTile(
                                    icon: Icons.school_rounded,
                                    label: 'Exam Preparing For',
                                    value: _currentUser.examPreparingFor!,
                                  ),
                                _InfoTile(
                                  icon: Icons.credit_card_rounded,
                                  label: 'Access Card Issued',
                                  value: _currentUser.isAccessCardIssued
                                      ? 'Yes'
                                      : 'No',
                                  valueColor: _currentUser.isAccessCardIssued
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                if (_currentUser.address != null)
                                  _InfoTile(
                                    icon: Icons.location_on_rounded,
                                    label: 'Address',
                                    value: _currentUser.address!,
                                  ),
                                if (_currentUser.gender != null)
                                  _InfoTile(
                                    icon: Icons.person_outline_rounded,
                                    label: 'Gender',
                                    value: _currentUser.gender!,
                                    showDivider: false,
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Account Information Card
                        _SectionCard(
                          title: 'Account Details',
                          icon: Icons.security_rounded,
                          delay: 200,
                          children: [
                            _InfoTile(
                              icon: Icons.workspace_premium_rounded,
                              label: 'Account Type',
                              value: _currentUser.role.name.toUpperCase(),
                              valueWidget: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFF8B5CF6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _currentUser.role.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            _InfoTile(
                              icon: Icons.verified_rounded,
                              label: 'Phone Verified',
                              value: _currentUser.isPhoneVerified
                                  ? 'Verified'
                                  : 'Not Verified',
                              valueWidget: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _currentUser.isPhoneVerified
                                      ? const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.1)
                                      : Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _currentUser.isPhoneVerified
                                        ? const Color(0xFF10B981)
                                        : Colors.orange,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _currentUser.isPhoneVerified
                                          ? Icons.check_circle_rounded
                                          : Icons.warning_rounded,
                                      size: 14,
                                      color: _currentUser.isPhoneVerified
                                          ? const Color(0xFF10B981)
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _currentUser.isPhoneVerified
                                          ? 'Verified'
                                          : 'Pending',
                                      style: TextStyle(
                                        color: _currentUser.isPhoneVerified
                                            ? const Color(0xFF10B981)
                                            : Colors.orange,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              showDivider: _currentUser.createdAt != null,
                            ),
                            if (_currentUser.createdAt != null)
                              _InfoTile(
                                icon: Icons.calendar_today_rounded,
                                label: 'Member Since',
                                value: DateFormat(
                                  'MMMM dd, yyyy',
                                ).format(_currentUser.createdAt!),
                                showDivider: false,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Owner Settings (only for owners)
                        if (_currentUser.role == UserRole.owner)
                          BlocProvider(
                            create: (_) {
                              final cubit = sl<OwnerSettingsCubit>();
                              cubit.loadSettings(_currentUser);
                              return cubit;
                            },
                            child: _OwnerSettingsSection(),
                          ),
                        if (_currentUser.role == UserRole.owner)
                          const SizedBox(height: 16),

                        // Security Section
                        _SecuritySection(userId: _currentUser.id),
                        const SizedBox(height: 16),

                        const _AccountDeletionSection(),
                        const SizedBox(height: 16),

                        const SizedBox(height: 24),
                        // App Info Section
                        _AppInfoSection(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
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

class _AnimatedAvatar extends StatelessWidget {
  const _AnimatedAvatar({required this.user, this.avatarUrl});

  final User user;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.5 + (0.5 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 45,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _ProfileStatusBadge extends StatelessWidget {
  const _ProfileStatusBadge({required this.isComplete});

  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isComplete
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.amber.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComplete ? Icons.check_circle_rounded : Icons.info_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            isComplete ? 'Profile Complete' : 'Profile Incomplete',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.delay = 0,
    this.actionButton,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final int delay;
  final Widget? actionButton;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + delay),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppUIConstants.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: AppUIConstants.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (actionButton != null) actionButton!,
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            ...children,
          ],
        ),
      ),
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
        return Column(
          children: [
            _SectionCard(
              title: 'Visibility Settings',
              icon: Icons.visibility_rounded,
              delay: 300,
              children: [
                _OwnerSettingsSwitchTile(
                  icon: Icons.library_books_rounded,
                  title: 'Allow students to see library listing',
                  subtitle: 'Students can explore other libraries',
                  value: state.showOtherLibraries,
                  onChanged: isSaving
                      ? null
                      : (value) => context
                            .read<OwnerSettingsCubit>()
                            .updateShowOtherLibraries(value),
                ),
                Divider(height: 1, indent: 54, color: Colors.grey.shade100),
                _OwnerSettingsSwitchTile(
                  icon: Icons.store_rounded,
                  title: 'Show my library in marketplace',
                  subtitle: 'Your PG appears in tenant listings',
                  value: state.showMyLibraryInListing,
                  onChanged: isSaving
                      ? null
                      : (value) => context
                            .read<OwnerSettingsCubit>()
                            .updateShowMyLibraryInListing(value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'WhatsApp Automation',
              icon: Icons.chat_rounded,
              delay: 340,
              children: [
                _OwnerSettingsSwitchTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'Auto-send invoices',
                  subtitle: 'Send invoice PDF on WhatsApp after payment',
                  value: state.autoWhatsAppInvoicesEnabled,
                  onChanged: isSaving
                      ? null
                      : (value) => context
                            .read<OwnerSettingsCubit>()
                            .updateAutoWhatsAppInvoices(value),
                ),
                Divider(height: 1, indent: 54, color: Colors.grey.shade100),
                _OwnerSettingsSwitchTile(
                  icon: Icons.notifications_active_rounded,
                  title: 'Auto-send payment reminders',
                  subtitle: 'Send fee reminders on WhatsApp automatically',
                  value: state.autoWhatsAppFeeRemindersEnabled,
                  onChanged: isSaving
                      ? null
                      : (value) => context
                            .read<OwnerSettingsCubit>()
                            .updateAutoWhatsAppFeeReminders(value),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _OwnerSettingsSwitchTile extends StatelessWidget {
  const _OwnerSettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWidget,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? valueWidget;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade500),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (valueWidget != null)
                      valueWidget!
                    else
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: valueColor ?? Colors.grey.shade800,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, indent: 54, color: Colors.grey.shade100),
      ],
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This permanently deletes your account and signs you out. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

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
          backgroundColor: Colors.red,
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
    return _SectionCard(
      title: 'Account',
      icon: Icons.manage_accounts_rounded,
      delay: 375,
      children: [
        InkWell(
          onTap: _isDeleting ? null : _confirmDeleteAccount,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.delete_forever_rounded,
                  size: 20,
                  color: Colors.red.shade600,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete Account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Permanently remove your account from PG Sathi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isDeleting)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
              ],
            ),
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

    return _SectionCard(
      title: 'App Information',
      icon: Icons.info_outline_rounded,
      delay: 400,
      children: [
        // App Version - tap 7 times for admin access
        GestureDetector(
          onTap: _handleVersionTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.phone_android_rounded,
                  size: 20,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Version',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        version,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, indent: 54, color: Colors.grey.shade100),
        // Privacy Policy
        InkWell(
          onTap: () => context.push('/privacy-policy'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  size: 20,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, indent: 54, color: Colors.grey.shade100),
        // Terms of Service
        InkWell(
          onTap: () => context.push('/terms-of-service'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Terms of Service',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, indent: 54, color: Colors.grey.shade100),
        // Rate Our App (mobile only)
        if (!kIsWeb)
          InkWell(
            onTap: _handleRateApp,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.star_rate_rounded,
                    size: 20,
                    color: Colors.amber.shade600,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Rate Our App',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        if (!kIsWeb)
          Divider(height: 1, indent: 54, color: Colors.grey.shade100),
        // Support & Contact
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.support_agent_rounded,
                    size: 20,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Support & Contact',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'support@pgsathi.in',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '9548582776',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
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
    return _SectionCard(
      title: 'Security',
      icon: Icons.security_rounded,
      delay: 350,
      children: [
        InkWell(
          onTap: () => _navigateToActiveDevices(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.devices_rounded,
                  size: 20,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Devices',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage devices with access to your account',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
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
