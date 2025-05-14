import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  int points;
  final String referralCode;
  String? referredBy;
  DateTime lastLogin;
  DateTime lastSpinDate;
  String? upiId;
  int spinsToday;
  double totalEarnings;
  double todayEarning;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    this.points = 0,
    required this.referralCode,
    this.referredBy,
    required this.lastLogin,
    required this.lastSpinDate,
    this.upiId,
    this.spinsToday = 0,
    this.totalEarnings = 0,
    this.todayEarning = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'points': points,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'lastLogin': Timestamp.fromDate(lastLogin),
      'lastSpinDate': Timestamp.fromDate(lastSpinDate),
      'upiId': upiId,
      'spinsToday': spinsToday,
      'totalEarnings': totalEarnings,
      'todayEarning': todayEarning,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, [String? userId]) {
    return AppUser(
      uid: userId ?? map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoURL: map['photoURL'],
      points: map['points']?.toInt() ?? 0,
      referralCode: map['referralCode'] ?? '',
      referredBy: map['referredBy'],
      lastLogin: (map['lastLogin'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSpinDate: (map['lastSpinDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      upiId: map['upiId'],
      spinsToday: map['spinsToday']?.toInt() ?? 0,
      totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
      todayEarning: (map['todayEarning'] ?? 0).toDouble(),
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    int? points,
    String? referralCode,
    String? referredBy,
    DateTime? lastLogin,
    DateTime? lastSpinDate,
    String? upiId,
    int? spinsToday,
    double? totalEarnings,
    double? todayEarning,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      points: points ?? this.points,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      lastLogin: lastLogin ?? this.lastLogin,
      lastSpinDate: lastSpinDate ?? this.lastSpinDate,
      upiId: upiId ?? this.upiId,
      spinsToday: spinsToday ?? this.spinsToday,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      todayEarning: todayEarning ?? this.todayEarning,
    );
  }
} 