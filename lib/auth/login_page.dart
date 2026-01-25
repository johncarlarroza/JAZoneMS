import 'package:flutter/material.dart';
import 'package:jazone_monitoring_dashboard/services/admin_session.dart';
import '../services/admin_login_service.dart';
import '../pages/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final nameController = TextEditingController();
  final passwordController = TextEditingController();

  String error = '';
  bool loading = false;

  Future<void> login() async {
    setState(() {
      loading = true;
      error = '';
    });

    final success = await AdminLoginService.login(
      nameController.text.trim(),
      passwordController.text.trim(),
    );

    if (!success) {
      setState(() {
        error = 'Invalid admin name or password';
        loading = false;
      });
      return;
    }

    AdminSession.isLoggedIn = true;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔹 Background Image
          SizedBox.expand(
            child: Image.asset('assets/jazone_bg.png', fit: BoxFit.cover),
          ),

          // 🔹 Centered Login Card (not bottom)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 400, // 👈 width limit
                ),
                child: Card(
                  color: Colors.white.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🔹 Username
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 🔹 Password
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 🔹 Login Button / Loader
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: loading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: login,
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                        ),

                        // 🔹 Error Message
                        if (error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              error,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
