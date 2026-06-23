import 'dart:math';
import 'package:flutter/material.dart';
import 'package:diploma_survey/services/firestore_service.dart';
import 'package:diploma_survey/models/survey_model.dart';
import 'package:diploma_survey/models/question_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateSurveyScreen extends StatefulWidget {
  const CreateSurveyScreen({super.key});

  @override
  State<CreateSurveyScreen> createState() => _CreateSurveyScreenState();
}

class _CreateSurveyScreenState extends State<CreateSurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isActive = true;
  bool _isPublic = false; // публичная ссылка
  bool _isLoading = false;

  // Возрастные ограничения
  RangeValues _ageRange = const RangeValues(6, 100);
  bool _hasAgeLimit = false;

  // Категория
  String _selectedCategory = 'Общее';
  final List<String> _categories = [
    'Общее',
    'Образование',
    'Здоровье',
    'Технологии',
    'Спорт',
    'Культура',
    'Маркетинг',
    'Другое',
  ];

  final List<Map<String, dynamic>> _questions = [];
  final FirestoreService _firestoreService = FirestoreService();

  // Генерируем уникальный токен для публичной ссылки
  String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(12, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'text': '',
        'type': 'text',
        'options': <String>[],
      });
    });
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  Future<void> _createSurvey() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы один вопрос')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final newSurvey = SurveyModel(
      id: '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      createdAt: DateTime.now(),
      createdBy: user.uid,
      isActive: _isActive,
      minAge: _hasAgeLimit ? _ageRange.start.round() : 0,
      maxAge: _hasAgeLimit ? _ageRange.end.round() : 999,
      isPublic: _isPublic,
      shareToken: _isPublic ? _generateToken() : '',
      category: _selectedCategory,
    );

    final surveyId = await _firestoreService.createSurvey(newSurvey);
    if (surveyId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при создании опроса')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    // Сохраняем запись в коллекцию audit_logs
    await _firestoreService.logAction(
      userId: user.uid,
      action: 'create_survey',
      details: 'Создан опрос: ${_titleController.text.trim()}',
    );

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final question = QuestionModel(
        id: '',
        surveyId: surveyId,
        text: q['text'] ?? '',
        type: q['type'] ?? 'text',
        options: q['type'] == 'text' || q['type'] == 'scale'
            ? []
            : List<String>.from(q['options'] ?? []),
        order: i,
      );
      await _firestoreService.addQuestion(question);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Опрос создан!'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      Navigator.pop(context);
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
          title: const Text('Создать опрос'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Добавить вопрос',
              onPressed: _addQuestion,
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ====== ОСНОВНАЯ ИНФОРМАЦИЯ ======
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Основное',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleController,
                        decoration:
                            const InputDecoration(labelText: 'Название опроса'),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Введите название' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        decoration:
                            const InputDecoration(labelText: 'Описание'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),

                      // Категория
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration:
                            const InputDecoration(labelText: 'Категория'),
                        items: _categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCategory = v!),
                      ),
                      const SizedBox(height: 8),

                      SwitchListTile(
                        title: const Text('Активен'),
                        subtitle:
                            const Text('Доступен для прохождения сейчас'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        secondary: const Icon(Icons.toggle_on,
                            color: Color(0xFF2E7D32)),
                        activeColor: const Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ====== ВОЗРАСТНЫЕ ОГРАНИЧЕНИЯ ======
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        title: const Text('Возрастное ограничение',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text(
                            'Опрос будет виден только нужной возрастной группе'),
                        value: _hasAgeLimit,
                        onChanged: (v) => setState(() => _hasAgeLimit = v),
                        secondary: const Icon(Icons.people_outline,
                            color: Color(0xFF2E7D32)),
                        activeColor: const Color(0xFF2E7D32),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_hasAgeLimit) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'От ${_ageRange.start.round()} лет',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'До ${_ageRange.end.round()} лет',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32)),
                              ),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: _ageRange,
                          min: 6,
                          max: 100,
                          divisions: 94,
                          activeColor: const Color(0xFF2E7D32),
                          labels: RangeLabels(
                            '${_ageRange.start.round()}',
                            '${_ageRange.end.round()}',
                          ),
                          onChanged: (v) => setState(() => _ageRange = v),
                        ),
                        // Быстрый выбор популярных диапазонов
                        const Text('Быстрый выбор:',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            _AgeChip('6–11', () => setState(() => _ageRange = const RangeValues(6, 11))),
                            _AgeChip('12–14', () => setState(() => _ageRange = const RangeValues(12, 14))),
                            _AgeChip('14–16', () => setState(() => _ageRange = const RangeValues(14, 16))),
                            _AgeChip('16–18', () => setState(() => _ageRange = const RangeValues(16, 18))),
                            _AgeChip('18+', () => setState(() => _ageRange = const RangeValues(18, 100))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ====== ПУБЛИЧНАЯ ССЫЛКА ======
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        title: const Text('Публичная ссылка',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text(
                            'Опрос можно пройти по ссылке без авторизации'),
                        value: _isPublic,
                        onChanged: (v) => setState(() => _isPublic = v),
                        secondary: const Icon(Icons.link,
                            color: Color(0xFF2E7D32)),
                        activeColor: const Color(0xFF2E7D32),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_isPublic)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.blue.withOpacity(0.2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'После создания ссылка появится в панели администратора',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ====== ВОПРОСЫ ======
              Row(
                children: [
                  const Text('Вопросы',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить'),
                    onPressed: _addQuestion,
                  ),
                ],
              ),
              if (_questions.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.grey.shade200, style: BorderStyle.solid),
                  ),
                  child: const Center(
                    child: Text('Нажмите «Добавить» чтобы добавить вопрос',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ..._questions.asMap().entries.map((entry) {
                final idx = entry.key;
                final q = entry.value;
                return _buildQuestionCard(idx, q);
              }),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _createSurvey,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Создать опрос'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int idx, Map<String, dynamic> q) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${idx + 1}',
                        style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: q['text'],
                    decoration:
                        const InputDecoration(labelText: 'Текст вопроса'),
                    onChanged: (val) => q['text'] = val,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Введите вопрос' : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeQuestion(idx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: q['type'],
              decoration: const InputDecoration(labelText: 'Тип ответа'),
              items: const [
                DropdownMenuItem(value: 'text', child: Text('📝 Текстовый')),
                DropdownMenuItem(
                    value: 'single', child: Text('🔘 Один из списка')),
                DropdownMenuItem(
                    value: 'multiple', child: Text('☑️ Несколько из списка')),
                DropdownMenuItem(
                    value: 'scale', child: Text('⭐ Оценка (1–5)')),
              ],
              onChanged: (val) {
                setState(() {
                  q['type'] = val!;
                  if (val == 'text' || val == 'scale') {
                    q['options'] = [];
                  } else {
                    q['options'] = q['options']?.isNotEmpty == true
                        ? q['options']
                        : [''];
                  }
                });
              },
            ),
            if (q['type'] == 'single' || q['type'] == 'multiple') ...[
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Варианты ответа:',
                    style: TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13)),
              ),
              ...List.generate(q['options'].length, (optIdx) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_handle,
                          color: Colors.grey, size: 20),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextFormField(
                          initialValue: q['options'][optIdx],
                          decoration: InputDecoration(
                            hintText: 'Вариант ${optIdx + 1}',
                          ),
                          onChanged: (val) => q['options'][optIdx] = val,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.red, size: 20),
                        onPressed: () =>
                            setState(() => q['options'].removeAt(optIdx)),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить вариант'),
                onPressed: () => setState(() => q['options'].add('')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Виджет для быстрого выбора возрастного диапазона
class _AgeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AgeChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32))),
      backgroundColor: const Color(0xFF2E7D32).withOpacity(0.08),
      side: const BorderSide(color: Color(0xFF2E7D32), width: 0.5),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}