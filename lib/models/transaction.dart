class PaymentTransaction {
  final String id;
  final String userId;
  final double amount;
  final String type;
  final String status;
  final String? upiId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PaymentTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.status,
    this.upiId,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'type': type,
      'status': status,
      'upiId': upiId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory PaymentTransaction.fromMap(Map<String, dynamic> map, String id) {
    return PaymentTransaction(
      id: id,
      userId: map['userId'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      status: map['status'] as String,
      upiId: map['upiId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
    );
  }
} 