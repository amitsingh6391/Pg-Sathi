import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../domain/core/failure.dart';
import '../../domain/entities/referral.dart';
import '../../domain/repositories/referral_repository.dart';

class _ReferralDataFailure extends Failure {
  const _ReferralDataFailure({super.message});
}

class ReferralRepositoryImpl implements ReferralRepository {
  const ReferralRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _referralsRef =>
      firestore.collection('referrals');

  CollectionReference<Map<String, dynamic>> get _redemptionsRef =>
      firestore.collection('referral_redemptions');

  CollectionReference<Map<String, dynamic>> get _walletsRef =>
      firestore.collection('referral_wallets');

  CollectionReference<Map<String, dynamic>> get _withdrawalsRef =>
      firestore.collection('referral_withdrawals');

  // =========================================================================
  // Referral CRUD
  // =========================================================================

  @override
  Future<Either<Failure, Referral>> createReferral(Referral referral) async {
    try {
      await _referralsRef.doc(referral.id).set(_referralToMap(referral));
      // Also index by code for fast lookup
      await _referralsRef
          .doc(referral.id)
          .collection('_meta')
          .doc('code_index')
          .set({'code': referral.code});
      return Right(referral);
    } catch (e) {
      return Left(_ReferralDataFailure(message: 'Failed to create referral: $e'));
    }
  }

  @override
  Future<Either<Failure, Referral?>> getReferralByOwnerId(
    String ownerId,
  ) async {
    try {
      final query = await _referralsRef
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return const Right(null);
      return Right(_referralFromDoc(query.docs.first));
    } catch (e) {
      return Left(_ReferralDataFailure(message: 'Failed to get referral: $e'));
    }
  }

  @override
  Future<Either<Failure, Referral?>> getReferralByCode(String code) async {
    try {
      final query = await _referralsRef
          .where('code', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) return const Right(null);
      return Right(_referralFromDoc(query.docs.first));
    } catch (e) {
      return Left(_ReferralDataFailure(message: 'Failed to get referral: $e'));
    }
  }

  @override
  Future<Either<Failure, Referral>> updateReferral(Referral referral) async {
    try {
      await _referralsRef.doc(referral.id).update(_referralToMap(referral));
      return Right(referral);
    } catch (e) {
      return Left(_ReferralDataFailure(message: 'Failed to update referral: $e'));
    }
  }

  // =========================================================================
  // Redemptions
  // =========================================================================

