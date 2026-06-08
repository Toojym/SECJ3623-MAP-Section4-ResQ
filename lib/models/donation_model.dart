import 'package:cloud_firestore/cloud_firestore.dart';

class DonationModel {
  final String id;
  final String campaignId;
  final String campaignName;
  final String citizenId;
  final double amount;
  final String paymentMethod;
  final String receiptNo;
  final DateTime createdAt;

  DonationModel({
    required this.id,
    required this.campaignId,
    required this.campaignName,
    required this.citizenId,
    required this.amount,
    required this.paymentMethod,
    required this.receiptNo,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'campaignId': campaignId,
      'campaignName': campaignName,
      'citizenId': citizenId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'receiptNo': receiptNo,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory DonationModel.fromMap(String id, Map<String, dynamic> map) {
    return DonationModel(
      id: id,
      campaignId: map['campaignId'] as String? ?? '',
      campaignName: map['campaignName'] as String? ?? '',
      citizenId: map['citizenId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] as String? ?? '',
      receiptNo: map['receiptNo'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
