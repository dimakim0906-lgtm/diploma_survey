import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionModel {
  final String id;
  final String surveyId;
  final String text;
  final String type; // 'single', 'multiple', 'text', 'scale'
  final List<String> options; // для single/multiple
  final int order;

  QuestionModel({
    required this.id,
    required this.surveyId,
    required this.text,
    required this.type,
    required this.options,
    required this.order,
  });

  factory QuestionModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return QuestionModel(
      id: documentId,
      surveyId: data['surveyId'] ?? '',
      text: data['text'] ?? '',
      type: data['type'] ?? 'text',
      options: List<String>.from(data['options'] ?? []),
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'surveyId': surveyId,
      'text': text,
      'type': type,
      'options': options,
      'order': order,
    };
  }
}