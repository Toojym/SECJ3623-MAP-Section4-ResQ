import 'package:cloud_firestore/cloud_firestore.dart';

class CampaignModel {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String purpose;
  final Map<String, double> allocations;
  final DateTime? createdAt;

  CampaignModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.purpose,
    required this.allocations,
    this.createdAt,
  });

  factory CampaignModel.fromMap(String id, Map<String, dynamic> data) {
    return CampaignModel(
      id: id,
      name: data['name'] ?? '',
      targetAmount: (data['targetAmount'] ?? 0).toDouble(),
      currentAmount: (data['currentAmount'] ?? 0).toDouble(),
      purpose: data['purpose'] ?? '',
      allocations: Map<String, double>.from(
          (data['allocations'] as Map<String, dynamic>?)?.map(
                (key, value) => MapEntry(key, (value as num).toDouble()),
              ) ??
              {}),
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'purpose': purpose,
      'allocations': allocations,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
