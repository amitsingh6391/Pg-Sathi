import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/invoice_repository.dart';
import '../../../domain/repositories/membership_repository.dart';
import '../../../domain/repositories/payment_repository.dart';
import '../../../domain/repositories/user_repository.dart';

/// Cubit for admin library data management (like cleanup/delete).
class AdminLibraryManagementCubit extends Cubit<AdminLibraryManagementState> {
  AdminLibraryManagementCubit({
    required this.membershipRepository,
    required this.paymentRepository,
    required this.invoiceRepository,
    required this.userRepository,
  }) : super(const AdminLibraryManagementState());

  final MembershipRepository membershipRepository;
  final PaymentRepository paymentRepository;
  final InvoiceRepository invoiceRepository;
  final UserRepository userRepository;

  /// Deletes all data for a library (memberships, payments, invoices).
  /// Also deletes student user accounts that ONLY have membership in this library.
  /// Does NOT delete the library itself or the owner.
  /// NOTE: Students with memberships in other libraries are preserved.
  Future<void> deleteLibraryData(String libraryId) async {
    emit(state.copyWith(status: AdminLibraryManagementStatus.deleting));
    log('AdminLibraryManagementCubit: Starting delete for library $libraryId');

    try {
      var deletedMemberships = 0;
      var deletedInvoices = 0;
      var deletedPayments = 0;
      final affectedStudentIds = <String>{};

      // 1. Delete all memberships for this library
      log('AdminLibraryManagementCubit: Fetching memberships...');
      final membershipsResult = await membershipRepository
          .getMembershipsByLibraryId(libraryId);

      await membershipsResult.fold(
        (failure) async {
          log(
            'AdminLibraryManagementCubit: Failed to fetch memberships - ${failure.message}',
          );
        },
        (memberships) async {
          log(
            'AdminLibraryManagementCubit: Found ${memberships.length} memberships to delete',
          );

          // Track affected students
          for (final membership in memberships) {
            if (membership.userId != null) {
              affectedStudentIds.add(membership.userId!);
            }

            final deleteResult = await membershipRepository.deleteMembership(
              membership.id,
            );
            deleteResult.fold(
              (failure) => log(
                'AdminLibraryManagementCubit: Failed to delete membership ${membership.id}',
              ),
              (_) => deletedMemberships++,
            );
          }
          log(
            'AdminLibraryManagementCubit: Deleted $deletedMemberships memberships',
          );
          log(
            'AdminLibraryManagementCubit: Affected ${affectedStudentIds.length} student accounts (NOT deleted)',
          );
        },
      );

      // 2. Delete all payments for this library
      log('AdminLibraryManagementCubit: Fetching payments...');
      final paymentsResult = await paymentRepository.getPaymentsByLibraryId(
        libraryId,
      );

      await paymentsResult.fold(
        (failure) async {
          log(
            'AdminLibraryManagementCubit: Failed to fetch payments - ${failure.message}',
          );
        },
        (payments) async {
          log(
            'AdminLibraryManagementCubit: Found ${payments.length} payments to delete',
          );
          for (final payment in payments) {
            final deleteResult = await paymentRepository.deletePayment(
              payment.id,
            );
            deleteResult.fold(
              (failure) => log(
                'AdminLibraryManagementCubit: Failed to delete payment ${payment.id}',
              ),
              (_) => deletedPayments++,
            );
          }
          log('AdminLibraryManagementCubit: Deleted $deletedPayments payments');
        },
      );

      // 3. Delete all invoices for this library
      log(
        'AdminLibraryManagementCubit: Fetching invoices for library $libraryId...',
      );
      final invoicesResult = await invoiceRepository.getInvoicesForLibrary(
        libraryId,
      );

      await invoicesResult.fold(
        (failure) async {
          log(
            'AdminLibraryManagementCubit: ❌ Failed to fetch invoices - ${failure.message}',
          );
          log(
            'AdminLibraryManagementCubit: Error type: ${failure.runtimeType}',
          );
        },
        (invoices) async {
          log(
            'AdminLibraryManagementCubit: ✅ Found ${invoices.length} invoices to delete',
          );
          if (invoices.isEmpty) {
            log(
              'AdminLibraryManagementCubit: No invoices found for library $libraryId',
            );
          } else {
            for (final invoice in invoices) {
              log(
                'AdminLibraryManagementCubit: Deleting invoice ${invoice.id} (${invoice.invoiceNumber})...',
              );
              final deleteResult = await invoiceRepository.deleteInvoice(
                invoice.id,
              );
              deleteResult.fold(
                (failure) {
                  log(
                    'AdminLibraryManagementCubit: ❌ Failed to delete invoice ${invoice.id}: ${failure.message}',
                  );
                },
                (_) {
                  deletedInvoices++;
                  log(
                    'AdminLibraryManagementCubit: ✅ Deleted invoice ${invoice.id}',
                  );
                },
              );
            }
            log(
              'AdminLibraryManagementCubit: ✅ Successfully deleted $deletedInvoices out of ${invoices.length} invoices',
            );
          }
        },
      );

      // 4. Delete user accounts that only have membership in this library
      var deletedUsers = 0;
      var preservedUsers = 0;
      
      log(
        'AdminLibraryManagementCubit: Checking ${affectedStudentIds.length} students for deletion...',
      );
      
      for (final studentId in affectedStudentIds) {
        // Get all memberships for this student
        final studentMembershipsResult = await membershipRepository
            .getMembershipsByUserId(studentId);
        
        await studentMembershipsResult.fold(
          (failure) async {
            log(
              'AdminLibraryManagementCubit: Failed to check memberships for user $studentId',
            );
            preservedUsers++;
          },
          (studentMemberships) async {
            // Filter out memberships from the library we just deleted
            final otherLibraryMemberships = studentMemberships
                .where((m) => m.libraryId != libraryId)
                .toList();
            
            if (otherLibraryMemberships.isEmpty) {
              // Student only had membership in this library - delete the account
              log(
                'AdminLibraryManagementCubit: Deleting user $studentId (no other memberships)',
              );
              final deleteResult = await userRepository.deleteUser(studentId);
              deleteResult.fold(
                (failure) {
                  log(
                    'AdminLibraryManagementCubit: Failed to delete user $studentId: ${failure.message}',
                  );
                  preservedUsers++;
                },
                (_) => deletedUsers++,
              );
            } else {
              // Student has memberships in other libraries - preserve the account
              log(
                'AdminLibraryManagementCubit: Preserving user $studentId (has ${otherLibraryMemberships.length} other memberships)',
              );
              preservedUsers++;
            }
          },
        );
      }

      log('AdminLibraryManagementCubit: ✅ Delete complete!');
      log('  📊 Summary:');
      log('    - Memberships deleted: $deletedMemberships');
      log('    - Payments deleted: $deletedPayments');
      log('    - Invoices deleted: $deletedInvoices');
      log('    - Student accounts deleted: $deletedUsers');
      log('    - Student accounts preserved: $preservedUsers');

      emit(
        state.copyWith(
          status: AdminLibraryManagementStatus.success,
          successMessage:
              'Deleted $deletedMemberships memberships, $deletedPayments payments, $deletedInvoices invoices, and $deletedUsers user accounts. $preservedUsers users preserved (have other library memberships).',
        ),
      );
    } catch (e) {
      log('AdminLibraryManagementCubit: Delete error - $e');
      emit(
        state.copyWith(
          status: AdminLibraryManagementStatus.error,
          errorMessage: 'Failed to delete library data: $e',
        ),
      );
    }
  }

  /// Resets the state.
  void reset() {
    emit(const AdminLibraryManagementState());
  }
}

enum AdminLibraryManagementStatus { initial, deleting, success, error }

class AdminLibraryManagementState {
  const AdminLibraryManagementState({
    this.status = AdminLibraryManagementStatus.initial,
    this.successMessage,
    this.errorMessage,
  });

  final AdminLibraryManagementStatus status;
  final String? successMessage;
  final String? errorMessage;

  bool get isDeleting => status == AdminLibraryManagementStatus.deleting;
  bool get isSuccess => status == AdminLibraryManagementStatus.success;
  bool get isError => status == AdminLibraryManagementStatus.error;

  AdminLibraryManagementState copyWith({
    AdminLibraryManagementStatus? status,
    String? successMessage,
    String? errorMessage,
  }) {
    return AdminLibraryManagementState(
      status: status ?? this.status,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }
}
