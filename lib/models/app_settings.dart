import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettings {
  final bool maintenanceMode;
  final AppVersion appVersion;
  final double minWithdrawalAmount;
  final double maxWithdrawalAmount;
  final double pointsToRupeeRatio;
  final int referralBonus;
  final String updateMessage;
  final Map<String, dynamic> additionalSettings;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppSettings({
    this.maintenanceMode = false,
    AppVersion? appVersion,
    this.minWithdrawalAmount = 2.0,
    this.maxWithdrawalAmount = 1000.0,
    this.pointsToRupeeRatio = 0.001, // 1000 points = ₹1
    this.referralBonus = 2000, // 2000 points = ₹2
    this.updateMessage = '',
    this.additionalSettings = const {},
    this.createdAt,
    this.updatedAt,
  }) : appVersion = appVersion ?? AppVersion();

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      maintenanceMode: map['maintenanceMode'] ?? false,
      appVersion: map['appVersion'] != null 
          ? AppVersion.fromMap(map['appVersion']) 
          : AppVersion(),
      minWithdrawalAmount: (map['minWithdrawalAmount'] ?? 2.0).toDouble(),
      maxWithdrawalAmount: (map['maxWithdrawalAmount'] ?? 1000.0).toDouble(),
      pointsToRupeeRatio: (map['pointsToRupeeRatio'] ?? 0.001).toDouble(),
      referralBonus: map['referralBonus'] ?? 2000,
      updateMessage: map['updateMessage'] ?? '',
      additionalSettings: Map<String, dynamic>.from(map['additionalSettings'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'maintenanceMode': maintenanceMode,
      'appVersion': appVersion.toMap(),
      'minWithdrawalAmount': minWithdrawalAmount,
      'maxWithdrawalAmount': maxWithdrawalAmount,
      'pointsToRupeeRatio': pointsToRupeeRatio,
      'referralBonus': referralBonus,
      'updateMessage': updateMessage,
      'additionalSettings': additionalSettings,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AppSettings copyWith({
    bool? maintenanceMode,
    AppVersion? appVersion,
    double? minWithdrawalAmount,
    double? maxWithdrawalAmount,
    double? pointsToRupeeRatio,
    int? referralBonus,
    String? updateMessage,
    Map<String, dynamic>? additionalSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      appVersion: appVersion ?? this.appVersion,
      minWithdrawalAmount: minWithdrawalAmount ?? this.minWithdrawalAmount,
      maxWithdrawalAmount: maxWithdrawalAmount ?? this.maxWithdrawalAmount,
      pointsToRupeeRatio: pointsToRupeeRatio ?? this.pointsToRupeeRatio,
      referralBonus: referralBonus ?? this.referralBonus,
      updateMessage: updateMessage ?? this.updateMessage,
      additionalSettings: additionalSettings ?? this.additionalSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AppVersion {
  final String version;
  final int buildNumber;
  final bool forceUpdate;
  final DateTime? lastUpdated;

  AppVersion({
    this.version = '1.0.0',
    this.buildNumber = 1,
    this.forceUpdate = false,
    this.lastUpdated,
  });

  factory AppVersion.fromMap(Map<String, dynamic> map) {
    return AppVersion(
      version: map['version'] ?? '1.0.0',
      buildNumber: map['buildNumber'] ?? 1,
      forceUpdate: map['forceUpdate'] ?? false,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'buildNumber': buildNumber,
      'forceUpdate': forceUpdate,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : FieldValue.serverTimestamp(),
    };
  }

  AppVersion copyWith({
    String? version,
    int? buildNumber,
    bool? forceUpdate,
    DateTime? lastUpdated,
  }) {
    return AppVersion(
      version: version ?? this.version,
      buildNumber: buildNumber ?? this.buildNumber,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
} 