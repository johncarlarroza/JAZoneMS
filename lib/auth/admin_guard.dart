import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminGuard extends StatelessWidget {
  final Widget child;
  const AdminGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseAuth.instance.currentUser!.getIdTokenResult(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isAdmin = snapshot.data!.claims?['admin'] == true;

        if (!isAdmin) {
          return const Scaffold(
            body: Center(child: Text('Unauthorized Access')),
          );
        }

        return child;
      },
    );
  }
}
