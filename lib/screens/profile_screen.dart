import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'profile_image_picker_dialog.dart';
// import 'reset_password_screen.dart';
import 'login_screen.dart';

// Widget to display a single password requirement row
class CriteriaRow extends StatelessWidget {
  final bool ok;
  final String text;

  const CriteriaRow({Key? key, required this.ok, required this.text})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF10B981) : Colors.redAccent;
    final icon = ok ? Icons.check_circle : Icons.close_rounded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _showChangePasswordDialog() async {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    String? errorMsg;
    bool oldPassVisible = false;
    bool newPassVisible = false;
    bool confirmPassVisible = false;
    bool showCriteria = false;
    bool hasMinLen = false;
    bool hasUpperLower = false;
    bool hasDigit = false;
    bool hasSymbol = false;

    List<String> _passwordIssues(String password) {
      final issues = <String>[];
      if (password.length < 8) {
        issues.add('• Minimal 8 karakter');
      }
      final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
      final hasLower = RegExp(r'[a-z]').hasMatch(password);
      if (!(hasUpper && hasLower)) {
        issues.add('• Harus mengandung huruf besar dan huruf kecil');
      }
      final digit = RegExp(r'\d').hasMatch(password);
      if (!digit) {
        issues.add('• Harus mengandung angka (0-9)');
      }
      final symbol = RegExp(
        r'[!@#\$%\^&*(),.?":{}|<>_\-\[\]\\/;]',
      ).hasMatch(password);
      if (!symbol) {
        issues.add('• Harus mengandung simbol (mis. !@#\$%^&*)');
      }
      return issues;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Ubah Kata Sandi'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPassController,
                  obscureText: !oldPassVisible,
                  decoration: InputDecoration(
                    labelText: 'Kata sandi lama',
                    suffixIcon: IconButton(
                      icon: Icon(
                        oldPassVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setStateDialog(
                        () => oldPassVisible = !oldPassVisible,
                      ),
                    ),
                  ),
                ),
                Focus(
                  onFocusChange: (focused) {
                    if (focused) setStateDialog(() => showCriteria = true);
                  },
                  child: TextField(
                    controller: newPassController,
                    obscureText: !newPassVisible,
                    decoration: InputDecoration(
                      labelText: 'Kata sandi baru',
                      suffixIcon: IconButton(
                        icon: Icon(
                          newPassVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setStateDialog(
                          () => newPassVisible = !newPassVisible,
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      setStateDialog(() {
                        showCriteria = true;
                        hasMinLen = v.length >= 8;
                        final up = RegExp(r'[A-Z]').hasMatch(v);
                        final low = RegExp(r'[a-z]').hasMatch(v);
                        hasUpperLower = up && low;
                        hasDigit = RegExp(r'\d').hasMatch(v);
                        hasSymbol = RegExp(
                          r'[!@#\$%\^&*(),.?":{}|<>_\-\[\]\\/;]',
                        ).hasMatch(v);
                      });
                    },
                  ),
                ),
                if (showCriteria || newPassController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  CriteriaRow(ok: hasMinLen, text: 'Minimal 8 karakter'),
                  CriteriaRow(
                    ok: hasUpperLower,
                    text: 'Harus mengandung huruf besar dan huruf kecil',
                  ),
                  CriteriaRow(
                    ok: hasDigit,
                    text: 'Harus mengandung angka (0-9)',
                  ),
                  CriteriaRow(
                    ok: hasSymbol,
                    text: 'Harus mengandung simbol (mis. !@#\$%^&*)',
                  ),
                ],
                TextField(
                  controller: confirmPassController,
                  obscureText: !confirmPassVisible,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi sandi baru',
                    suffixIcon: IconButton(
                      icon: Icon(
                        confirmPassVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setStateDialog(
                        () => confirmPassVisible = !confirmPassVisible,
                      ),
                    ),
                  ),
                ),
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () async {
                  final oldPass = oldPassController.text.trim();
                  final newPass = newPassController.text.trim();
                  final confirmPass = confirmPassController.text.trim();
                  setStateDialog(() => errorMsg = null);
                  if (oldPass.isEmpty ||
                      newPass.isEmpty ||
                      confirmPass.isEmpty) {
                    setStateDialog(() => errorMsg = 'Semua kolom wajib diisi');
                    return;
                  }
                  final issues = _passwordIssues(newPass);
                  if (issues.isNotEmpty) {
                    setStateDialog(
                      () => errorMsg =
                          'Password tidak valid:\n${issues.join('\n')}',
                    );
                    return;
                  }
                  if (newPass != confirmPass) {
                    setStateDialog(
                      () => errorMsg = 'Konfirmasi sandi tidak sama',
                    );
                    return;
                  }
                  try {
                    final cred = EmailAuthProvider.credential(
                      email: user!.email!,
                      password: oldPass,
                    );
                    await user.reauthenticateWithCredential(cred);
                    await user.updatePassword(newPass);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kata sandi berhasil diubah'),
                        ),
                      );
                    }
                  } on FirebaseAuthException catch (e) {
                    String msg = 'Gagal mengubah sandi';
                    if (e.code == 'wrong-password')
                      msg = 'Sandi lama salah';
                    else if (e.code == 'weak-password')
                      msg = 'Sandi baru terlalu lemah';
                    else if (e.code == 'requires-recent-login')
                      msg = 'Silakan login ulang dan coba lagi';
                    setStateDialog(() => errorMsg = msg);
                  } catch (e) {
                    setStateDialog(() => errorMsg = 'Terjadi kesalahan');
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _photoUrl;
  bool _uploading = false;

  static const List<String> jenisCabaiList = [
    'Cabai Rawit',
    'Dewata F1',
    'CRV 211',
    'Patra 3',
    'Mhanu XR',
    'Wartavi',
    'Bara',
    'Juwiring',
  ];

  // Ambil data user dari Firestore
  Future<Map<String, dynamic>?> _getUserData(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data();
  }

  // Edit field teks dan dropdown
  Future<void> _editProfileField(
    String field,
    String currentValue,
    String uid,
  ) async {
    if (field == 'jenisCabai') {
      String selectedValue = currentValue;

      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Pilih Varietas Cabai',
            style: TextStyle(
              color: Color(0xFF0B6623),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: StatefulBuilder(
            builder: (context, setStateDialog) => SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: jenisCabaiList.map((e) {
                        final bool isSelected = e == selectedValue;
                        return InkWell(
                          onTap: () => setStateDialog(() => selectedValue = e),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0B6623)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                if (isSelected) const SizedBox(width: 8),
                                Text(
                                  e,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selectedValue),
              child: const Text(
                'Simpan',
                style: TextStyle(
                  color: Color(0xFF0B6623),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      if (result != null && result != currentValue) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          field: result,
        });
        setState(() {});
      }
    } else {
      final controller = TextEditingController(text: currentValue);

      final result = await showDialog<String>(
        context: context,
        builder: (context) {
          String? localError;
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: Text('Edit $field'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: controller, autofocus: true),
                    if (localError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          localError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  TextButton(
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isEmpty) {
                        setStateDialog(
                          () => localError = 'Nama tidak boleh kosong',
                        );
                        return;
                      }
                      Navigator.pop(context, text);
                    },
                    child: const Text('Simpan'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != null && result.isNotEmpty && result != currentValue) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          field: result,
        });
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return user == null
        ? const Center(child: Text('Tidak ada user login'))
        : FutureBuilder<Map<String, dynamic>?>(
            future: _getUserData(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return const Center(child: Text('Data user tidak ditemukan'));
              }

              final data = snapshot.data!;
              final nama = data['nama'] ?? '-';
              final email = user.email ?? '-';

              // FIX membaca url dengan benar
              // Default profile image
              final defaultProfile = 'assets/images/profile.png';
              // Jika belum pernah memilih foto, gunakan gambar petani sebagai default
              String photoUrl = (_photoUrl ?? data['photoUrl']) ?? '';
              if (photoUrl.isEmpty) {
                photoUrl = defaultProfile;
              }

              return Scaffold(
                backgroundColor: const Color(0xFFE8F5E9),
                body: SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Profile - Style konsisten dengan History/Kontrol/Laporan/Pengaturan
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF1B5E20),
                                  const Color(0xFF2E7D32),
                                  const Color(0xFF4CAF50),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2E7D32,
                                  ).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Profil Pengguna',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Kelola informasi profil Anda',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.manage_accounts,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Foto Profil
                          Center(
                            child: Column(
                              children: [
                                _uploading
                                    ? Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.green.shade700,
                                              Colors.green.shade400,
                                              Colors.green.shade200,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.green.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 15,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                          ),
                                          padding: const EdgeInsets.all(3),
                                          child: const CircleAvatar(
                                            radius: 75,
                                            backgroundColor: Color(0xFFE0E0E0),
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF0B6623),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.green.shade700,
                                              Colors.green.shade400,
                                              Colors.green.shade200,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.green.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 15,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                          ),
                                          padding: const EdgeInsets.all(3),
                                          child: CircleAvatar(
                                            radius: 80,
                                            backgroundColor: const Color(
                                              0xFFE0E0E0,
                                            ),
                                            backgroundImage:
                                                photoUrl.startsWith('assets/')
                                                ? AssetImage(photoUrl)
                                                : NetworkImage(photoUrl)
                                                      as ImageProvider,
                                          ),
                                        ),
                                      ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _uploading
                                      ? null
                                      : () async {
                                          // Daftar gambar profile (sertakan yang sedang dipakai)
                                          final List<String> profileImages = [
                                            'assets/images/air.png',
                                            'assets/images/bupetani.png',
                                            'assets/images/Cabai.png',
                                            'assets/images/Matahari.png',
                                            'assets/images/pakpetani.png',
                                            'assets/images/Tanah.png',
                                            'assets/images/Tunas.png',
                                            'assets/images/Ulat.png',
                                          ];
                                          // Jika foto sekarang bukan salah satu pilihan dan bukan default, tambahkan di awal
                                          // Jika foto sekarang bukan salah satu pilihan, tambahkan di awal
                                          final currentPhoto = photoUrl;
                                          if (currentPhoto.isNotEmpty &&
                                              !profileImages.contains(
                                                currentPhoto,
                                              ) &&
                                              currentPhoto != defaultProfile) {
                                            profileImages.insert(
                                              0,
                                              currentPhoto,
                                            );
                                          }
                                          final selected =
                                              await showDialog<String>(
                                                context: context,
                                                builder: (context) =>
                                                    ProfileImagePickerDialog(
                                                      profileImages:
                                                          profileImages,
                                                      currentPhoto:
                                                          currentPhoto,
                                                      defaultProfile:
                                                          defaultProfile,
                                                    ),
                                              );
                                          if (selected != null &&
                                              selected != currentPhoto) {
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(user.uid)
                                                .set({
                                                  'photoUrl': selected,
                                                }, SetOptions(merge: true));
                                            setState(() {
                                              _photoUrl = selected;
                                            });
                                          }
                                        },
                                  child: const Text(
                                    "Pilih Gambar Profile",
                                    style: TextStyle(
                                      color: Color(0xFF0B6623),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Card Nama
                          _ProfileInfoCard(
                            icon: Icons.person,
                            title: "Nama",
                            value: nama,
                            onEdit: () =>
                                _editProfileField('nama', nama, user.uid),
                            cardColor: Colors.white,
                          ),

                          // Card Email
                          _ProfileInfoCard(
                            icon: Icons.email,
                            title: "Email",
                            value: email,
                            cardColor: Colors.white,
                            showEdit: false,
                          ),

                          const SizedBox(height: 16),

                          // Ubah Password
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
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
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0B6623,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFF0B6623),
                                  size: 24,
                                ),
                              ),
                              title: const Text(
                                "Ubah kata sandi",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0B6623,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Color(0xFF0B6623),
                                  size: 16,
                                ),
                              ),
                              onTap: _showChangePasswordDialog,
                            ),
                          ),

                          // Logout
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.logout,
                                  color: Colors.red,
                                  size: 24,
                                ),
                              ),
                              title: const Text(
                                "Keluar akun",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.red,
                                  size: 16,
                                ),
                              ),
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => Dialog(
                                    backgroundColor: const Color(0xFF0B6623),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 24,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.red,
                                            size: 40,
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            'Anda yakin ingin keluar dari akun?',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16.5,
                                            ),
                                          ),
                                          const SizedBox(height: 22),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                elevation: 0,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text(
                                                'Keluar',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFFE5E5E5,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                elevation: 0,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text(
                                                'Kembali',
                                                style: TextStyle(
                                                  color: Color(0xFF0B6623),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );

                                if (confirm == true) {
                                  await FirebaseAuth.instance.signOut();
                                  if (context.mounted) {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const LoginScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                }
                              },
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onEdit;
  final Color? cardColor;
  final bool showEdit;

  const _ProfileInfoCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    this.onEdit,
    this.cardColor,
    this.showEdit = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B6623).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF0B6623), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (showEdit)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0B6623).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.edit,
                    color: Color(0xFF0B6623),
                    size: 20,
                  ),
                  onPressed: onEdit,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
