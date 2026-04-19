// File: lib/features/logbook/models/log_model.dart
import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart';

// Bagian ini akan di-generate otomatis oleh build_runner
part 'log_model.g.dart';

@HiveType(typeId: 0)
class LogModel extends HiveObject {
  @HiveField(0)
  final String title;

  @HiveField(1)
  final String description;

  @HiveField(2)
  final String category;

  @HiveField(3)
  final String date;

  @HiveField(4)
  final String username;

  @HiveField(5)
  final String authorId; // ID pemilik catatan

  @HiveField(6)
  final String teamId; // ID kelompok (untuk collaborative filter)

  @HiveField(7)
  final bool isPublic; // true = bisa dilihat semua anggota tim

  @HiveField(8)
  final bool isSynced; // true = sudah tersinkron ke MongoDB Atlas

  // MongoDB ID (tidak perlu disimpan ke Hive, hanya untuk operasi cloud)
  final ObjectId? id;

  LogModel({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.date,
    required this.username,
    this.authorId = '',
    this.teamId = '',
    this.isPublic = false,
    this.isSynced = false,
  });

  // Konversi ke Map untuk MongoDB
  Map<String, dynamic> toMap() {
    return {
      '_id': id ?? ObjectId(),
      'title': title,
      'description': description,
      'category': category,
      'date': date,
      'username': username,
      'authorId': authorId,
      'teamId': teamId,
      'isPublic': isPublic,
      'isSynced': true, // saat ke cloud berarti sudah sync
    };
  }

  // Buat dari MongoDB document
  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      id: map['_id'] as ObjectId?,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'Umum',
      date: map['date'] ?? '',
      username: map['username'] ?? '',
      authorId: map['authorId'] ?? '',
      teamId: map['teamId'] ?? '',
      isPublic: map['isPublic'] ?? false,
      isSynced: true,
    );
  }

  // Copy dengan perubahan tertentu (immutable update)
  LogModel copyWith({
    ObjectId? id,
    String? title,
    String? description,
    String? category,
    String? date,
    String? username,
    String? authorId,
    String? teamId,
    bool? isPublic,
    bool? isSynced,
  }) {
    return LogModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      username: username ?? this.username,
      authorId: authorId ?? this.authorId,
      teamId: teamId ?? this.teamId,
      isPublic: isPublic ?? this.isPublic,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}