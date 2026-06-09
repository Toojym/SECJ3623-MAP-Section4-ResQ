import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerTaskModel {
  final String id;
  final String squadName;
  final String zone;
  final String priority;
  final String status;
  final double progress;
  final String taskDescription;
  final String assignedVolunteer;
  final String eta;
  final String lastKnownLocation;
  final double? currentLat;
  final double? currentLng;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  VolunteerTaskModel({
    required this.id,
    required this.squadName,
    required this.zone,
    this.priority = 'Sederhana',
    required this.status,
    required this.progress,
    required this.taskDescription,
    this.assignedVolunteer = '',
    this.eta = '-',
    this.lastKnownLocation = '',
    this.currentLat,
    this.currentLng,
    this.createdAt,
    this.updatedAt,
  });

  factory VolunteerTaskModel.fromMap(String id, Map<String, dynamic> map) {
    return VolunteerTaskModel(
      id: id,
      squadName: map['squadName'] ?? '',
      zone: map['zone'] ?? '',
      priority: map['priority'] ?? 'Sederhana',
      status: map['status'] ?? 'Menuju ke Lokasi',
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      taskDescription: map['taskDescription'] ?? '',
      assignedVolunteer: map['assignedVolunteer'] ?? '',
      eta: map['eta'] ?? '-',
      lastKnownLocation: map['lastKnownLocation'] ?? '',
      currentLat: (map['currentLat'] as num?)?.toDouble(),
      currentLng: (map['currentLng'] as num?)?.toDouble(),
      createdAt: map['createdAt'] as Timestamp?,
      updatedAt: map['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'squadName': squadName,
      'zone': zone,
      'priority': priority,
      'status': status,
      'progress': progress,
      'taskDescription': taskDescription,
      'assignedVolunteer': assignedVolunteer,
      'eta': eta,
      'lastKnownLocation': lastKnownLocation,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt,
    };
  }
}
