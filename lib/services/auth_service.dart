import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get userChanges => _auth.authStateChanges();

  // 🔹 Register user baru + simpan data ke Firestore
  Future<User?> register(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'role': 'farmer', // default role
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return user;
    } on FirebaseAuthException catch (e) {
      // Propagate the original auth exception so callers can inspect e.code
      rethrow;
    }
  }

  // 🔹 Login user
  Future<User?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // 🔹 Reset password dengan ActionCodeSettings (redirect ke GitHub Pages)
  Future<void> resetPassword(String email) async {
    try {
      final actionSettings = ActionCodeSettings(
        url: 'https://jessicaamelia17.github.io/chaos-app-pages/reset.html',
        handleCodeInApp: false,
      );
      await _auth.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: actionSettings,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // 🔹 Verifikasi kode reset password
  Future<String> verifyPasswordResetCode(String code) async {
    try {
      return await _auth.verifyPasswordResetCode(code);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // 🔹 Konfirmasi & ubah password menggunakan oobCode
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    try {
      await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // 🔹 Logout user
  Future<void> logout() async {
    await _auth.signOut();
  }

  // 🔹 Ubah password
  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User tidak ditemukan');
      }

      // Reauthenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // 🔹 Cek metode sign-in yang tersedia untuk email
  Future<List<String>?> getSignInMethodsForEmail(String email) async {
    try {
      return await _auth.fetchSignInMethodsForEmail(email);
    } on FirebaseAuthException catch (e) {
      // Jika error user-not-found, kembalikan list kosong bukan throw exception
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        return [];
      }
      throw Exception(e.message);
    }
  }
}
