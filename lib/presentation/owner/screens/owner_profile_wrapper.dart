import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../auth/cubit/phone_auth_cubit.dart';
import '../../auth/cubit/phone_auth_state.dart';
import '../../student/cubit/profile_cubit.dart';
import '../../student/screens/profile_screen.dart';

/// Wrapper to handle profile screen for owners in navigation.
class OwnerProfileWrapper extends StatelessWidget {
  const OwnerProfileWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PhoneAuthCubit, PhoneAuthState>(
      builder: (context, authState) {
        return authState.maybeWhen(
          authenticated: (user) => BlocProvider(
            create: (_) => sl<ProfileCubit>(),
            child: ProfileScreen(user: user),
          ),
          orElse: () => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }
}
