import 'package:cloud_firestore/cloud_firestore.dart';

class ClaimModel {
  final String id;
  final String citizenId;
  final String citizenName;
  final String icNumber;
  final int householdSize;
  final String damageDescription;
  final String type;
  final String photoEvidence;
  final String location;
  final String
      status; // 'submitted', 'under_review', 'approved', 'disbursed', 'rejected', 'expired'
  final String? rejectReason;
  final String? infoRequestReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  // New fields
  final DateTime? infoDeadline;
  final String? outOfZoneReason;

  ClaimModel({
    required this.id,
    required this.citizenId,
    required this.citizenName,
    required this.icNumber,
    required this.householdSize,
    required this.damageDescription,
    required this.type,
    required this.photoEvidence,
    required this.location,
    required this.status,
    this.rejectReason,
    this.infoRequestReason,
    this.reviewedBy,
    this.reviewedAt,
    this.createdAt,
    this.infoDeadline,
    this.outOfZoneReason,
  });

  factory ClaimModel.fromMap(String id, Map<String, dynamic> data) {
    return ClaimModel(
      id: id,
      citizenId: data['citizenId'] ?? '',
      citizenName: data['citizenName'] ?? 'Awam',
      icNumber: data['icNumber'] ?? '-',
      householdSize: data['householdSize'] ?? 1,
      damageDescription: data['damageDescription'] ?? '-',
      type: data['type'] ?? 'Tuntutan Bantuan',
      photoEvidence: data['photoEvidence'] ??
          data['evidence'] ??
          'Tiada bukti', // Fallback to 'evidence' for old data
      location: data['location'] ?? 'Tidak diketahui',
      status: data['status'] ?? 'submitted',
      rejectReason: data['rejectReason'],
      infoRequestReason: data['infoRequestReason'] ?? data['officerFeedback'],
      reviewedBy: data['reviewedBy'],
      reviewedAt: data['reviewedAt'] != null
          ? (data['reviewedAt'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      infoDeadline: data['infoDeadline'] != null
          ? (data['infoDeadline'] as Timestamp).toDate()
          : null,
      outOfZoneReason: data['outOfZoneReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'citizenId': citizenId,
      'citizenName': citizenName,
      'icNumber': icNumber,
      'householdSize': householdSize,
      'damageDescription': damageDescription,
      'type': type,
      'photoEvidence': photoEvidence,
      'location': location,
      'status': status,
      'rejectReason': rejectReason,
      'infoRequestReason': infoRequestReason,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'infoDeadline':
          infoDeadline != null ? Timestamp.fromDate(infoDeadline!) : null,
      'outOfZoneReason': outOfZoneReason,
    };
  }
}
