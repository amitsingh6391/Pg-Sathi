import 'package:equatable/equatable.dart';

/// Represents a referral code owned by an active subscriber.
/// The code gives the referee 15% off their first subscription,
/// and the referrer earns a reward (free month or ₹149 wallet credit).
class Referral extends Equatable {
  const Referral({
    required this.id,
    required this.ownerId,
    required this.code,
    required this.isActive,
    this.totalRedemptions = 0,
    this.successfulConversions = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String code;
  final bool isActive;
  final int totalRedemptions;
  final int successfulConversions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasConversions => successfulConversions > 0;

  Referral copyWith({
    String? id,
    String? ownerId,
    String? code,
    bool? isActive,
    int? totalRedemptions,
    int? successfulConversions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Referral(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      code: code ?? this.code,
      isActive: isActive ?? this.isActive,
      totalRedemptions: totalRedemptions ?? this.totalRedemptions,
      successfulConversions:
          successfulConversions ?? this.successfulConversions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Referral incrementRedemption() {
    return copyWith(
      totalRedemptions: totalRedemptions + 1,
      updatedAt: DateTime.now(),
    );
  }

  Referral incrementConversion() {
    return copyWith(
      successfulConversions: successfulConversions + 1,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    code,
    isActive,
    totalRedemptions,
    successfulConversions,
    createdAt,
    updatedAt,
  ];
}

/// Tracks each individual referral redemption.
class ReferralRedemption extends Equatable {
  const ReferralRedemption({
    required this.id,
    required this.referralCode,
    required this.referrerId,
    required this.refereeId,
    required this.status,
    this.subscriptionId,
    this.rewardType,
    this.rewardClaimed = false,
    this.createdAt,
    this.convertedAt,
  });

  final String id;
  final String referralCode;
  final String referrerId;
  final String refereeId;
  final ReferralRedemptionStatus status;
  final String? subscriptionId;
  final ReferralRewardType? rewardType;
  final bool rewardClaimed;
  final DateTime? createdAt;
  final DateTime? convertedAt;

  bool get isConverted => status == ReferralRedemptionStatus.converted;
  bool get isPending => status == ReferralRedemptionStatus.pending;

  ReferralRedemption markConverted({
    required String subscriptionId,
  }) {
    return ReferralRedemption(
      id: id,
      referralCode: referralCode,
      referrerId: referrerId,
      refereeId: refereeId,
      status: ReferralRedemptionStatus.converted,
      subscriptionId: subscriptionId,
      rewardType: rewardType,
      rewardClaimed: rewardClaimed,
      createdAt: createdAt,
      convertedAt: DateTime.now(),
    );
  }

  ReferralRedemption claimReward(ReferralRewardType type) {
    return ReferralRedemption(
      id: id,
      referralCode: referralCode,
      referrerId: referrerId,
      refereeId: refereeId,
      status: status,
      subscriptionId: subscriptionId,
      rewardType: type,
      rewardClaimed: true,
      createdAt: createdAt,
      convertedAt: convertedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    referralCode,
    referrerId,
    refereeId,
    status,
    subscriptionId,
    rewardType,
    rewardClaimed,
    createdAt,
    convertedAt,
  ];
}

enum ReferralRedemptionStatus { pending, converted, expired }

enum ReferralRewardType { freeMonth, walletCredit }

/// Wallet for referral earnings. Owners can accumulate credit
/// from successful referrals and either use it for their next
/// subscription or request a withdrawal.
class ReferralWallet extends Equatable {
  const ReferralWallet({
    required this.ownerId,
    this.balance = 0,
    this.totalEarned = 0,
    this.totalWithdrawn = 0,
    this.updatedAt,
  });

  final String ownerId;
  final double balance;
  final double totalEarned;
  final double totalWithdrawn;
  final DateTime? updatedAt;

  static const double creditPerReferral = 149.0;

  ReferralWallet addCredit(double amount) {
    return ReferralWallet(
      ownerId: ownerId,
      balance: balance + amount,
      totalEarned: totalEarned + amount,
      totalWithdrawn: totalWithdrawn,
      updatedAt: DateTime.now(),
    );
  }

  ReferralWallet withdraw(double amount) {
    return ReferralWallet(
      ownerId: ownerId,
      balance: balance - amount,
      totalEarned: totalEarned,
      totalWithdrawn: totalWithdrawn + amount,
      updatedAt: DateTime.now(),
    );
  }

  bool canWithdraw(double amount) => balance >= amount;

  @override
  List<Object?> get props => [
    ownerId,
    balance,
    totalEarned,
    totalWithdrawn,
    updatedAt,
  ];
}

/// Tracks withdrawal requests.
class WithdrawalRequest extends Equatable {
  const WithdrawalRequest({
    required this.id,
    required this.ownerId,
    required this.amount,
    required this.status,
    this.upiId,
    this.processedAt,
    this.rejectionReason,
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final double amount;
  final WithdrawalStatus status;
  final String? upiId;
  final DateTime? processedAt;
  final String? rejectionReason;
  final DateTime? createdAt;

  bool get isPending => status == WithdrawalStatus.pending;
  bool get isApproved => status == WithdrawalStatus.approved;
  bool get isRejected => status == WithdrawalStatus.rejected;

  WithdrawalRequest approve() => WithdrawalRequest(
        id: id,
        ownerId: ownerId,
        amount: amount,
        status: WithdrawalStatus.approved,
        upiId: upiId,
        processedAt: DateTime.now(),
        createdAt: createdAt,
      );

  WithdrawalRequest reject(String reason) => WithdrawalRequest(
        id: id,
        ownerId: ownerId,
        amount: amount,
        status: WithdrawalStatus.rejected,
        upiId: upiId,
        processedAt: DateTime.now(),
        rejectionReason: reason,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
    id,
    ownerId,
    amount,
    status,
    upiId,
    processedAt,
    rejectionReason,
    createdAt,
  ];
}

enum WithdrawalStatus { pending, approved, rejected }
