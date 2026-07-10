import '../../../domain/usecases/assign_membership.dart';
import '../../../domain/usecases/assign_membership_with_custom_slot.dart';
import '../../../domain/usecases/cancel_membership.dart';
import '../../../domain/usecases/create_slot.dart';
import '../../../domain/usecases/delete_slot.dart';
import '../../../domain/usecases/delete_invoice.dart';
import '../../../domain/usecases/delete_account.dart';
import '../../../domain/usecases/check_auth_status.dart';
import '../../../domain/usecases/check_in.dart';
import '../../../domain/usecases/check_out.dart';
import '../../../domain/usecases/check_version_update.dart';
import '../../../domain/usecases/create_library.dart';
import '../../../domain/usecases/deactivate_membership.dart';
import '../../../domain/usecases/expire_memberships.dart';
import '../../../domain/usecases/get_all_libraries.dart';
import '../../../domain/usecases/get_current_user.dart';
import '../../../domain/usecases/get_library_stats.dart';
import '../../../domain/usecases/get_occupied_seats.dart';
import '../../../domain/usecases/get_expired_seats.dart';
import '../../../domain/usecases/renew_membership.dart';
import '../../../domain/usecases/get_owner_library.dart';
import '../../../domain/usecases/get_slots_by_library.dart';
import '../../../domain/usecases/get_student_memberships.dart';
import '../../../domain/usecases/get_today_attendance.dart';
import '../../../domain/usecases/handle_payment_failure.dart';
import '../../../domain/usecases/reassign_seat.dart';
import '../../../domain/usecases/send_otp.dart';
import '../../../domain/usecases/sign_out.dart';
import '../../../domain/usecases/update_library.dart';
import '../../../domain/usecases/update_library_photos.dart';
import '../../../domain/usecases/delete_library_photo.dart';
import '../../../domain/usecases/upload_student_document.dart';
import '../../../domain/usecases/get_student_documents.dart';
import '../../../domain/usecases/approve_student_document.dart';
import '../../../domain/usecases/send_membership_expiry_reminder.dart';
import '../../../domain/usecases/send_payment_reminder.dart';
import '../../../domain/usecases/update_membership.dart';
import '../../../domain/usecases/update_owner_settings.dart';
import '../../../domain/usecases/update_slot.dart';
import '../../../domain/usecases/update_user_profile.dart';
import '../../../domain/usecases/validate_daily_presence.dart';
import '../../../domain/usecases/generate_invoice.dart';
import '../../../domain/usecases/get_attendance_history.dart';
import '../../../domain/usecases/get_attendance_stats.dart';
import '../../../domain/usecases/get_invoices_for_owner.dart';
import '../../../domain/usecases/get_invoices_for_student.dart';
import '../../../domain/usecases/approve_cash_payment.dart';
import '../../../domain/usecases/get_pending_cash_payments.dart';
import '../../../domain/usecases/initiate_cash_payment.dart';
import '../../../domain/usecases/initiate_upi_payment.dart';
import '../../../domain/usecases/mark_upi_as_paid.dart';
import '../../../domain/usecases/get_pending_approval_payments.dart';
import '../../../domain/usecases/reject_cash_payment.dart';
import '../../../domain/usecases/refund_payment.dart';
import '../../../domain/usecases/verify_otp.dart';
import '../../../domain/usecases/sync_memberships_on_login.dart';
import '../../../domain/usecases/mark_payment_received.dart';
import '../../../domain/usecases/send_whatsapp_invoice.dart';
import '../../../domain/usecases/notice_usecases.dart';
import '../../../domain/usecases/promo/promo_usecases.dart';
import '../../../domain/usecases/get_user_device_sessions.dart';
import '../../../domain/usecases/logout_device_session.dart';
import '../../../domain/usecases/logout_all_other_devices.dart';
import '../../../domain/usecases/get_expiring_trials.dart';
import '../../../domain/services/storage_service.dart' as domain_storage;

import 'package:get_it/get_it.dart';

