import 'package:get_it/get_it.dart';

import '../../../presentation/auth/cubit/phone_auth_cubit.dart';
import '../../../presentation/owner/bloc/owner_library_bloc.dart';
import '../../../presentation/owner/cubit/library_form_cubit.dart';
import '../../../presentation/owner/cubit/membership_assignment_cubit.dart';
import '../../../presentation/owner/cubit/occupied_seats_cubit.dart';
import '../../../presentation/owner/cubit/expiry_reminder_cubit.dart';
import '../../../presentation/owner/cubit/whatsapp_reminder_cubit.dart';
import '../../../presentation/owner/cubit/referral_cubit.dart';
import '../../../presentation/owner/cubit/subscription_cubit.dart';
import '../../../presentation/owner/cubit/owner_settings_cubit.dart';
import '../../../presentation/owner/cubit/cash_approval_cubit.dart';
import '../../../presentation/owner/cubit/owner_invoice_cubit.dart';
import '../../../presentation/owner/cubit/revenue_analytics_cubit.dart';
import '../../../presentation/owner/cubit/expense_cubit.dart';
import '../../../presentation/owner/cubit/refund_cubit.dart';
import '../../../presentation/owner/cubit/slot_management_cubit.dart';
import '../../../presentation/owner/cubit/library_photos_cubit.dart';
import '../../../presentation/owner/cubit/student_details_cubit.dart';
import '../../../presentation/owner/cubit/bulk_import_cubit.dart';
import '../../../presentation/student/cubit/attendance_cubit.dart';
import '../../../presentation/student/cubit/attendance_history_cubit.dart';
import '../../../presentation/student/cubit/explore_libraries_cubit.dart';
import '../../../presentation/student/cubit/invoice_cubit.dart';
import '../../../presentation/student/cubit/library_details_cubit.dart';
import '../../../presentation/student/cubit/profile_cubit.dart';
import '../../../presentation/student/cubit/student_home_cubit.dart';
import '../../../presentation/student/cubit/student_payment_cubit.dart';
import '../../../presentation/student/cubit/student_documents_cubit.dart';
import '../../../presentation/owner/cubit/device_sessions_cubit.dart';
import '../../../presentation/core/cubit/notification_permission_cubit.dart';
import '../../../presentation/core/cubit/version_check_cubit.dart';
import '../../../presentation/admin/cubit/admin_cubit.dart';
import '../../../presentation/admin/cubit/withdrawal_approval_cubit.dart';
import '../../../presentation/admin/cubit/admin_analytics_cubit.dart';
import '../../../presentation/admin/cubit/feature_analytics_cubit.dart';
import '../../../presentation/admin/cubit/activity_drill_down_cubit.dart';
import '../../../presentation/admin/cubit/admin_library_management_cubit.dart';
import '../../../presentation/admin/cubit/admin_invoices_cubit.dart';
import '../../../presentation/admin/cubit/admin_intelligence_cubit.dart';
import '../../../presentation/owner/cubit/owner_notice_cubit.dart';
import '../../../presentation/student/cubit/student_notice_cubit.dart';
import '../../../domain/repositories/admin_intelligence_repository.dart';
import '../../../data/repositories/admin_intelligence_repository_impl.dart';
import '../../../domain/usecases/admin_intelligence/admin_intelligence_usecases.dart';
import '../../../domain/repositories/analytics_dashboard_repository.dart';
import '../../../domain/usecases/approve_subscription.dart';
import '../../../domain/usecases/auto_approve_razorpay_subscription.dart';
import '../../../domain/usecases/calculate_subscription_price.dart';
import '../../../domain/usecases/create_coupon.dart';
import '../../../domain/usecases/create_subscription.dart';
import '../../../domain/usecases/delete_subscription.dart';
import '../../../domain/usecases/get_admin_dashboard_data.dart';
import '../../../domain/usecases/get_admin_invoices.dart';
import '../../../domain/usecases/get_admin_user_activity.dart';
import '../../../domain/usecases/get_all_coupons.dart';
import '../../../domain/usecases/get_all_subscriptions.dart';
import '../../../domain/usecases/get_hourly_active_users.dart';
import '../../../domain/usecases/get_owner_subscription.dart';
import '../../../domain/usecases/get_pending_subscriptions.dart';
import '../../../domain/usecases/get_revenue_analytics.dart';
import '../../../domain/usecases/get_user_activity_details.dart';
import '../../../domain/usecases/mark_subscription_paid.dart';
import '../../../domain/usecases/reject_subscription.dart';
import '../../../domain/usecases/send_admin_broadcast_notification.dart';
import '../../../domain/usecases/start_owner_trial.dart';
import '../../../domain/usecases/validate_coupon.dart';
import '../../../domain/usecases/referral/referral_usecases.dart';
import '../../../domain/usecases/validate_seat_limit.dart';
import '../../../domain/services/location_service.dart';
import '../../../domain/services/storage_service.dart' as domain_storage;

