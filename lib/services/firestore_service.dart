import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diploma_survey/models/survey_model.dart';
import 'package:diploma_survey/models/question_model.dart';
import 'package:diploma_survey/models/response_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== КОЛЛЕКЦИЯ 1: surveys ====================

  Future<List<SurveyModel>> getActiveSurveys() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('surveys')
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => SurveyModel.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Ошибка загрузки опросов: $e');
      return [];
    }
  }

  // Загружаем активные опросы с фильтром по возрасту пользователя
  Future<List<SurveyModel>> getActiveSurveysForAge(int userAge) async {
    try {
      final all = await getActiveSurveys();
      if (userAge == 0) return all; // возраст неизвестен — показываем все
      return all.where((s) => s.isAgeAllowed(userAge)).toList();
    } catch (e) {
      print('Ошибка фильтрации по возрасту: $e');
      return [];
    }
  }

  Future<List<SurveyModel>> getSurveysByUser(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('surveys')
          .where('createdBy', isEqualTo: userId)
          .get();
      return snapshot.docs
          .map((doc) => SurveyModel.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Ошибка загрузки опросов пользователя: $e');
      return [];
    }
  }

  // Найти опрос по публичному токену (для ссылки без авторизации)
  Future<SurveyModel?> getSurveyByToken(String token) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('surveys')
          .where('shareToken', isEqualTo: token)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return SurveyModel.fromFirestore(
          doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      print('Ошибка поиска по токену: $e');
      return null;
    }
  }

  Future<String?> createSurvey(SurveyModel survey) async {
    try {
      DocumentReference docRef =
          await _firestore.collection('surveys').add(survey.toFirestore());

      // Если у опроса есть токен — сохраняем в коллекцию shared_links
      if (survey.shareToken.isNotEmpty) {
        await _firestore.collection('shared_links').add({
          'surveyId': docRef.id,
          'token': survey.shareToken,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': survey.createdBy,
          'surveyTitle': survey.title,
          'isActive': true,
        });
      }

      return docRef.id;
    } catch (e) {
      print('Ошибка создания опроса: $e');
      return null;
    }
  }

  Future<bool> updateSurvey(String surveyId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('surveys').doc(surveyId).update(data);
      return true;
    } catch (e) {
      print('Ошибка обновления опроса: $e');
      return false;
    }
  }

  Future<bool> deleteSurvey(String surveyId) async {
    try {
      // Удаляем вопросы
      QuerySnapshot questions = await _firestore
          .collection('questions')
          .where('surveyId', isEqualTo: surveyId)
          .get();
      for (var doc in questions.docs) {
        await doc.reference.delete();
      }
      // Удаляем ответы
      QuerySnapshot responses = await _firestore
          .collection('responses')
          .where('surveyId', isEqualTo: surveyId)
          .get();
      for (var doc in responses.docs) {
        await doc.reference.delete();
      }
      // Удаляем из shared_links если есть
      QuerySnapshot links = await _firestore
          .collection('shared_links')
          .where('surveyId', isEqualTo: surveyId)
          .get();
      for (var doc in links.docs) {
        await doc.reference.delete();
      }
      // Удаляем сам опрос
      await _firestore.collection('surveys').doc(surveyId).delete();
      return true;
    } catch (e) {
      print('Ошибка удаления опроса: $e');
      return false;
    }
  }

  // ==================== КОЛЛЕКЦИЯ 2: questions ====================

  Future<List<QuestionModel>> getQuestionsForSurvey(String surveyId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('questions')
          .where('surveyId', isEqualTo: surveyId)
          .orderBy('order')
          .get();
      return snapshot.docs
          .map((doc) => QuestionModel.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Ошибка загрузки вопросов: $e');
      return [];
    }
  }

  Future<String?> addQuestion(QuestionModel question) async {
    try {
      DocumentReference docRef =
          await _firestore.collection('questions').add(question.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Ошибка добавления вопроса: $e');
      return null;
    }
  }

  Future<bool> updateQuestion(
      String questionId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('questions').doc(questionId).update(data);
      return true;
    } catch (e) {
      print('Ошибка обновления вопроса: $e');
      return false;
    }
  }

  Future<bool> deleteQuestion(String questionId) async {
    try {
      await _firestore.collection('questions').doc(questionId).delete();
      return true;
    } catch (e) {
      print('Ошибка удаления вопроса: $e');
      return false;
    }
  }

  // ==================== КОЛЛЕКЦИЯ 3: responses ====================

  Future<bool> submitResponse(ResponseModel response) async {
    try {
      await _firestore.collection('responses').add(response.toFirestore());
      return true;
    } catch (e) {
      print('Ошибка сохранения ответа: $e');
      return false;
    }
  }

  Future<List<ResponseModel>> getResponsesForSurvey(String surveyId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('responses')
          .where('surveyId', isEqualTo: surveyId)
          .get();
      return snapshot.docs
          .map((doc) => ResponseModel.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Ошибка загрузки ответов: $e');
      return [];
    }
  }

  Future<bool> hasUserResponded(String surveyId, String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('responses')
          .where('surveyId', isEqualTo: surveyId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Ошибка проверки ответа: $e');
      return false;
    }
  }

  // ==================== КОЛЛЕКЦИЯ 4: users ====================

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc =
          await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // ==================== КОЛЛЕКЦИЯ 5: categories ====================

  Future<List<String>> getCategories() async {
    try {
      QuerySnapshot snapshot =
          await _firestore.collection('categories').get();
      return snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String)
          .toList();
    } catch (e) {
      // Возвращаем дефолтные если коллекция пуста
      return ['Общее', 'Образование', 'Здоровье', 'Технологии', 'Спорт'];
    }
  }

  Future<void> ensureDefaultCategories() async {
    final defaults = [
      'Общее', 'Образование', 'Здоровье',
      'Технологии', 'Спорт', 'Культура', 'Маркетинг', 'Другое'
    ];
    final snapshot = await _firestore.collection('categories').get();
    if (snapshot.docs.isEmpty) {
      for (final cat in defaults) {
        await _firestore.collection('categories').add({
          'name': cat,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // ==================== КОЛЛЕКЦИЯ 6: age_groups ====================

  Future<void> ensureDefaultAgeGroups() async {
    final snapshot = await _firestore.collection('age_groups').get();
    if (snapshot.docs.isEmpty) {
      final groups = [
        {'label': 'Дети (6–11)', 'minAge': 6, 'maxAge': 11},
        {'label': 'Подростки (12–14)', 'minAge': 12, 'maxAge': 14},
        {'label': 'Старшие подростки (14–16)', 'minAge': 14, 'maxAge': 16},
        {'label': 'Молодёжь (16–18)', 'minAge': 16, 'maxAge': 18},
        {'label': 'Взрослые (18+)', 'minAge': 18, 'maxAge': 999},
        {'label': 'Средний возраст (30–50)', 'minAge': 30, 'maxAge': 50},
        {'label': 'Старший возраст (50+)', 'minAge': 50, 'maxAge': 999},
        {'label': 'Все возрасты', 'minAge': 0, 'maxAge': 999},
      ];
      for (final g in groups) {
        await _firestore.collection('age_groups').add({
          ...g,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> getAgeGroups() async {
    try {
      final snapshot = await _firestore.collection('age_groups').get();
      return snapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== КОЛЛЕКЦИЯ 7: shared_links ====================

  Future<List<Map<String, dynamic>>> getSharedLinks(String adminId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('shared_links')
          .where('createdBy', isEqualTo: adminId)
          .get();
      return snapshot.docs
          .map((doc) =>
              {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== КОЛЛЕКЦИЯ 8: audit_logs ====================

  Future<void> logAction({
    required String userId,
    required String action,
    required String details,
  }) async {
    try {
      await _firestore.collection('audit_logs').add({
        'userId': userId,
        'action': action,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Ошибка записи лога: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 50}) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) =>
              {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();
    } catch (e) {
      return [];
    }
  }
}