void registerUseCases(GetIt sl) {
  // Auth use cases
  sl.registerLazySingleton(() => SendOtp(authRepository: sl()));
  sl.registerLazySingleton(() => VerifyOtp(authRepository: sl()));
  sl.registerLazySingleton(() => CheckAuthStatus(authRepository: sl()));
  sl.registerLazySingleton(
    () => CheckVersionUpdate(versionRepository: sl(), packageInfo: sl()),
  );
  sl.registerLazySingleton(() => SignOut(authRepository: sl()));
  sl.registerLazySingleton(() => DeleteAccount(authRepository: sl()));
  sl.registerLazySingleton(() => UpdateUserProfile(authRepository: sl()));
  sl.registerLazySingleton(() => GetCurrentUser(authRepository: sl()));
  sl.registerLazySingleton(() => UpdateOwnerSettings(userRepository: sl()));

  // Library use cases
  sl.registerLazySingleton(
    () => CreateLibrary(libraryRepository: sl(), seatRepository: sl()),
  );
  sl.registerLazySingleton(
    () => UpdateLibrary(libraryRepository: sl(), seatRepository: sl()),
  );
  sl.registerLazySingleton(() => GetOwnerLibrary(libraryRepository: sl()));
  sl.registerLazySingleton(
    () => GetLibraryStats(membershipRepository: sl(), slotRepository: sl()),
  );
  sl.registerLazySingleton(
    () => GetAllLibraries(libraryRepository: sl(), userRepository: sl()),
  );
  sl.registerLazySingleton(
    () => UpdateLibraryPhotos(
      libraryRepository: sl(),
      storageService: sl<domain_storage.StorageService>(),
    ),
  );
  sl.registerLazySingleton(
    () => DeleteLibraryPhoto(
      libraryRepository: sl(),
      storageService: sl<domain_storage.StorageService>(),
    ),
  );

  // Student document use cases
  sl.registerLazySingleton(() => UploadStudentDocument(repository: sl()));
  sl.registerLazySingleton(() => GetStudentDocuments(repository: sl()));
  sl.registerLazySingleton(() => ApproveStudentDocument(repository: sl()));

  // Slot use cases
  sl.registerLazySingleton(() => CreateSlot(slotRepository: sl()));
  sl.registerLazySingleton(() => UpdateSlot(slotRepository: sl()));
  sl.registerLazySingleton(
    () => DeleteSlot(slotRepository: sl(), membershipRepository: sl()),
  );
  sl.registerLazySingleton(() => GetSlotsByLibrary(slotRepository: sl()));

  // Membership use cases
  sl.registerLazySingleton(
    () => GetStudentMemberships(
      membershipRepository: sl(),
      libraryRepository: sl(),
      slotRepository: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => AssignMembership(membershipRepository: sl(), userRepository: sl()),
  );

  sl.registerLazySingleton(
    () => AssignMembershipWithCustomSlot(
      membershipRepository: sl(),
      slotRepository: sl(),
      userRepository: sl(),
      libraryRepository: sl(),
      paymentRepository: sl(),
      seatRepository: sl(),
      generateInvoice: sl(),
      notificationService: sl(),
      whatsAppNotificationRepository: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => UpdateMembership(
      membershipRepository: sl(),
      invoiceRepository: sl(),
      slotRepository: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => GetOccupiedSeats(membershipRepository: sl(), userRepository: sl()),
  );

  sl.registerLazySingleton(
    () => GetExpiredSeats(membershipRepository: sl(), userRepository: sl()),
  );

  sl.registerLazySingleton(
    () => RenewMembership(
      membershipRepository: sl(),
      paymentRepository: sl(),
      libraryRepository: sl(),
      slotRepository: sl(),
      seatRepository: sl(),
      analyticsService: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => ReassignSeat(
      membershipRepository: sl(),
      libraryRepository: sl(),
      seatRepository: sl(),
      slotRepository: sl(),
      analyticsService: sl(),
      notificationService: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => DeactivateMembership(membershipRepository: sl()),
  );

  sl.registerLazySingleton(() => CancelMembership(membershipRepository: sl()));

  sl.registerLazySingleton(() => ExpireMemberships(membershipRepository: sl()));

  // New use cases for phone-based assignment
  sl.registerLazySingleton(
    () => SyncMembershipsOnLogin(
      membershipRepository: sl(),
      invoiceRepository: sl(),
      documentRepository: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => MarkPaymentReceived(
      membershipRepository: sl(),
      paymentRepository: sl(),
      generateInvoice: sl(),
      whatsAppNotificationRepository: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => HandlePaymentFailure(
      paymentRepository: sl(),
      membershipRepository: sl(),
      analyticsService: sl(),
    ),
  );

  // Cash payment use cases
  sl.registerLazySingleton(
    () => InitiateCashPayment(
      paymentRepository: sl(),
      membershipRepository: sl(),
      libraryRepository: sl(),
      userRepository: sl(),
      notificationService: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => ApproveCashPayment(
      paymentRepository: sl(),
      membershipRepository: sl(),
      libraryRepository: sl(),
      generateInvoice: sl(),
      notificationService: sl(),
      whatsAppNotificationRepository: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => SendWhatsAppInvoice(
      whatsAppNotificationRepository: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => RejectCashPayment(
      paymentRepository: sl(),
      membershipRepository: sl(),
      libraryRepository: sl(),
      notificationService: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => RefundPayment(
      paymentRepository: sl(),
      membershipRepository: sl(),
      invoiceRepository: sl(),
      analyticsService: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => GetPendingCashPayments(
      paymentRepository: sl(),
      membershipRepository: sl(),
      userRepository: sl(),
    ),
  );

  // UPI payment use cases
  sl.registerLazySingleton(
    () => InitiateUpiPayment(
      paymentRepository: sl(),
      membershipRepository: sl(),
      libraryRepository: sl(),
      userRepository: sl(),
      notificationService: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => MarkUpiAsPaid(
      paymentRepository: sl(),
      membershipRepository: sl(),
      libraryRepository: sl(),
      userRepository: sl(),
      notificationService: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => GetPendingApprovalPayments(
      paymentRepository: sl(),
      membershipRepository: sl(),
      userRepository: sl(),
    ),
  );

  // Presence use cases
  sl.registerLazySingleton(
    () => ValidateDailyPresence(
      presenceRepository: sl(),
      membershipRepository: sl(),
    ),
  );

  // Attendance use cases
  sl.registerLazySingleton(
    () => CheckIn(
      attendanceRepository: sl(),
      membershipRepository: sl(),
      libraryRepository: sl(),
      locationService: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => CheckOut(
      attendanceRepository: sl(),
      libraryRepository: sl(),
      locationService: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => GetTodayAttendance(attendanceRepository: sl()),
  );

  sl.registerLazySingleton(
    () => GetAttendanceHistory(attendanceRepository: sl()),
  );

  sl.registerLazySingleton(
    () => GetAttendanceStats(attendanceRepository: sl()),
  );

  // Invoice use cases
  sl.registerLazySingleton(
    () => GenerateInvoice(
      invoiceRepository: sl(),
      membershipRepository: sl(),
      libraryRepository: sl(),
      userRepository: sl(),
      slotRepository: sl(),
      analyticsService: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => GetInvoicesForStudent(
      invoiceRepository: sl(),
      membershipRepository: sl(),
    ),
  );

  sl.registerLazySingleton(() => GetInvoicesForOwner(invoiceRepository: sl()));

  sl.registerLazySingleton(
    () => DeleteInvoice(invoiceRepository: sl(), paymentRepository: sl()),
  );

  // Reminder use cases
  sl.registerLazySingleton(
    () => SendMembershipExpiryReminder(
      membershipRepository: sl(),
      notificationRepository: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => SendPaymentReminder(
      membershipRepository: sl(),
      notificationRepository: sl(),
    ),
  );

  // Notice use cases
  sl.registerLazySingleton(() => CreateNotice(sl()));
  sl.registerLazySingleton(() => UpdateNotice(sl()));
  sl.registerLazySingleton(() => DeleteNotice(sl()));
  sl.registerLazySingleton(() => PublishNotice(sl()));
  sl.registerLazySingleton(() => GetNoticesByLibrary(sl()));
  sl.registerLazySingleton(() => GetActiveNoticesForStudent(sl()));
  sl.registerLazySingleton(() => MarkNoticeAsRead(sl()));
  sl.registerLazySingleton(() => GetReadStatusForStudent(sl()));
  sl.registerLazySingleton(() => GetNoticeById(sl()));
  sl.registerLazySingleton(() => IncrementNoticeViewCount(sl()));
  sl.registerLazySingleton(() => GetNoticeAnalytics(sl()));

  // Device session use cases
  sl.registerLazySingleton(() => GetUserDeviceSessions(sl()));
  sl.registerLazySingleton(() => LogoutDeviceSession(sl()));
  sl.registerLazySingleton(() => LogoutAllOtherDevices(sl()));

  // Promo use cases
  sl.registerLazySingleton(() => GetActivePromo(sl()));
  sl.registerLazySingleton(() => GetActivePromoForStudent(sl()));
  sl.registerLazySingleton(() => RecordPromoInteraction(sl()));
  sl.registerLazySingleton(() => GetAllPromos(sl()));
  sl.registerLazySingleton(() => CreatePromo(sl()));
  sl.registerLazySingleton(() => UpdatePromo(sl()));
  sl.registerLazySingleton(() => DeletePromo(sl()));
  sl.registerLazySingleton(() => GetPromoAnalytics(sl()));

  // Admin use cases
  sl.registerLazySingleton(
    () => GetExpiringTrials(
      libraryRepository: sl(),
      subscriptionRepository: sl(),
      userRepository: sl(),
    ),
  );
}
