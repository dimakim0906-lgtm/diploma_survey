import 'package:flutter/material.dart';
import 'package:diploma_survey/services/firestore_service.dart';
import 'package:diploma_survey/models/question_model.dart';
import 'package:diploma_survey/models/response_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TakeSurveyScreen extends StatefulWidget {
  final String surveyId;
  const TakeSurveyScreen({super.key, required this.surveyId});

  @override
  State<TakeSurveyScreen> createState() => _TakeSurveyScreenState();
}

class _TakeSurveyScreenState extends State<TakeSurveyScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Map<String, dynamic> _answers = {};

  // Вопросы грузим один раз в initState — никаких FutureBuilder
  List<QuestionModel> _questions = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _alreadyResponded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Проверяем и загружаем вопросы параллельно
    final results = await Future.wait([
      _firestoreService.hasUserResponded(widget.surveyId, user.uid),
      _firestoreService.getQuestionsForSurvey(widget.surveyId),
    ]);

    if (!mounted) return;

    final responded = results[0] as bool;
    final questions = results[1] as List<QuestionModel>;

    setState(() {
      _alreadyResponded = responded;
      _questions = questions;
      _isLoading = false;
    });

    if (responded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Уже пройдено'),
            content: const Text(
                'Вы уже отвечали на этот опрос. Повторное прохождение невозможно.'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Ок'),
              ),
            ],
          ),
        ).then((_) => Navigator.pop(context));
      });
    }
  }

  int get _answeredCount {
    if (_questions.isEmpty) return 0;
    return _questions.where((q) {
      final answer = _answers[q.id];
      if (answer == null) return false;
      if (answer is String) return answer.trim().isNotEmpty;
      if (answer is List) return answer.isNotEmpty;
      return true;
    }).length;
  }

  double get _progressValue {
    if (_questions.isEmpty) return 0;
    return _answeredCount / _questions.length;
  }

  Future<void> _submitAnswers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    final response = ResponseModel(
      id: '',
      surveyId: widget.surveyId,
      userId: user.uid,
      answers: _answers,
      submittedAt: DateTime.now(),
    );

    final success = await _firestoreService.submitResponse(response);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Спасибо, ответы сохранены!'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при сохранении ответов')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_alreadyResponded) {
      return const Scaffold(
          body: Center(child: Text('Вы уже проходили этот опрос.')));
    }

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
          title: const Text('Прохождение опроса'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            // ====== ПРОГРЕСС-БАР ======
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Отвечено: $_answeredCount из ${_questions.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      Text(
                        '${(_progressValue * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progressValue,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ====== СПИСОК ВОПРОСОВ ======
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final q = _questions[index];
                  final isAnswered = () {
                    final answer = _answers[q.id];
                    if (answer == null) return false;
                    if (answer is String) return answer.trim().isNotEmpty;
                    if (answer is List) return answer.isNotEmpty;
                    return true;
                  }();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isAnswered
                            ? const Color(0xFF2E7D32)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isAnswered
                                      ? const Color(0xFF2E7D32)
                                      : Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: isAnswered
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 16)
                                      : Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  q.text,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInputForQuestion(q),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ====== КНОПКА ОТПРАВИТЬ ======
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitAnswers,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Отправить ответы'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputForQuestion(QuestionModel q) {
    final qid = q.id;
    switch (q.type) {
      case 'text':
        // Отдельный виджет — не триггерит перестройку всего экрана
        return _TextAnswer(
          initialValue: _answers[qid] as String? ?? '',
          onChanged: (val) {
            final wasPreviouslyAnswered =
                (_answers[qid] as String? ?? '').trim().isNotEmpty;
            final isNowAnswered = val.trim().isNotEmpty;

            // Обновляем ответ без setState — поле само управляет своим текстом
            _answers[qid] = val;

            // setState только когда статус "отвечено" МЕНЯЕТСЯ:
            // первый символ введён или поле полностью очищено
            if (wasPreviouslyAnswered != isNowAnswered) {
              setState(() {});
            }
          },
        );
      case 'scale':
        return Row(
          children: List.generate(5, (i) {
            final rating = i + 1;
            return Expanded(
              child: RadioListTile<int>(
                title: Text(rating.toString()),
                value: rating,
                groupValue: _answers[qid],
                onChanged: (val) => setState(() => _answers[qid] = val),
                activeColor: const Color(0xFF2E7D32),
                contentPadding: EdgeInsets.zero,
              ),
            );
          }),
        );
      case 'single':
        return Column(
          children: q.options.map((opt) {
            return RadioListTile<String>(
              title: Text(opt),
              value: opt,
              groupValue: _answers[qid],
              onChanged: (val) => setState(() => _answers[qid] = val),
              activeColor: const Color(0xFF2E7D32),
            );
          }).toList(),
        );
      case 'multiple':
        return Column(
          children: q.options.map((opt) {
            return CheckboxListTile(
              title: Text(opt),
              value: (_answers[qid] as List?)?.contains(opt) ?? false,
              onChanged: (checked) {
                setState(() {
                  final List<String> selected =
                      List.from(_answers[qid] ?? []);
                  if (checked == true) {
                    selected.add(opt);
                  } else {
                    selected.remove(opt);
                  }
                  _answers[qid] = selected;
                });
              },
              activeColor: const Color(0xFF2E7D32),
            );
          }).toList(),
        );
      default:
        return const Text('Неизвестный тип вопроса');
    }
  }
}

// ====== ОТДЕЛЬНЫЙ ВИДЖЕТ ДЛЯ ТЕКСТОВОГО ПОЛЯ ======
// Ключевая идея: у него свой State, поэтому при вводе текста
// перестраивается ТОЛЬКО это поле, а не весь экран с вопросами
class _TextAnswer extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _TextAnswer({required this.initialValue, required this.onChanged});

  @override
  State<_TextAnswer> createState() => _TextAnswerState();
}

class _TextAnswerState extends State<_TextAnswer> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(hintText: 'Введите ответ'),
      onChanged: widget.onChanged,
    );
  }
}