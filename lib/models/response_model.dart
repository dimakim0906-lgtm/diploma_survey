import 'package:cloud_firestore/cloud_firestore.dart';

class ResponseModel {
  final String id;
  final String surveyId;
  final String userId;
  final Map<String, dynamic> answers; // ключ: questionId, значение: ответ
  final DateTime submittedAt;

  ResponseModel({
    required this.id,
    required this.surveyId,
    required this.userId,
    required this.answers,
    required this.submittedAt,
  });

  factory ResponseModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return ResponseModel(
      id: documentId,
      surveyId: data['surveyId'] ?? '',
      userId: data['userId'] ?? '',
      answers: data['answers'] ?? {},
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'surveyId': surveyId,
      'userId': userId,
      'answers': answers,
      'submittedAt': Timestamp.fromDate(submittedAt),
    };
  }
}