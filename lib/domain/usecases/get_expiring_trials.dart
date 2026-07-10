import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../core/core.dart';
import '../entities/library.dart';
import '../entities/owner_trial.dart';
import '../entities/subscription.dart';
import '../entities/user.dart';
import '../repositories/library_repository.dart';
import '../repositories/subscription_repository.dart';
import '../repositories/user_repository.dart';
import '../../data/failures/data_failures.dart';

/// Result of fetching all trial and subscription data needed by the admin
/// expiring-subscriptions screen.
class ExpiringTrialsResult {
  const ExpiringTrialsResult({
    required this.expiringTrials,
    required this.activeTrials,
    required this.expiredTrials,
    required this.libraryCache,
    required this.ownerCache,
  });

  final List<ExpiringTrialInfo> expiringTrials;
  final List<ExpiringTrialInfo> activeTrials;
  final List<ExpiringTrialInfo> expiredTrials;
  final Map<String, Library> libraryCache;
  final Map<String, User> ownerCache;
}

/// View-model pairing a trial with its owner/library context for display.
class ExpiringTrialInfo extends Equatable {
  const ExpiringTrialInfo({
    required this.ownerId,
    required this.libraryId,
    required this.libraryName,
    required this.ownerName,
    required this.ownerPhone,
    required this.trial,
    required this.daysRemaining,
  });

  final String ownerId;
  final String libraryId;
  final String libraryName;
  final String ownerName;
  final String ownerPhone;
  final OwnerTrial trial;
  final int daysRemaining;

  bool get isUrgent => daysRemaining <= 3;

  @override
  List<Object?> get props => [
        ownerId,
        libraryId,
        libraryName,
        ownerName,
        ownerPhone,
        trial,
        daysRemaining,
      ];
}

class GetExpiringTrialsParams extends Equatable {
  const GetExpiringTrialsParams({
    required this.allSubscriptions,
    this.expiringDaysThreshold = 7,
  });

  final List<Subscription> allSubscriptions;
  final int expiringDaysThreshold;

  @override
  List<Object?> get props => [allSubscriptions, expiringDaysThreshold];
}

/// Fetches all trial + library + owner data for the admin subscriptions screen.
///
/// Replaces the presentation-layer ExpiringSubscriptionsService so that
/// repository orchestration lives in the domain layer where it belongs.
class GetExpiringTrials
    implements UseCase<ExpiringTrialsResult, GetExpiringTrialsParams> {
  const GetExpiringTrials({
    required this.libraryRepository,
    required this.subscriptionRepository,
    required this.userRepository,
  });

  final LibraryRepository libraryRepository;
  final SubscriptionRepository subscriptionRepository;
  final UserRepository userRepository;

  @override
  Future<Either<Failure, ExpiringTrialsResult>> call(
    GetExpiringTrialsParams params,
  ) async {
    try {
      final now = DateTime.now();

      final allOwnersResult = await userRepository.getUsersByRole(UserRole.owner);

      late List<User> owners;
      final foldError = allOwnersResult.fold<Failure?>(
        (f) => f,
        (o) {
          owners = o;
          return null;
        },
      );
      if (foldError != null) return Left(foldError);

      if (owners.isEmpty) {
        return Right(ExpiringTrialsResult(
          expiringTrials: const [],
          activeTrials: const [],
          expiredTrials: const [],
          libraryCache: const {},
          ownerCache: const {},
        ));
      }

      // Fetch all libraries + trials in parallel across all owners
      final libraryFutures = owners
          .map((o) => libraryRepository.getLibraryByOwnerId(o.id))
          .toList();
      final trialFutures = owners
          .map((o) => subscriptionRepository.getTrial(o.id))
          .toList();

      final libraryResults = await Future.wait(libraryFutures);
      final trialResults = await Future.wait(trialFutures);

      // Build lookup maps
      final ownerLibraryMap = <String, Library>{};
      for (var i = 0; i < owners.length; i++) {
        libraryResults[i].fold((_) => null, (lib) {
          if (lib != null) ownerLibraryMap[owners[i].id] = lib;
        });
      }

      final expiringTrials = <ExpiringTrialInfo>[];
      final activeTrials = <ExpiringTrialInfo>[];
      final expiredTrials = <ExpiringTrialInfo>[];

      for (var i = 0; i < owners.length; i++) {
        final owner = owners[i];
        final library = ownerLibraryMap[owner.id];
        if (library == null) continue;

        OwnerTrial? trial;
        trialResults[i].fold((_) => null, (t) => trial = t);

        if (trial == null && library.createdAt != null) {
          trial = OwnerTrial.fromAccountCreation(
            ownerId: owner.id,
            accountCreatedAt: library.createdAt!,
          );
        }

        if (trial == null || trial!.isUsed) continue;

        final daysRemaining = trial!.daysRemaining(now);
        final info = ExpiringTrialInfo(
          ownerId: owner.id,
          libraryId: library.id,
          libraryName: library.name,
          ownerName: owner.displayName,
          ownerPhone: owner.phone,
          trial: trial!,
          daysRemaining: daysRemaining,
        );

        if (daysRemaining < 0) {
          expiredTrials.add(info);
        } else if (daysRemaining <= params.expiringDaysThreshold) {
          expiringTrials.add(info);
        } else {
          activeTrials.add(info);
        }
      }

      // Build library/owner caches for expiring subscriptions display
      final libraryCache = await _fetchLibraryCache(params.allSubscriptions);
      final ownerCache = await _fetchOwnerCache(libraryCache.values.toList());

      return Right(ExpiringTrialsResult(
        expiringTrials: expiringTrials,
        activeTrials: activeTrials,
        expiredTrials: expiredTrials,
        libraryCache: libraryCache,
        ownerCache: ownerCache,
      ));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  Future<Map<String, Library>> _fetchLibraryCache(
    List<Subscription> subscriptions,
  ) async {
    final uniqueIds =
        subscriptions.map((s) => s.libraryId).toSet().toList();
    if (uniqueIds.isEmpty) return {};

    final results = await Future.wait(
      uniqueIds.map((id) => libraryRepository.getLibraryById(id)),
    );

    final cache = <String, Library>{};
    for (var i = 0; i < uniqueIds.length; i++) {
      results[i].fold((_) => null, (lib) {
        if (lib != null) cache[uniqueIds[i]] = lib;
      });
    }
    return cache;
  }

  Future<Map<String, User>> _fetchOwnerCache(List<Library> libraries) async {
    final uniqueOwnerIds =
        libraries.map((lib) => lib.ownerId).toSet().toList();
    if (uniqueOwnerIds.isEmpty) return {};

    final results = await Future.wait(
      uniqueOwnerIds.map((id) => userRepository.getUserById(id)),
    );

    final cache = <String, User>{};
    for (var i = 0; i < uniqueOwnerIds.length; i++) {
      results[i].fold((_) => null, (user) => cache[uniqueOwnerIds[i]] = user);
    }
    return cache;
  }
}
