import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:diploma_survey/services/auth_service.dart';
import 'package:diploma_survey/services/firestore_service.dart';
import 'package:diploma_survey/models/survey_model.dart';
import 'package:diploma_survey/screens/admin/create_survey_screen.dart';
import 'package:diploma_survey/screens/admin/survey_stats_screen.dart';
import 'package:diploma_survey/screens/admin/edit_survey_screen.dart';
import 'package:diploma_survey/screens/profile/edit_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  List<SurveyModel> _surveys = [];
  bool _isLoading = true;

  // Вкладки: Опросы / Логи
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSurveys();
    // Создаём дефолтные категории и возрастные группы при первом запуске
    _firestoreService.ensureDefaultCategories();
    _firestoreService.ensureDefaultAgeGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSurveys() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final surveys = await _firestoreService.getSurveysByUser(user.uid);
      if (mounted) setState(() {
        _surveys = surveys;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSurvey(SurveyModel survey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить опрос?'),
        content: Text('Удалить "${survey.title}"? Это необратимо.'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestoreService.logAction(
        userId: user.uid,
        action: 'delete_survey',
        details: 'Удалён опрос: ${survey.title}',
      );
    }

    final success = await _firestoreService.deleteSurvey(survey.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Опрос "${survey.title}" удалён')),
      );
      _loadSurveys();
    }
  }

  void _showShareLink(SurveyModel survey) {
    if (survey.shareToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('У этого опроса нет публичной ссылки')),
      );
      return;
    }
    // Ссылка формируется на основе токена
    final link =
        'https://diplomasurvey-cb0a5.web.app/survey/${survey.shareToken}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Публичная ссылка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Отправьте эту ссылку — опрос можно пройти без авторизации:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(link,
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Закрыть')),
          FilledButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Скопировать'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ссылка скопирована!')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final avatarLetter = (user?.displayName?.isNotEmpty == true
            ? user!.displayName![0]
            : user?.email?.isNotEmpty == true
                ? user!.email![0]
                : 'A')
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
          title: const Text('Панель администратора'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2E7D32),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF2E7D32),
            tabs: const [
              Tab(icon: Icon(Icons.poll_outlined), text: 'Опросы'),
              Tab(icon: Icon(Icons.history), text: 'Логи'),
            ],
          ),
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
              onPressed: () async => AuthService().signOut(),
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSurveysTab(),
            _buildLogsTab(),
          ],
        ),
      ),
    );
  }

  // ====== ВКЛАДКА ОПРОСЫ ======
  Widget _buildSurveysTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CreateSurveyScreen()),
                ).then((_) => _loadSurveys());
              },
              icon: const Icon(Icons.add),
              label: const Text('Создать новый опрос'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _surveys.isEmpty
                  ? const Center(
                      child: Text('Вы ещё не создали ни одного опроса',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      itemCount: _surveys.length,
                      itemBuilder: (context, index) =>
                          _buildSurveyTile(_surveys[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildSurveyTile(SurveyModel survey) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(survey.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                // Статус активен/неактивен
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: survey.isActive
                        ? Colors.green[100]
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    survey.isActive ? 'Активен' : 'Неактивен',
                    style: TextStyle(
                        fontSize: 11,
                        color: survey.isActive
                            ? Colors.green[900]
                            : Colors.grey[800]),
                  ),
                ),
              ],
            ),
            if (survey.description.isNotEmpty)
              Text(survey.description,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            // Теги
            Wrap(
              spacing: 4,
              children: [
                _SmallTag(survey.category, Colors.blue),
                _SmallTag(survey.ageLabel, Colors.orange),
                if (survey.isPublic) _SmallTag('Публичный 🔗', Colors.purple),
              ],
            ),
            // Кнопки действий
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (survey.isPublic)
                  IconButton(
                    icon: const Icon(Icons.link, color: Colors.purple),
                    tooltip: 'Скопировать ссылку',
                    onPressed: () => _showShareLink(survey),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'Редактировать',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              EditSurveyScreen(survey: survey)),
                    ).then((_) => _loadSurveys());
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.bar_chart, color: Color(0xFF2E7D32)),
                  tooltip: 'Статистика',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              SurveyStatsScreen(survey: survey)),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Удалить',
                  onPressed: () => _deleteSurvey(survey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ====== ВКЛАДКА ЛОГИ ======
  Widget _buildLogsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _firestoreService.getAuditLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return const Center(
              child: Text('Нет записей в журнале',
                  style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: logs.length,
          itemBuilder: (context, i) {
            final log = logs[i];
            final ts = (log['timestamp'] as dynamic)?.toDate();
            final dateStr = ts != null
                ? '${ts.day.toString().padLeft(2, '0')}.${ts.month.toString().padLeft(2, '0')}.${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}'
                : '—';
            final action = log['action'] as String? ?? '';
            final details = log['details'] as String? ?? '';

            IconData icon;
            Color color;
            if (action.contains('create')) {
              icon = Icons.add_circle_outline;
              color = Colors.green;
            } else if (action.contains('delete')) {
              icon = Icons.delete_outline;
              color = Colors.red;
            } else if (action.contains('register')) {
              icon = Icons.person_add_outlined;
              color = Colors.blue;
            } else {
              icon = Icons.info_outline;
              color = Colors.grey;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Text(details,
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(dateStr,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            );
          },
        );
      },
    );
  }
}

class _SmallTag extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallTag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color)),
    );
  }
}