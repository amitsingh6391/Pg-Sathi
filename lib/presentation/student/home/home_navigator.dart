import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/usecases/get_student_memberships.dart';
import '../cubit/invoice_cubit.dart';
import '../cubit/student_payment_cubit.dart';
import '../screens/invoices_screen.dart';
import '../screens/library_details_screen.dart';
import '../screens/payment_screen.dart';
import '../screens/student_documents_screen.dart';

/// Navigation used by the home dashboard widgets (featured stay, quick
/// actions, past stays). PG counterpart of Library Manager's navigator,
/// limited to the stay-related destinations PG has.
class StudentHomeNavigator {
  const StudentHomeNavigator({required this.userId, required this.onRefresh});

  final String userId;

  /// Reloads the dashboard after flows that change membership state.
  final VoidCallback onRefresh;

  Future<void> payment(BuildContext context, StudentMembershipInfo info) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<StudentPaymentCubit>(),
          child: PaymentScreen(membershipInfo: info),
        ),
      ),
    );
    if (result == true) onRefresh();
  }

  void libraryDetails(BuildContext context, StudentMembershipInfo info) {
    if (info.library == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryDetailsScreen(
          library: info.library!,
          membershipInfo: info,
          userId: userId,
        ),
      ),
    );
  }

  Future<void> documents(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentDocumentsScreen(studentId: userId),
      ),
    );
    onRefresh();
  }

  void invoices(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<InvoiceCubit>(),
          child: InvoicesScreen(userId: userId),
        ),
      ),
    );
  }
}
