import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerTaskModel {
  final String id;
  final String squadName;
  final String zone;
  final String status;
  final double progress;
  final String taskDescription;
  final Timestamp? createdAt;

  VolunteerTaskModel({
    required this.id,
    required this.squadName,
    required this.zone,
    required this.status,
    required this.progress,
    required this.taskDescription,
    this.createdAt,
  });

  factory VolunteerTaskModel.fromMap(String id, Map<String, dynamic> map) {
    return VolunteerTaskModel(
      id: id,
      squadName: map['squadName'] ?? '',
      zone: map['zone'] ?? '',
      status: map['status'] ?? 'Menuju ke Lokasi',
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      taskDescription: map['taskDescription'] ?? '',
      createdAt: map['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'squadName': squadName,
      'zone': zone,
      'status': status,
      'progress': progress,
      'taskDescription': taskDescription,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
