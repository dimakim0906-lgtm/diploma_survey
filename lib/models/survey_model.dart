import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyModel {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final String createdBy;
  final bool isActive;

  // ====== НОВЫЕ ПОЛЯ ======
  final int minAge;        // минимальный возраст (0 = без ограничений)
  final int maxAge;        // максимальный возраст (999 = без ограничений)
  final bool isPublic;     // можно ли проходить без авторизации
  final String shareToken; // уникальный токен для публичной ссылки
  final String category;   // категория опроса

  SurveyModel({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.createdBy,
    required this.isActive,
    this.minAge = 0,
    this.maxAge = 999,
    this.isPublic = false,
    this.shareToken = '',
    this.category = 'Общее',
  });

  factory SurveyModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return SurveyModel(
      id: documentId,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      isActive: data['isActive'] ?? false,
      minAge: data['minAge'] ?? 0,
      maxAge: data['maxAge'] ?? 999,
      isPublic: data['isPublic'] ?? false,
      shareToken: data['shareToken'] ?? '',
      category: data['category'] ?? 'Общее',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'isActive': isActive,
      'minAge': minAge,
      'maxAge': maxAge,
      'isPublic': isPublic,
      'shareToken': shareToken,
      'category': category,
    };
  }

  // Проверяет, может ли пользователь данного возраста пройти этот опрос
  bool isAgeAllowed(int userAge) {
    if (minAge == 0 && maxAge == 999) return true; // без ограничений
    return userAge >= minAge && userAge <= maxAge;
  }

  // Читаемое описание возрастного ограничения
  String get ageLabel {
    if (minAge == 0 && maxAge == 999) return 'Для всех';
    if (maxAge == 999) return 'От $minAge лет';
    if (minAge == 0) return 'До $maxAge лет';
    return '$minAge–$maxAge лет';
  }
}