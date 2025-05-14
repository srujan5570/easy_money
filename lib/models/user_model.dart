import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String username;
  final String phoneNumber;
  int points;
  int totalEarnings;
  int todayEarning;
  String? referredBy;
  final String referralCode;
  List<String> referredUsers;
  int referralEarnings;
  int totalReferrals;
  DateTime? lastReferralDate;
  DateTime? referralAppliedDate;
  String upiId;
  DateTime lastLoginDate;
  int spinsToday;
  int remainingSpins;
  DateTime? lastSpinDate;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.username,
    this.phoneNumber = "",
    this.points = 0,
    this.totalEarnings = 0,
    this.todayEarning = 0,
    this.referredBy,
    required this.referralCode,
    this.referredUsers = const [],
    this.referralEarnings = 0,
    this.totalReferrals = 0,
    this.lastReferralDate,
    this.referralAppliedDate,
    this.upiId = "",
    required this.lastLoginDate,
    this.spinsToday = 0,
    this.remainingSpins = 5,
    this.lastSpinDate,
    DateTime? createdAt,
  }) : this.createdAt = createdAt ?? DateTime.now();

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return null;
    }

    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      points: map['points'] ?? 0,
      totalEarnings: map['totalEarnings'] ?? 0,
      todayEarning: map['todayEarning'] ?? 0,
      referredBy: map['referredBy'],
      referralCode: map['referralCode'] ?? '',
      referredUsers: List<String>.from(map['referredUsers'] ?? []),
      referralEarnings: map['referralEarnings'] ?? 0,
      totalReferrals: map['totalReferrals'] ?? 0,
      lastReferralDate: parseDate(map['lastReferralDate']),
      referralAppliedDate: parseDate(map['referralAppliedDate']),
      upiId: map['upiId'] ?? '',
      lastLoginDate: parseDate(map['lastLoginDate']) ?? DateTime.now(),
      spinsToday: map['spinsToday'] ?? 0,
      remainingSpins: map['remainingSpins'] ?? 5,
      lastSpinDate: parseDate(map['lastSpinDate']),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'username': username,
      'phoneNumber': phoneNumber,
      'points': points,
      'totalEarnings': totalEarnings,
      'todayEarning': todayEarning,
      'referredBy': referredBy,
      'referralCode': referralCode,
      'referredUsers': referredUsers,
      'referralEarnings': referralEarnings,
      'totalReferrals': totalReferrals,
      'lastReferralDate': lastReferralDate != null ? Timestamp.fromDate(lastReferralDate!) : null,
      'referralAppliedDate': referralAppliedDate != null ? Timestamp.fromDate(referralAppliedDate!) : null,
      'upiId': upiId,
      'lastLoginDate': Timestamp.fromDate(lastLoginDate),
      'spinsToday': spinsToday,
      'remainingSpins': remainingSpins,
      'lastSpinDate': lastSpinDate != null ? Timestamp.fromDate(lastSpinDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? username,
    String? phoneNumber,
    int? points,
    int? totalEarnings,
    int? todayEarning,
    String? referredBy,
    String? referralCode,
    List<String>? referredUsers,
    int? referralEarnings,
    int? totalReferrals,
    DateTime? lastReferralDate,
    DateTime? referralAppliedDate,
    String? upiId,
    DateTime? lastLoginDate,
    int? spinsToday,
    int? remainingSpins,
    DateTime? lastSpinDate,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      points: points ?? this.points,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      todayEarning: todayEarning ?? this.todayEarning,
      referredBy: referredBy ?? this.referredBy,
      referralCode: referralCode ?? this.referralCode,
      referredUsers: referredUsers ?? this.referredUsers,
      referralEarnings: referralEarnings ?? this.referralEarnings,
      totalReferrals: totalReferrals ?? this.totalReferrals,
      lastReferralDate: lastReferralDate ?? this.lastReferralDate,
      referralAppliedDate: referralAppliedDate ?? this.referralAppliedDate,
      upiId: upiId ?? this.upiId,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      spinsToday: spinsToday ?? this.spinsToday,
      remainingSpins: remainingSpins ?? this.remainingSpins,
      lastSpinDate: lastSpinDate ?? this.lastSpinDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 