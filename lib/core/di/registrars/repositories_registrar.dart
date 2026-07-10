import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import '../../../data/providers/firebase_otp_provider.dart';
import '../../../data/providers/sms_portals_otp_provider.dart';
import '../../../data/repositories/admin_analytics_repository_impl.dart';
import '../../../data/repositories/analytics_dashboard_repository_impl.dart';
import '../../../data/repositories/attendance_repository_impl.dart';
import '../../../data/repositories/auth_repository_impl.dart';
import '../../../data/repositories/device_session_repository_impl.dart';
import '../../../data/repositories/expense_repository_impl.dart';
import '../../../data/repositories/invoice_repository_impl.dart';
import '../../../data/repositories/library_repository_impl.dart';
import '../../../data/repositories/membership_repository_impl.dart';
import '../../../data/repositories/notice_repository_impl.dart';
import '../../../data/repositories/notification_repository_impl.dart';
import '../../../data/repositories/promo_repository_impl.dart';
import '../../../data/repositories/payment_repository_impl.dart';
import '../../../data/repositories/presence_repository_impl.dart';
import '../../../data/repositories/seat_repository_impl.dart';
import '../../../data/repositories/slot_repository_impl.dart';
import '../../../data/repositories/student_document_repository_impl.dart';
import '../../../data/repositories/subscription_repository_impl.dart';
import '../../../data/repositories/user_repository_impl.dart';
import '../../../data/repositories/user_session_repository_impl.dart';
import '../../../data/repositories/version_repository_impl.dart';
import '../../../data/repositories/referral_repository_impl.dart';
import '../../../data/repositories/whatsapp_reminder_repository_impl.dart';
import '../../../data/repositories/whatsapp_notification_repository_impl.dart';
import '../../../data/services/membership_notification_service.dart';
import '../../../data/services/otp_quota_service.dart';
import '../../../data/services/storage_service.dart' as data_storage;
import '../../../data/services/subscription_notification_service.dart';
import '../../../domain/repositories/admin_analytics_repository.dart';
import '../../../domain/repositories/analytics_dashboard_repository.dart';
import '../../../domain/repositories/attendance_repository.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/device_session_repository.dart';
import '../../../domain/repositories/expense_repository.dart';
import '../../../domain/repositories/invoice_repository.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/membership_repository.dart';
import '../../../domain/repositories/notice_repository.dart';
import '../../../domain/repositories/notification_repository.dart';
import '../../../domain/repositories/promo_repository.dart';
import '../../../domain/repositories/payment_repository.dart';
import '../../../domain/repositories/presence_repository.dart';
import '../../../domain/repositories/seat_repository.dart';
import '../../../domain/repositories/slot_repository.dart';
import '../../../domain/repositories/student_document_repository.dart';
import '../../../domain/repositories/subscription_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/repositories/user_session_repository.dart';
import '../../../domain/repositories/version_repository.dart';
import '../../../domain/repositories/referral_repository.dart';
import '../../../domain/repositories/whatsapp_reminder_repository.dart';
import '../../../domain/repositories/whatsapp_notification_repository.dart';

void registerRepositories(GetIt sl) {
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      firebaseAuth: sl(),
      firestore: sl(),
      deviceInfoService: sl(),
      otpProvider: sl(),
      firebaseOtpProvider: sl<FirebaseOtpProvider>(),
      smsPortalsOtpProvider: sl<SmsPortalsOtpProvider>(),
      otpQuotaService: sl<OtpQuotaService>(),
      remoteConfig: sl(),
      functions: sl(),
    ),
  );

  sl.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<VersionRepository>(
    () => VersionRepositoryImpl(remoteConfig: sl()),
  );

  sl.registerLazySingleton<LibraryRepository>(
    () => LibraryRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<SeatRepository>(
    () => SeatRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<MembershipRepository>(
    () => MembershipRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<PaymentRepository>(
    () => PaymentRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<PresenceRepository>(
    () => PresenceRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<AttendanceRepository>(
    () => AttendanceRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<InvoiceRepository>(
    () => InvoiceRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(firestore: sl(), messaging: sl()),
  );

  sl.registerLazySingleton<SlotRepository>(
    () => SlotRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<StudentDocumentRepository>(
    () => StudentDocumentRepositoryImpl(
      firestore: sl(),
      storageService: sl<data_storage.StorageService>(),
    ),
  );

  sl.registerLazySingleton<WhatsAppReminderRepository>(
    () => WhatsAppReminderRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<AdminAnalyticsRepository>(
    () => AdminAnalyticsRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<AnalyticsDashboardRepository>(
    () => AnalyticsDashboardRepositoryImpl(sl()),
  );

  sl.registerLazySingleton<UserSessionRepository>(
    () => UserSessionRepositoryImpl(sl<FirebaseFirestore>()),
  );

  sl.registerLazySingleton<ExpenseRepository>(
    () => ExpenseRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<NoticeRepository>(
    () => NoticeRepositoryImpl(
      firestore: sl(),
      storageService: sl<data_storage.StorageService>(),
      notificationRepository: sl(),
    ),
  );

  sl.registerLazySingleton<DeviceSessionRepository>(
    () => DeviceSessionRepositoryImpl(sl<FirebaseFirestore>()),
  );

  sl.registerLazySingleton<ReferralRepository>(
    () => ReferralRepositoryImpl(firestore: sl()),
  );

  // Subscription notification service
  sl.registerLazySingleton(
    () => SubscriptionNotificationService(
      notificationRepository: sl(),
      userRepository: sl(),
    ),
  );

  // Membership notification service
  sl.registerLazySingleton(
    () => MembershipNotificationService(notificationRepository: sl()),
  );

  // Promo repository
  sl.registerLazySingleton<PromoRepository>(
    () => PromoRepositoryImpl(firestore: sl(), promoSeenService: sl()),
  );

  sl.registerLazySingleton<WhatsAppNotificationRepository>(
    () => WhatsAppNotificationRepositoryImpl(
      functions: sl(),
      firestore: sl(),
    ),
  );
}
