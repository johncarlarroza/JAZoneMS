import 'package:flutter/material.dart';
import '../services/admin_session.dart';
import 'login_page.dart';
import '../pages/dashboard_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminSession.isLoggedIn ? const DashboardPage() : const LoginPage();
  }
}
