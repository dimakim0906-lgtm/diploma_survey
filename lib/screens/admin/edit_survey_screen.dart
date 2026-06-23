import 'package:flutter/material.dart';
import 'package:diploma_survey/services/firestore_service.dart';
import 'package:diploma_survey/models/survey_model.dart';
import 'package:diploma_survey/models/question_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditSurveyScreen extends StatefulWidget {
  final SurveyModel survey;
  const EditSurveyScreen({super.key, required this.survey});

  @override
  State<EditSurveyScreen> createState() => _EditSurveyScreenState();
}

class _EditSurveyScreenState extends State<EditSurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late bool _isActive;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _editedQuestions = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.survey.title);
    _descriptionController = TextEditingController(text: widget.survey.description);
    _isActive = widget.survey.isActive;
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final questions = await _firestoreService.getQuestionsForSurvey(widget.survey.id);
    setState(() {
      for (var q in questions) {
        _editedQuestions.add({
          'id': q.id,
          'text': q.text,
          'type': q.type,
          'options': List<String>.from(q.options),
          'order': q.order,
          'isDeleted': false,
        });
      }
    });
  }

  void _addQuestion() {
    setState(() {
      _editedQuestions.add({
        'id': null,
        'text': '',
        'type': 'text',
        'options': <String>[],
        'order': _editedQuestions.length,
        'isDeleted': false,
      });
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      if (_editedQuestions[index]['id'] != null) {
        _editedQuestions[index]['isDeleted'] = true;
      } else {
        _editedQuestions.removeAt(index);
      }
    });
  }

  Future<void> _saveSurvey() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final surveyData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'isActive': _isActive,
    };
    final surveyUpdated = await _firestoreService.updateSurvey(widget.survey.id, surveyData);
    if (!surveyUpdated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при обновлении опроса')),
      );
      setState(() => _isLoading = false);
      return;
    }

    for (var q in _editedQuestions) {
      if (q['isDeleted'] == true) {
        await _firestoreService.deleteQuestion(q['id']);
      } else if (q['id'] == null) {
        final newQuestion = QuestionModel(
          id: '',
          surveyId: widget.survey.id,
          text: q['text'] ?? '',
          type: q['type'] ?? 'text',
          options: q['type'] == 'text' ? [] : List<String>.from(q['options'] ?? []),
          order: q['order'],
        );
        await _firestoreService.addQuestion(newQuestion);
      } else {
        final questionData = {
          'text': q['text'],
          'type': q['type'],
          'options': q['type'] == 'text' ? [] : q['options'],
          'order': q['order'],
        };
        await _firestoreService.updateQuestion(q['id'], questionData);
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Опрос обновлён!'),
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
          colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Редактировать опрос'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addQuestion,
            ),
          ],
        ),
        body: _editedQuestions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _titleController,
                                decoration: const InputDecoration(labelText: 'Название опроса'),
                                validator: (value) => value == null || value.isEmpty ? 'Введите название' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(labelText: 'Описание'),
                                maxLines: 3,
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                title: const Text('Активен (доступен для прохождения)'),
                                value: _isActive,
                                onChanged: (value) => setState(() => _isActive = value),
                                secondary: const Icon(Icons.toggle_on),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Вопросы:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._editedQuestions.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final q = entry.value;
                        if (q['isDeleted'] == true) return const SizedBox.shrink();
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: Colors.grey[50],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: q['text'],
                                        decoration: const InputDecoration(labelText: 'Текст вопроса'),
                                        onChanged: (val) => q['text'] = val,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _removeQuestion(idx),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: q['type'],
                                  decoration: const InputDecoration(labelText: 'Тип вопроса'),
                                  items: const [
                                    DropdownMenuItem(value: 'text', child: Text('Текстовый')),
                                    DropdownMenuItem(value: 'single', child: Text('Один из списка')),
                                    DropdownMenuItem(value: 'multiple', child: Text('Несколько из списка')),
                                    DropdownMenuItem(value: 'scale', child: Text('Оценка (1-5)')),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      q['type'] = val!;
                                      if (val == 'text' || val == 'scale') {
                                        q['options'] = [];
                                      } else {
                                        q['options'] = q['options'] ?? [''];
                                      }
                                    });
                                  },
                                ),
                                if (q['type'] == 'single' || q['type'] == 'multiple') ...[
                                  const SizedBox(height: 8),
                                  const Text('Варианты ответа:', style: TextStyle(fontWeight: FontWeight.w500)),
                                  ...List.generate(q['options'].length, (optIdx) {
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 8, top: 4),
                                      child: Row(
                                        children: [
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
                                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                                            onPressed: () {
                                              setState(() => q['options'].removeAt(optIdx));
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  TextButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Добавить вариант'),
                                    onPressed: () {
                                      setState(() => q['options'].add(''));
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveSurvey,
                        child: _isLoading ? const CircularProgressIndicator() : const Text('Сохранить изменения'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}