  @override
  Future<Either<Failure, ReferralRedemption>> createRedemption(
    ReferralRedemption redemption,
  ) async {
    try {
      await _redemptionsRef
          .doc(redemption.id)
          .set(_redemptionToMap(redemption));
      return Right(redemption);
    } catch (e) {
      return Left(
        _ReferralDataFailure(message: 'Failed to create redemption: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, ReferralRedemption>> updateRedemption(
    ReferralRedemption redemption,
  ) async {
    try {
      await _redemptionsRef
          .doc(redemption.id)
          .update(_redemptionToMap(redemption));
      return Right(redemption);
    } catch (e) {
      return Left(
        _ReferralDataFailure(message: 'Failed to update redemption: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ReferralRedemption>>> getRedemptionsByReferrer(
    String referrerId,
  ) async {
    try {
      final query = await _redemptionsRef
          .where('referrerId', isEqualTo: referrerId)
          .get();

      final results = query.docs.map(_redemptionFromDoc).toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });

      return Right(results);
    } catch (e) {
      return Left(
        _ReferralDataFailure(message: 'Failed to get redemptions: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, ReferralRedemption?>> getRedemptionByReferee(
    String refereeId,
  ) async {
    try {
      final query = await _redemptionsRef
          .where('refereeId', isEqualTo: refereeId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return const Right(null);
      return Right(_redemptionFromDoc(query.docs.first));
    } catch (e) {
      return Left(
        _ReferralDataFailure(message: 'Failed to get redemption: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ReferralRedemption>>> getUnclaimedRewards(
    String referrerId,
  ) async {
    try {
      // Single-field query to avoid composite index requirement.
      // Filter converted + unclaimed in memory.
      final query = await _redemptionsRef
          .where('referrerId', isEqualTo: referrerId)
          .get();

      final unclaimed = query.docs
          .map(_redemptionFromDoc)
          .where((r) => r.isConverted && !r.rewardClaimed)
          .toList();

      return Right(unclaimed);
    } catch (e) {
      return Left(
        _ReferralDataFailure(message: 'Failed to get unclaimed rewards: $e'),
      );
    }
  }

  // =========================================================================
  // Wallet
  // =========================================================================

  @override
  Future<Either<Failure, ReferralWallet>> getOrCreateWallet(
    String ownerId,
  ) async {
    try {
      final doc = await _walletsRef.doc(ownerId).get();

      if (doc.exists) {
        return Right(_walletFromDoc(doc));
      }

      final wallet = ReferralWallet(
        ownerId: ownerId,
        updatedAt: DateTime.now(),
      );
      await _walletsRef.doc(ownerId).set(_walletToMap(wallet));
      return Right(wallet);
    } catch (e) {
      return Left(_ReferralDataFailure(message: 'Failed to get wallet: $e'));
    }
  }

  @override
  Future<Either<Failure, ReferralWallet>> updateWallet(
    ReferralWallet wallet,
  ) async {
    try {
      await _walletsRef.doc(wallet.ownerId).update(_walletToMap(wallet));
      return Right(wallet);
    } catch (e) {
      return Left(_ReferralDataFailure(message: 'Failed to update wallet: $e'));
    }
  }

  // =========================================================================
  // Withdrawals
  // =========================================================================

  @override
  Future<Either<Failure, WithdrawalRequest>> createWithdrawalRequest(
    WithdrawalRequest request,
  ) async {
    try {
      await _withdrawalsRef.doc(request.id).set(_withdrawalToMap(request));
      return Right(request);
    } catch (e) {
      return Left(
        _ReferralDataFailure(message: 'Failed to create withdrawal: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<WithdrawalRequest>>> getWithdrawalRequests(
    String ownerId,
  ) async {
    try {
      final query = await _withdrawalsRef
          .where('ownerId', isEqualTo: ownerId)
          .get();

      final results = query.docs.map(_withdrawalFromDoc).toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });

      return Right(results);
    } catch (e) {
      return Left(
        _ReferralDataFailure(message: 'Failed to get withdrawals: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<WithdrawalRequest>>>
      getAllPendingWithdrawals() async {
    try {
      final query = await _withdrawalsRef
          .where('status', isEqualTo: 'pending')
          .get();

      final results = query.docs.map(_withdrawalFromDoc).toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          return aDate.compareTo(bDate); // oldest first
        });

      return Right(results);
    } catch (e) {
      return Left(
        _ReferralDataFailure(
          message: 'Failed to get pending withdrawals: $e',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, WithdrawalRequest>> updateWithdrawalRequest(
    WithdrawalRequest request,
  ) async {
    try {
      await _withdrawalsRef
          .doc(request.id)
          .update(_withdrawalToMap(request));
      return Right(request);
    } catch (e) {
      return Left(
        _ReferralDataFailure(
          message: 'Failed to update withdrawal request: $e',
        ),
      );
    }
  }

  // =========================================================================
  // Mappers
  // =========================================================================

  Map<String, dynamic> _referralToMap(Referral r) => {
    'ownerId': r.ownerId,
    'code': r.code,
    'isActive': r.isActive,
    'totalRedemptions': r.totalRedemptions,
    'successfulConversions': r.successfulConversions,
    'createdAt': r.createdAt != null
        ? Timestamp.fromDate(r.createdAt!)
        : FieldValue.serverTimestamp(),
    'updatedAt': Timestamp.fromDate(r.updatedAt ?? DateTime.now()),
  };

  Referral _referralFromDoc(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return Referral(
      id: doc.id,
      ownerId: d['ownerId'] as String,
      code: d['code'] as String,
      isActive: d['isActive'] as bool? ?? true,
      totalRedemptions: d['totalRedemptions'] as int? ?? 0,
      successfulConversions: d['successfulConversions'] as int? ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> _redemptionToMap(ReferralRedemption r) => {
    'referralCode': r.referralCode,
    'referrerId': r.referrerId,
    'refereeId': r.refereeId,
    'status': r.status.name,
    'subscriptionId': r.subscriptionId,
    'rewardType': r.rewardType?.name,
    'rewardClaimed': r.rewardClaimed,
    'createdAt': r.createdAt != null
        ? Timestamp.fromDate(r.createdAt!)
        : FieldValue.serverTimestamp(),
    'convertedAt': r.convertedAt != null
        ? Timestamp.fromDate(r.convertedAt!)
        : null,
  };

  ReferralRedemption _redemptionFromDoc(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return ReferralRedemption(
      id: doc.id,
      referralCode: d['referralCode'] as String,
      referrerId: d['referrerId'] as String,
      refereeId: d['refereeId'] as String,
      status: ReferralRedemptionStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => ReferralRedemptionStatus.pending,
      ),
      subscriptionId: d['subscriptionId'] as String?,
      rewardType: d['rewardType'] != null
          ? ReferralRewardType.values.firstWhere(
              (t) => t.name == d['rewardType'],
              orElse: () => ReferralRewardType.walletCredit,
            )
          : null,
      rewardClaimed: d['rewardClaimed'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      convertedAt: (d['convertedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> _walletToMap(ReferralWallet w) => {
    'balance': w.balance,
    'totalEarned': w.totalEarned,
    'totalWithdrawn': w.totalWithdrawn,
    'updatedAt': Timestamp.fromDate(w.updatedAt ?? DateTime.now()),
  };

  ReferralWallet _walletFromDoc(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return ReferralWallet(
      ownerId: doc.id,
      balance: (d['balance'] as num?)?.toDouble() ?? 0,
      totalEarned: (d['totalEarned'] as num?)?.toDouble() ?? 0,
      totalWithdrawn: (d['totalWithdrawn'] as num?)?.toDouble() ?? 0,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> _withdrawalToMap(WithdrawalRequest w) => {
    'ownerId': w.ownerId,
    'amount': w.amount,
    'status': w.status.name,
    'upiId': w.upiId,
    'processedAt': w.processedAt != null
        ? Timestamp.fromDate(w.processedAt!)
        : null,
    'rejectionReason': w.rejectionReason,
    'createdAt': w.createdAt != null
        ? Timestamp.fromDate(w.createdAt!)
        : FieldValue.serverTimestamp(),
  };

  WithdrawalRequest _withdrawalFromDoc(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return WithdrawalRequest(
      id: doc.id,
      ownerId: d['ownerId'] as String,
      amount: (d['amount'] as num).toDouble(),
      status: WithdrawalStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => WithdrawalStatus.pending,
      ),
      upiId: d['upiId'] as String?,
      processedAt: (d['processedAt'] as Timestamp?)?.toDate(),
      rejectionReason: d['rejectionReason'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
