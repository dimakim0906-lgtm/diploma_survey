import 'dart:io';
import 'package:flutter/material.dart';
import 'package:diploma_survey/services/firestore_service.dart';
import 'package:diploma_survey/models/survey_model.dart';
import 'package:diploma_survey/models/question_model.dart';
import 'package:diploma_survey/models/response_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
// Добавь этот импорт в самый верх файла
import 'package:flutter/foundation.dart' show kIsWeb;


// Если запускаешь на вебе — добавь ещё этот импорт:
// ignore: avoid_web_libraries_in_flutter
// Модель пользователя для кеша
class _UserInfo {
  final String email;
  final String name;
  _UserInfo({required this.email, required this.name});

  // Отображаемое имя: ник если есть, иначе часть email до @
  String get displayLabel {
    if (name.trim().isNotEmpty) return name.trim();
    return email.split('@').first;
  }
}

class SurveyStatsScreen extends StatefulWidget {
  final SurveyModel survey;
  const SurveyStatsScreen({super.key, required this.survey});

  @override
  State<SurveyStatsScreen> createState() => _SurveyStatsScreenState();
}

class _SurveyStatsScreenState extends State<SurveyStatsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Map<String, _UserInfo> _userCache = {};

  // Загружаем данные один раз в initState
  List<QuestionModel> _questions = [];
  List<ResponseModel> _responses = [];
  bool _isLoading = true;

  // Какой вопрос сейчас раскрыт в детальном просмотре
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _firestoreService.getQuestionsForSurvey(widget.survey.id),
      _firestoreService.getResponsesForSurvey(widget.survey.id),
    ]);

    final questions = results[0] as List<QuestionModel>;
    final responses = results[1] as List<ResponseModel>;

    // Загружаем инфо о всех пользователях параллельно
    await Future.wait(
      responses.map((r) => _getUserInfo(r.userId)),
    );

    if (!mounted) return;
    setState(() {
      _questions = questions;
      _responses = responses;
      _isLoading = false;
    });
  }

  Future<_UserInfo> _getUserInfo(String userId) async {
    if (_userCache.containsKey(userId)) return _userCache[userId]!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = doc.data() ?? {};
      final info = _UserInfo(
        email: data['email'] as String? ?? 'Неизвестно',
        name: data['name'] as String? ?? '',
      );
      _userCache[userId] = info;
      return info;
    } catch (_) {
      final info = _UserInfo(email: 'Ошибка', name: '');
      _userCache[userId] = info;
      return info;
    }
  }

  String _formatAnswer(dynamic answer, String type) {
    if (answer == null) return '—';
    if (type == 'multiple') return (answer as List).join(', ');
    if (type == 'scale') return '⭐ $answer / 5';
    return answer.toString();
  }

  // Считаем сколько раз выбран каждый вариант (для single/multiple/scale)
  Map<String, int> _getAnswerCounts(QuestionModel q) {
    final counts = <String, int>{};
    for (final r in _responses) {
      final answer = r.answers[q.id];
      if (answer == null) continue;
      if (q.type == 'multiple') {
        for (final opt in (answer as List)) {
          counts[opt.toString()] = (counts[opt.toString()] ?? 0) + 1;
        }
      } else {
        final key = answer.toString();
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  double _getAvgScale(QuestionModel q) {
    final values = _responses
        .map((r) => r.answers[q.id])
        .where((a) => a != null)
        .map((a) => (a as num).toDouble())
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  // ====== ЭКСПОРТ CSV ======
  Future<void> _exportToCsv() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Формируем CSV...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final buffer = StringBuffer();
      buffer.write('"Ник";"Email";"Дата ответа"');
      for (final q in _questions) {
        buffer.write(';"${q.text.replaceAll('"', '""')}"');
      }
      buffer.writeln();

      for (final response in _responses) {
        final info = _userCache[response.userId] ??
            _UserInfo(email: response.userId, name: '');
        final date =
            '${response.submittedAt.day.toString().padLeft(2, '0')}.${response.submittedAt.month.toString().padLeft(2, '0')}.${response.submittedAt.year}';

        buffer.write(';"${info.displayLabel}";"${info.email}";"$date"');
        for (final q in _questions) {
          final answer = _formatAnswer(response.answers[q.id], q.type)
              .replaceAll('"', '""');
         buffer.write(';\"$answer\"');
        }
        buffer.writeln();
      }

      final directory = await getTemporaryDirectory();
      final fileName =
          'survey_${widget.survey.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      final bom = [0xEF, 0xBB, 0xBF];
 await file.writeAsBytes([...bom, ...utf8.encode(buffer.toString())]);

      if (mounted) Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Статистика: ${widget.survey.title}',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка экспорта: $e'),
              backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          title: Text(
            widget.survey.title,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (!_isLoading && _responses.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Экспорт CSV',
                onPressed: _exportToCsv,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _responses.isEmpty
                ? _buildEmpty()
                : _buildContent(),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Text('Пока нет ответов',
              style: TextStyle(fontSize: 20, color: Colors.grey)),
          SizedBox(height: 8),
          Text('Здесь появится статистика после первых прохождений',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ====== КАРТОЧКА СВОДКИ ======
        _buildSummaryCard(),
        const SizedBox(height: 16),

        // ====== ЗАГОЛОВОК СЕКЦИИ ======
        Row(
          children: [
            const Icon(Icons.quiz_outlined, color: Color(0xFF2E7D32), size: 20),
            const SizedBox(width: 8),
            Text(
              'Вопросы (${_questions.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ====== КАРТОЧКИ ВОПРОСОВ ======
        ..._questions.asMap().entries.map((entry) {
          return _buildQuestionCard(entry.key, entry.value);
        }),

        const SizedBox(height: 16),

        // ====== СЕКЦИЯ РЕСПОНДЕНТОВ ======
        Row(
          children: [
            const Icon(Icons.people_outline,
                color: Color(0xFF2E7D32), size: 20),
            const SizedBox(width: 8),
            Text(
              'Все ответившие (${_responses.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildRespondentsList(),
      ],
    );
  }

  // ====== СВОДНАЯ КАРТОЧКА ======
  Widget _buildSummaryCard() {
    // Считаем среднее по всем scale-вопросам
    final scaleQuestions = _questions.where((q) => q.type == 'scale').toList();
    final double? overallAvg = scaleQuestions.isEmpty
        ? null
        : scaleQuestions.map(_getAvgScale).reduce((a, b) => a + b) /
            scaleQuestions.length;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Общая статистика',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Всего ответов
                Expanded(
                  child: _StatTile(
                    icon: Icons.assignment_turned_in_outlined,
                    value: '${_responses.length}',
                    label: 'ответов',
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                // Всего вопросов
                Expanded(
                  child: _StatTile(
                    icon: Icons.help_outline,
                    value: '${_questions.length}',
                    label: 'вопросов',
                    color: Colors.blue,
                  ),
                ),
                // Средняя оценка (если есть scale-вопросы)
                if (overallAvg != null)
                  Expanded(
                    child: _StatTile(
                      icon: Icons.star_outline,
                      value: overallAvg.toStringAsFixed(1),
                      label: 'ср. оценка',
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Кнопка экспорта внутри карточки
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _exportToCsv,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Экспортировать в CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====== КАРТОЧКА ВОПРОСА ======
  Widget _buildQuestionCard(int index, QuestionModel q) {
    final isExpanded = _expandedIndex == index;
    final answeredCount =
        _responses.where((r) => r.answers[q.id] != null).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Заголовок вопроса (всегда виден)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(
                () => _expandedIndex = isExpanded ? null : index),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Номер вопроса
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.text,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _TypeBadge(type: q.type),
                            const SizedBox(width: 8),
                            Text(
                              '$answeredCount из ${_responses.length} ответили',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // Агрегированная статистика (краткая, всегда видна)
          if (q.type == 'single' || q.type == 'multiple' || q.type == 'scale')
            _buildAggregatedStats(q),

          // Детальные ответы (разворачиваются)
          if (isExpanded) ...[
            const Divider(height: 1),
            _buildDetailedAnswers(q),
          ],
        ],
      ),
    );
  }

  // ====== АГРЕГИРОВАННАЯ СТАТИСТИКА (диаграмма выборов) ======
  Widget _buildAggregatedStats(QuestionModel q) {
    if (q.type == 'scale') {
      // Для scale — средняя оценка + звёздочки
      final avg = _getAvgScale(q);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.star, color: Colors.orange, size: 28),
              const SizedBox(width: 10),
              Text(
                avg.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const Text(
                ' / 5',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              // Визуальные звёзды
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < avg.round() ? Icons.star : Icons.star_border,
                    color: Colors.orange,
                    size: 18,
                  );
                }),
              ),
            ],
          ),
        ),
      );
    }

    // Для single/multiple — горизонтальные бары
    final counts = _getAnswerCounts(q);
    final options = q.options.isEmpty ? counts.keys.toList() : q.options;
    final maxCount =
        counts.values.isEmpty ? 1 : counts.values.reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: options.map((opt) {
          final count = counts[opt] ?? 0;
          final percent =
              _responses.isEmpty ? 0.0 : count / _responses.length;
          final barWidth = maxCount == 0 ? 0.0 : count / maxCount;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // Текст варианта
                SizedBox(
                  width: 120,
                  child: Text(
                    opt,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Бар
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: barWidth.toDouble(),
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Число и процент
                SizedBox(
                  width: 52,
                  child: Text(
                    '$count (${(percent * 100).toInt()}%)',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ====== ДЕТАЛЬНЫЕ ОТВЕТЫ КАЖДОГО ПОЛЬЗОВАТЕЛЯ ======
  Widget _buildDetailedAnswers(QuestionModel q) {
    final respondents = _responses
        .where((r) => r.answers[q.id] != null)
        .toList();

    if (respondents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Нет ответов на этот вопрос',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: respondents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final response = respondents[i];
        final info = _userCache[response.userId] ??
            _UserInfo(email: response.userId, name: '');
        final answer = _formatAnswer(response.answers[q.id], q.type);
        final date =
            '${response.submittedAt.day.toString().padLeft(2, '0')}.${response.submittedAt.month.toString().padLeft(2, '0')}.${response.submittedAt.year}';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Аватар с инициалом
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    const Color(0xFF2E7D32).withOpacity(0.15),
                child: Text(
                  info.displayLabel.isNotEmpty
                      ? info.displayLabel[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Имя + email + дата
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ник (жирным) и email
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            info.displayLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          date,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    if (info.name.trim().isNotEmpty)
                      Text(
                        info.email,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    // Сам ответ
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        answer,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ====== СПИСОК ВСЕХ РЕСПОНДЕНТОВ ======
  Widget _buildRespondentsList() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _responses.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, i) {
          final response = _responses[i];
          final info = _userCache[response.userId] ??
              _UserInfo(email: response.userId, name: '');
          final answeredQ =
              _questions.where((q) => response.answers[q.id] != null).length;
          final date =
              '${response.submittedAt.day.toString().padLeft(2, '0')}.${response.submittedAt.month.toString().padLeft(2, '0')}.${response.submittedAt.year}';

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor:
                  const Color(0xFF2E7D32).withOpacity(0.15),
              child: Text(
                info.displayLabel.isNotEmpty
                    ? info.displayLabel[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    info.displayLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$answeredQ/${_questions.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info.name.trim().isNotEmpty)
                  Text(info.email,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  'Прошёл: $date',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ====== ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ======

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  static const _labels = {
    'text': ('Текст', Colors.blue),
    'single': ('Один вариант', Colors.purple),
    'multiple': ('Несколько', Colors.teal),
    'scale': ('Оценка', Colors.orange),
  };

  @override
  Widget build(BuildContext context) {
    final info = _labels[type] ?? ('Иное', Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (info.$2 as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        info.$1 as String,
        style: TextStyle(
          fontSize: 11,
          color: info.$2 as Color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}