void registerBlocsAndFeatureModules(GetIt sl) {
  // Factory: creates new instance each time for fresh state on navigation

  sl.registerFactory(
    () => PhoneAuthCubit(
      sendOtpUseCase: sl(),
      verifyOtpUseCase: sl(),
      checkAuthStatusUseCase: sl(),
      signOutUseCase: sl(),
      deleteAccountUseCase: sl(),
      authRepository: sl(),
      analyticsService: sl(),
    ),
  );

  sl.registerFactory(
    () => StudentHomeCubit(
      getStudentMemberships: sl(),
      validateDailyPresence: sl(),
      syncMembershipsOnLogin: sl(),
      membershipRepository: sl(),
      authRepository: sl(),
      userRepository: sl(),
      getStudentDocuments: sl(),
    ),
  );

  sl.registerFactory(
    () => StudentPaymentCubit(
      handlePaymentFailure: sl(),
      initiateCashPayment: sl(),
      initiateUpiPayment: sl(),
      markUpiAsPaid: sl(),
      paymentRepository: sl(),
      renewMembershipUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => ProfileCubit(
      updateUserProfile: sl(),
      storageService: sl<domain_storage.StorageService>(),
    ),
  );

  sl.registerFactory(
    () => OwnerLibraryBloc(
      getOwnerLibrary: sl(),
      getLibraryStats: sl(),
      createLibrary: sl(),
      updateLibrary: sl(),
    ),
  );

  sl.registerFactory(
    () => MembershipAssignmentCubit(
      assignMembership: sl(),
      assignMembershipWithCustomSlot: sl(),
      updateMembership: sl(),
      membershipRepository: sl(),
      getSlotsByLibrary: sl(),
      analyticsService: sl(),
      validateSeatLimit: sl(),
    ),
  );

  sl.registerFactory(
    () => OccupiedSeatsCubit(
      getOccupiedSeats: sl(),
      getExpiredSeats: sl(),
      reassignSeat: sl(),
      deactivateMembership: sl(),
      cancelMembership: sl(),
      updateMembership: sl(),
      memberExportService: sl(),
    ),
  );

  // Owner library form
  sl.registerFactory(
    () => LibraryFormCubit(
      getOwnerLibrary: sl(),
      createLibrary: sl(),
      updateLibrary: sl(),
      getSlotsByLibrary: sl(),
      draftService: sl(),
    ),
  );

  // Owner library photos
  sl.registerFactory(
    () =>
        LibraryPhotosCubit(updateLibraryPhotos: sl(), deleteLibraryPhoto: sl()),
  );

  // Student documents
  sl.registerFactory(
    () => StudentDocumentsCubit(
      uploadDocument: sl(),
      getDocuments: sl(),
      repository: sl(),
    ),
  );

  // Owner student details view
  sl.registerFactory(
    () => StudentDetailsCubit(
      getAttendanceHistory: sl(),
      getInvoicesForStudent: sl(),
      getStudentDocuments: sl(),
      uploadDocument: sl(),
      repository: sl(),
      userRepository: sl(),
      invoiceRepository: sl(),
    ),
  );

  // Bulk import
  sl.registerFactory(
    () => BulkImportCubit(
      userRepository: sl(),
      membershipRepository: sl(),
      seatRepository: sl(),
      slotRepository: sl(),
      paymentRepository: sl(),
      invoiceRepository: sl(),
      libraryRepository: sl(),
      generateInvoice: sl(),
      analyticsService: sl(),
    ),
  );

  // Student explore libraries
  sl.registerFactory(
    () => ExploreLibrariesCubit(
      getAllLibraries: sl(),
      locationService: sl<LocationService>(),
    ),
  );

  // Student library details
  sl.registerFactory(
    () => LibraryDetailsCubit(
      libraryRepository: sl(),
      membershipRepository: sl(),
      getSlotsByLibrary: sl(),
    ),
  );

  // Student attendance
  sl.registerFactory(
    () => AttendanceCubit(
      checkInUseCase: sl(),
      checkOutUseCase: sl(),
      getTodayAttendanceUseCase: sl(),
    ),
  );

  // Student attendance history
  sl.registerFactory(
    () => AttendanceHistoryCubit(
      getAttendanceHistoryUseCase: sl(),
      getAttendanceStatsUseCase: sl(),
    ),
  );

  // Student invoices
  sl.registerFactory(
    () => InvoiceCubit(
      getInvoicesForStudent: sl(),
      pdfService: sl(),
      deleteInvoice: sl(),
      analyticsService: sl(),
    ),
  );

  // Owner invoices
  sl.registerFactory(
    () => OwnerInvoiceCubit(
      getInvoicesForOwner: sl(),
      pdfService: sl(),
      deleteInvoice: sl(),
    ),
  );

  // Owner payment approvals (cash + UPI)
  sl.registerFactory(
    () => CashApprovalCubit(
      getPendingCashPayments: sl(),
      getPendingApprovalPayments: sl(),
      approveCashPayment: sl(),
      rejectCashPayment: sl(),
    ),
  );

  // Refund cubit
  sl.registerFactory(() => RefundCubit(refundPayment: sl()));

  // Revenue Analytics
  sl.registerLazySingleton(() => GetRevenueAnalytics(paymentRepository: sl()));

  // Subscription use cases
  sl.registerLazySingleton(() => const CalculateSubscriptionPrice());
  sl.registerLazySingleton(
    () => GetOwnerSubscription(subscriptionRepository: sl()),
  );
  sl.registerLazySingleton(
    () => CreateSubscription(
      subscriptionRepository: sl(),
      referralRepository: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => MarkSubscriptionPaid(subscriptionRepository: sl()),
  );
  sl.registerLazySingleton(
    () => ApproveSubscription(
      subscriptionRepository: sl(),
      referralRepository: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => AutoApproveRazorpaySubscription(
      subscriptionRepository: sl(),
      referralRepository: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => RejectSubscription(
      subscriptionRepository: sl(),
      analyticsService: sl(),
    ),
  );
  sl.registerLazySingleton(() => DeleteSubscription(sl()));
  sl.registerLazySingleton(() => ValidateCoupon(subscriptionRepository: sl()));
  sl.registerLazySingleton(
    () => GetPendingSubscriptions(subscriptionRepository: sl()),
  );
  sl.registerLazySingleton(
    () => GetAllSubscriptions(subscriptionRepository: sl()),
  );
  sl.registerLazySingleton(() => GetAllCoupons(subscriptionRepository: sl()));
  sl.registerLazySingleton(() => CreateCoupon(subscriptionRepository: sl()));
  sl.registerLazySingleton(() => StartOwnerTrial(subscriptionRepository: sl()));
  sl.registerLazySingleton(
    () => ValidateSeatLimit(
      subscriptionRepository: sl(),
      libraryRepository: sl(),
      membershipRepository: sl(),
    ),
  );

  sl.registerFactory(() => RevenueAnalyticsCubit(getRevenueAnalytics: sl()));
  sl.registerFactory(() => ExpenseCubit(expenseRepository: sl()));

  // Subscription cubit
  sl.registerFactory(
    () => SubscriptionCubit(
      getOwnerSubscription: sl(),
      calculateSubscriptionPrice: sl(),
      createSubscription: sl(),
      markSubscriptionPaid: sl(),
      autoApproveRazorpaySubscription: sl(),
      startOwnerTrial: sl(),
      validateCoupon: sl(),
      validateReferralCode: sl(),
      subscriptionNotificationService: sl(),
      analyticsService: sl(),
    ),
  );

  // Referral use cases
  sl.registerLazySingleton(
    () => CreateReferralCode(
      referralRepository: sl(),
      subscriptionRepository: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => ValidateReferralCode(
      referralRepository: sl(),
      subscriptionRepository: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetReferralStats(referralRepository: sl()));
  sl.registerLazySingleton(
    () => ClaimReferralReward(
      referralRepository: sl(),
      subscriptionRepository: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => RequestWalletWithdrawal(referralRepository: sl()),
  );
  sl.registerLazySingleton(
    () => GetPendingWithdrawals(referralRepository: sl()),
  );
  sl.registerLazySingleton(() => ApproveWithdrawal(referralRepository: sl()));
  sl.registerLazySingleton(() => RejectWithdrawal(referralRepository: sl()));

  // Referral cubit
  sl.registerFactory(
    () => ReferralCubit(
      createReferralCode: sl(),
      getReferralStats: sl(),
      claimReferralReward: sl(),
      requestWalletWithdrawal: sl(),
      notificationService: sl(),
    ),
  );

  // Withdrawal approval cubit (admin)
  sl.registerFactory(
    () => WithdrawalApprovalCubit(
      getPendingWithdrawals: sl(),
      approveWithdrawal: sl(),
      rejectWithdrawal: sl(),
      notificationService: sl(),
    ),
  );

  // Admin cubit
  sl.registerFactory(
    () => AdminCubit(
      getPendingSubscriptionsUseCase: sl(),
      getAllSubscriptionsUseCase: sl(),
      approveSubscriptionUseCase: sl(),
      rejectSubscriptionUseCase: sl(),
      deleteSubscriptionUseCase: sl(),
      getAllCouponsUseCase: sl(),
      createCouponUseCase: sl(),
      subscriptionNotificationService: sl(),
    ),
  );

  // Admin analytics use cases
  sl.registerLazySingleton(() => GetAdminDashboardData(repository: sl()));
  sl.registerLazySingleton(() => GetAdminUserActivity(repository: sl()));
  sl.registerLazySingleton(() => GetAdminInvoices(repository: sl()));
  sl.registerLazySingleton(
    () => SendAdminBroadcastNotification(
      analyticsRepository: sl(),
      notificationRepository: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetHourlyActiveUsers(sl()));
  sl.registerLazySingleton(() => GetUserActivityDetails(sl()));

  // Admin analytics cubit
  sl.registerFactory(
    () => AdminAnalyticsCubit(
      getAdminDashboardData: sl(),
      getAdminUserActivity: sl(),
      sendAdminBroadcastNotification: sl(),
    ),
  );

  // Feature analytics cubit
  sl.registerFactory(
    () => FeatureAnalyticsCubit(sl<AnalyticsDashboardRepository>()),
  );

  // Activity drill-down cubit
  sl.registerFactory(
    () => ActivityDrillDownCubit(
      getHourlyActiveUsers: sl(),
      getUserActivityDetails: sl(),
    ),
  );

  // Admin library management cubit
  sl.registerFactory(
    () => AdminLibraryManagementCubit(
      membershipRepository: sl(),
      paymentRepository: sl(),
      invoiceRepository: sl(),
      userRepository: sl(),
    ),
  );

  // Admin invoices cubit
  sl.registerFactory(() => AdminInvoicesCubit(getAdminInvoices: sl()));

  // Owner settings
  sl.registerFactory(() => OwnerSettingsCubit(updateOwnerSettings: sl()));

  // Device sessions
  sl.registerFactory(
    () => DeviceSessionsCubit(
      getUserDeviceSessions: sl(),
      logoutDeviceSession: sl(),
      logoutAllOtherDevices: sl(),
    ),
  );

  // Expiry reminder
  sl.registerFactory(
    () => ExpiryReminderCubit(
      sendReminder: sl(),
      membershipRepository: sl(),
      userRepository: sl(),
    ),
  );

  // WhatsApp reminder
  sl.registerFactory(() => WhatsAppReminderCubit(repository: sl()));

  // Notification permission
  sl.registerLazySingleton(() => NotificationPermissionCubit(messaging: sl()));

  // Version check
  sl.registerLazySingleton(() => VersionCheckCubit(checkVersionUpdate: sl()));

  // Slot management
  sl.registerFactory(
    () => SlotManagementCubit(
      createSlot: sl(),
      updateSlot: sl(),
      deleteSlot: sl(),
      getSlotsByLibrary: sl(),
      libraryRepository: sl(),
    ),
  );

  // Notice management - Owner
  sl.registerFactory(
    () => OwnerNoticeCubit(
      getNoticesByLibrary: sl(),
      createNotice: sl(),
      updateNotice: sl(),
      deleteNotice: sl(),
      publishNotice: sl(),
      getNoticeAnalytics: sl(),
      whatsAppNotificationRepository: sl(),
    ),
  );

  // Notice management - Student
  sl.registerFactory(
    () => StudentNoticeCubit(
      getActiveNoticesForStudent: sl(),
      getReadStatusForStudent: sl(),
      markNoticeAsRead: sl(),
      getNoticeById: sl(),
      incrementNoticeViewCount: sl(),
      libraryRepository: sl(),
      userRepository: sl(),
    ),
  );

  // ============================================================================
  // Admin Intelligence V2
  // ============================================================================

  // Admin Intelligence Repository
  sl.registerLazySingleton<AdminIntelligenceRepository>(
    () => AdminIntelligenceRepositoryImpl(firestore: sl()),
  );

  // Admin Intelligence Use Cases
  sl.registerLazySingleton(() => GetRevenueStats(repository: sl()));
  sl.registerLazySingleton(() => GetChurnData(repository: sl()));
  sl.registerLazySingleton(() => GetAlertsSummary(repository: sl()));
  sl.registerLazySingleton(() => GetAdminActions(repository: sl()));
  sl.registerLazySingleton(() => SuspendLibrary(repository: sl()));
  sl.registerLazySingleton(() => UnsuspendLibrary(repository: sl()));
  sl.registerLazySingleton(() => ExtendTrial(repository: sl()));
  sl.registerLazySingleton(() => ApplyDiscount(repository: sl()));
  sl.registerLazySingleton(() => RemoveDiscount(repository: sl()));
  sl.registerLazySingleton(
    () =>
        AdminMarkPaymentReceived(repository: sl<AdminIntelligenceRepository>()),
  );
  sl.registerLazySingleton(() => MarkAlertAsRead(repository: sl()));

  // Admin Intelligence Cubit
  sl.registerFactory(
    () => AdminIntelligenceCubit(
      getRevenueStats: sl(),
      getChurnData: sl(),
      getAlertsSummary: sl(),
      getAdminActions: sl(),
      suspendLibrary: sl(),
      unsuspendLibrary: sl(),
      extendTrial: sl(),
      applyDiscount: sl(),
      removeDiscount: sl(),
      adminMarkPaymentReceived: sl(),
      markAlertAsRead: sl(),
    ),
  );
}
