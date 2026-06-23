import 'package:flutter/material.dart';
import 'package:diploma_survey/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _currentEmail;
  String? _currentName;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Загружаем текущие данные из Firebase Auth
  void _loadCurrentData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentEmail = user.email;
        _currentName = user.displayName ?? '';
        _nameController.text = _currentName!;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await _authService.updateProfile(
      displayName: _nameController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Профиль успешно обновлён!'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
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
          title: const Text('Редактировать профиль'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: const Color(0xFF1F2937),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Аватар (инициалы пользователя)
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF2E7D32),
                  child: Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text[0].toUpperCase()
                        : (_currentEmail?.isNotEmpty == true
                            ? _currentEmail![0].toUpperCase()
                            : '?'),
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Карточка с полями
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Email (только для чтения)
                        const Text(
                          'Email (нельзя изменить)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.email_outlined,
                                  color: Colors.grey, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                _currentEmail ?? 'Нет email',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Поле имени (редактируемое)
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Отображаемое имя',
                            prefixIcon: Icon(Icons.person_outline),
                            helperText: 'Это имя будет видно в профиле',
                            errorBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(16)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 2),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(16)),
                              borderSide:
                                  BorderSide(color: Colors.red, width: 2),
                            ),
                          ),
                          onChanged: (_) => setState(() {}), // обновляем аватар
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Введите ваше имя';
                            }
                            if (value.trim().length < 2) {
                              return 'Имя слишком короткое (минимум 2 символа)';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Кнопка сохранения
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveProfile,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isLoading ? 'Сохраняем...' : 'Сохранить'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}