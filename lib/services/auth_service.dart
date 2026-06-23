import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Пользователь с таким email не найден';
        case 'wrong-password':
          return 'Неверный пароль';
        case 'invalid-email':
          return 'Некорректный email';
        case 'invalid-credential':
          return 'Неверный email или пароль';
        default:
          return 'Ошибка входа: ${e.message}';
      }
    } catch (e) {
      return 'Произошла неизвестная ошибка';
    }
  }

  // ====== РЕГИСТРАЦИЯ — теперь принимает имя, год рождения и возраст ======
  Future<String?> signUp(
    String email,
    String password, {
    String name = '',
    int birthYear = 0,
    int age = 0,
  }) async {
    if (password.length < 6) {
      return 'Пароль должен содержать не менее 6 символов';
    }

    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Устанавливаем displayName сразу при регистрации
      if (name.isNotEmpty) {
        await userCredential.user?.updateDisplayName(name);
      }

      // Сохраняем в коллекцию users
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'email': email,
        'name': name,
        'role': 'respondent',
        'birthYear': birthYear,
        'age': age,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Записываем в audit_logs
      await _firestore.collection('audit_logs').add({
        'userId': userCredential.user!.uid,
        'action': 'register',
        'details': 'Зарегистрировался пользователь: $email',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Этот email уже зарегистрирован';
        case 'invalid-email':
          return 'Некорректный email';
        case 'weak-password':
          return 'Слишком слабый пароль';
        default:
          return 'Ошибка регистрации: ${e.message}';
      }
    } catch (e) {
      return 'Произошла неизвестная ошибка';
    }
  }

  // Обновление профиля
  Future<String?> updateProfile({required String displayName}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Пользователь не найден';

      await user.updateDisplayName(displayName);
      await _firestore.collection('users').doc(user.uid).update({
        'name': displayName,
      });

      return null;
    } on FirebaseAuthException catch (e) {
      return 'Ошибка обновления профиля: ${e.message}';
    } catch (e) {
      return 'Произошла ошибка: $e';
    }
  }

  // Получить возраст текущего пользователя из Firestore
  Future<int> getCurrentUserAge() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;
      final doc =
          await _firestore.collection('users').doc(user.uid).get();
      return doc.data()?['age'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> signOut() async => await _auth.signOut();

  User? getCurrentUser() => _auth.currentUser;

  Stream<User?> get user => _auth.authStateChanges();

  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.get('role') ?? 'respondent';
      }
    } catch (e) {
      print('Ошибка получения роли: $e');
    }
    return 'respondent';
  }
}