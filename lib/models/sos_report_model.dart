import 'package:cloud_firestore/cloud_firestore.dart';

class SosReportModel {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reporterPhone;
  final String type;
  final String description;
  final String urgency;
  final String status;
  final double latitude;
  final double longitude;
  final String address;
  final List<String> requiredSkills;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? responderId;
  final String? responderName;
  final DateTime? respondedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;

  const SosReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    this.reporterPhone = '',
    required this.type,
    this.description = '',
    required this.urgency,
    this.status = 'active',
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.requiredSkills = const [],
    this.createdAt,
    this.updatedAt,
    this.responderId,
    this.responderName,
    this.respondedAt,
    this.cancelledAt,
    this.cancelReason,
  });

  // ── Status Constants ─────────────────────────────────────────────────────

  static const String statusActive = 'active';
  static const String statusResponded = 'responded';
  static const String statusResolved = 'resolved';
  static const String statusCancelled = 'cancelled';

  // ── Urgency Constants ────────────────────────────────────────────────────

  static const String urgencyKritikal = 'KRITIKAL';
  static const String urgencyTinggi = 'TINGGI';
  static const String urgencySedang = 'SEDANG';
  static const String urgencyRendah = 'RENDAH';

  /// Returns numeric priority for sorting (lower = more urgent)
  int get urgencyPriority {
    switch (urgency) {
      case urgencyKritikal:
        return 0;
      case urgencyTinggi:
        return 1;
      case urgencySedang:
        return 2;
      case urgencyRendah:
        return 3;
      default:
        return 4;
    }
  }

  // ── Type → Urgency Mapping ───────────────────────────────────────────────

  static String urgencyForType(String type) {
    switch (type) {
      case 'Kebakaran':
      case 'Perubatan':
        return urgencyKritikal;
      case 'Banjir':
      case 'Tanah Runtuh':
        return urgencyTinggi;
      case 'Orang Hilang':
        return urgencySedang;
      default:
        return urgencySedang;
    }
  }

  // ── Type → Required Skills Mapping ───────────────────────────────────────

  static List<String> skillsForType(String type) {
    switch (type) {
      case 'Kebakaran':
        return ['Pemadam Kebakaran', 'Pertolongan Cemas'];
      case 'Banjir':
        return ['Pemandu Bot', 'Pengurusan Evakuasi'];
      case 'Perubatan':
        return ['Pertolongan Cemas', 'Jururawat Komuniti', 'Pengetua Perubatan'];
      case 'Tanah Runtuh':
        return ['Pengurusan Evakuasi', 'Pertolongan Cemas'];
      case 'Orang Hilang':
        return ['Pakar Komunikasi'];
      default:
        return [];
    }
  }

  // ── Serialization ────────────────────────────────────────────────────────

  factory SosReportModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SosReportModel(
      id: doc.id,
      reporterId: data['reporterId'] as String? ?? '',
      reporterName: data['reporterName'] as String? ?? '',
      reporterPhone: data['reporterPhone'] as String? ?? '',
      type: data['type'] as String? ?? '',
      description: data['description'] as String? ?? '',
      urgency: data['urgency'] as String? ?? urgencySedang,
      status: data['status'] as String? ?? statusActive,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      address: data['address'] as String? ?? '',
      requiredSkills: List<String>.from(data['requiredSkills'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      responderId: data['responderId'] as String?,
      responderName: data['responderName'] as String?,
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      cancelReason: data['cancelReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'reporterId': reporterId,
        'reporterName': reporterName,
        'reporterPhone': reporterPhone,
        'type': type,
        'description': description,
        'urgency': urgency,
        'status': status,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'requiredSkills': requiredSkills,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  SosReportModel copyWith({
    String? id,
    String? reporterId,
    String? reporterName,
    String? reporterPhone,
    String? type,
    String? description,
    String? urgency,
    String? status,
    double? latitude,
    double? longitude,
    String? address,
    List<String>? requiredSkills,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? responderId,
    String? responderName,
    DateTime? respondedAt,
    DateTime? cancelledAt,
    String? cancelReason,
  }) {
    return SosReportModel(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reporterPhone: reporterPhone ?? this.reporterPhone,
      type: type ?? this.type,
      description: description ?? this.description,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      responderId: responderId ?? this.responderId,
      responderName: responderName ?? this.responderName,
      respondedAt: respondedAt ?? this.respondedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
    );
  }
}
