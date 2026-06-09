import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class IncidentModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String severity; // e.g., 'Kritikal', 'Sederhana', 'Rendah'
  final String type; // e.g., 'Banjir', 'Tanah Runtuh', 'Kecemasan Perubatan'
  final String status; // 'active', 'resolved'
  final DateTime reportedAt;
  final double latitude;
  final double longitude;

  const IncidentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.type,
    required this.status,
    required this.reportedAt,
    required this.latitude,
    required this.longitude,
  });

  factory IncidentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IncidentModel(
      id: doc.id,
      title: data['title'] as String? ?? 'Insiden Tanpa Tajuk',
      description: data['description'] as String? ?? '',
      severity: data['severity'] as String? ?? 'Sederhana',
      type: data['type'] as String? ?? 'Lain-lain',
      status: data['status'] as String? ?? 'active',
      reportedAt: (data['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'severity': severity,
      'type': type,
      'status': status,
      'reportedAt': Timestamp.fromDate(reportedAt),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  String get durationString {
    final diff = DateTime.now().difference(reportedAt);
    if (diff.inDays > 0) return '${diff.inDays} Hari';
    if (diff.inHours > 0) return '${diff.inHours} Jam';
    if (diff.inMinutes > 0) return '${diff.inMinutes} Minit';
    return 'Baru Sahaja';
  }

  @override
  List<Object?> get props => [
        id, title, description, severity, type, status, reportedAt, latitude, longitude
      ];
}