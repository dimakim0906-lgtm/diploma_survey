import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:diploma_survey/services/auth_service.dart';
import 'package:diploma_survey/screens/respondent/survey_list_screen.dart';
import 'package:diploma_survey/screens/admin/admin_panel_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  String? _role;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    User? user = _authService.getCurrentUser();
    if (user != null) {
      String? role = await _authService.getUserRole(user.uid);
      setState(() {
        _role = role;
        _loading = false;
      });
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_role == 'admin') {
      return const AdminPanelScreen();
    } else {
      return const SurveyListScreen();
    }
  }
}