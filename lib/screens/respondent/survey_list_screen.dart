import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:diploma_survey/services/firestore_service.dart';
import 'package:diploma_survey/services/auth_service.dart';
import 'package:diploma_survey/models/survey_model.dart';
import 'package:diploma_survey/screens/respondent/take_survey_screen.dart';
import 'package:diploma_survey/screens/profile/edit_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SurveyListScreen extends StatefulWidget {
  const SurveyListScreen({super.key});

  @override
  State<SurveyListScreen> createState() => _SurveyListScreenState();
}

class _SurveyListScreenState extends State<SurveyListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  List<SurveyModel> _surveys = [];
  final Map<String, bool> _respondedStatus = {};
  bool _isLoading = true;
  int _userAge = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Загружаем возраст пользователя
    _userAge = await _authService.getCurrentUserAge();

    // Загружаем опросы с фильтром по возрасту
    final surveys =
        await _firestoreService.getActiveSurveysForAge(_userAge);

    // Проверяем, отвечал ли пользователь
    for (final survey in surveys) {
      final responded = await _firestoreService.hasUserResponded(
          survey.id, user.uid);
      _respondedStatus[survey.id] = responded;
    }

    if (mounted) {
      setState(() {
        _surveys = surveys;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final avatarLetter = (user?.displayName?.isNotEmpty == true
            ? user!.displayName![0]
            : user?.email?.isNotEmpty == true
                ? user!.email![0]
                : 'R')
        .toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Доступные опросы'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EditProfileScreen()),
                ).then((_) => setState(() {}));
              },
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF2E7D32),
                  child: Text(avatarLetter,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Выйти',
              onPressed: () async => FirebaseAuth.instance.signOut(),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _surveys.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _surveys.length,
                      itemBuilder: (context, index) =>
                          _buildSurveyCard(_surveys[index]),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Нет доступных опросов',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          if (_userAge > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Для вашего возраста ($_userAge лет) сейчас нет активных опросов',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSurveyCard(SurveyModel survey) {
    final responded = _respondedStatus[survey.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: responded ? Colors.green.shade300 : Colors.transparent,
          width: 1.5,
        ),
      ),
      color: responded ? Colors.green[50] : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: responded
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TakeSurveyScreen(surveyId: survey.id),
                  ),
                );
                _loadData();
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      survey.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: responded ? Colors.green[900] : Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    responded
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: responded ? Colors.green : Colors.grey,
                    size: 26,
                  ),
                ],
              ),
              if (survey.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(survey.description,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
              const SizedBox(height: 10),
              // Теги: категория + возраст
              Wrap(
                spacing: 6,
                children: [
                  _Tag(survey.category, Colors.blue),
                  if (survey.minAge != 0 || survey.maxAge != 999)
                    _Tag(survey.ageLabel, Colors.orange),
                  if (survey.isPublic)
                    _Tag('Публичный', Colors.purple),
                  if (responded)
                    _Tag('Пройдено', Colors.green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}