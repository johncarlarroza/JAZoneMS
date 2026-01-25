import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLoginService {
  static Future<bool> login(String name, String password) async {
    final query = await FirebaseFirestore.instance
        .collection('admin')
        .where('name', isEqualTo: name)
        .where('password', isEqualTo: password)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }
}
