import 'package:cloud_firestore/cloud_firestore.dart';

class WithdrawalTransaction {
  final String id;
  final String uid;
  final String upiId;
  final int amount;
  final int points;
  final String status;
  final DateTime timestamp;

  WithdrawalTransaction({
    required this.id,
    required this.uid,
    required this.upiId,
    required this.amount,
    required this.points,
    required this.status,
    required this.timestamp,
  });

  factory WithdrawalTransaction.fromMap(Map<String, dynamic> map, String id) {
    return WithdrawalTransaction(
      id: id,
      uid: map['uid'] as String,
      upiId: map['upiId'] as String,
      amount: map['amount'] as int,
      points: map['points'] as int,
      status: map['status'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'upiId': upiId,
      'amount': amount,
      'points': points,
      'status': status,
      'timestamp': timestamp,
    };
  }
} 