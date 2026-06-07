import 'package:cloud_firestore/cloud_firestore.dart';

class ClaimModel {
  final String id;
  final String citizenId;
  final String citizenName;
  final String type;
  final String evidence;
  final String location;
  final String status; // 'pending', 'approved', 'info_requested', 'rejected'
  final String? rejectReason;
  final DateTime? createdAt;

  ClaimModel({
    required this.id,
    required this.citizenId,
    required this.citizenName,
    required this.type,
    required this.evidence,
    required this.location,
    required this.status,
    this.rejectReason,
    this.createdAt,
  });

  factory ClaimModel.fromMap(String id, Map<String, dynamic> data) {
    return ClaimModel(
      id: id,
      citizenId: data['citizenId'] ?? '',
      citizenName: data['citizenName'] ?? 'Awam',
      type: data['type'] ?? 'Tuntutan Bantuan',
      evidence: data['evidence'] ?? 'Tiada bukti',
      location: data['location'] ?? 'Tidak diketahui',
      status: data['status'] ?? 'pending',
      rejectReason: data['rejectReason'],
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'citizenId': citizenId,
      'citizenName': citizenName,
      'type': type,
      'evidence': evidence,
      'location': location,
      'status': status,
      'rejectReason': rejectReason,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
