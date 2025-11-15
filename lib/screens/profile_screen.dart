import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/app_scaffold.dart';
import 'profile_image_picker_dialog.dart';
// import 'reset_password_screen.dart';
import 'login_screen.dart';

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
                        icon: Icon(oldPassVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setStateDialog(() => oldPassVisible = !oldPassVisible),
                      ),
                    ),
                  ),
                  TextField(
                    controller: newPassController,
                    obscureText: !newPassVisible,
                    decoration: InputDecoration(
                      labelText: 'Kata sandi baru',
                      suffixIcon: IconButton(
                        icon: Icon(newPassVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setStateDialog(() => newPassVisible = !newPassVisible),
                      ),
                    ),
                  ),
                  TextField(
                    controller: confirmPassController,
                    obscureText: !confirmPassVisible,
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi sandi baru',
                      suffixIcon: IconButton(
                        icon: Icon(confirmPassVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setStateDialog(() => confirmPassVisible = !confirmPassVisible),
                      ),
                    ),
                  ),
                  if (errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
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
                    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                      setStateDialog(() => errorMsg = 'Semua kolom wajib diisi');
                      return;
                    }
                    if (newPass.length < 6) {
                      setStateDialog(() => errorMsg = 'Sandi baru minimal 6 karakter');
                      return;
                    }
                    if (newPass != confirmPass) {
                      setStateDialog(() => errorMsg = 'Konfirmasi sandi tidak sama');
                      return;
                    }
                    try {
                      final cred = EmailAuthProvider.credential(email: user!.email!, password: oldPass);
                      await user.reauthenticateWithCredential(cred);
                      await user.updatePassword(newPass);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kata sandi berhasil diubah')));
                      }
                    } on FirebaseAuthException catch (e) {
                      String msg = 'Gagal mengubah sandi';
                      if (e.code == 'wrong-password') msg = 'Sandi lama salah';
                      else if (e.code == 'weak-password') msg = 'Sandi baru terlalu lemah';
                      else if (e.code == 'requires-recent-login') msg = 'Silakan login ulang dan coba lagi';
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
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data();
  }


  // Edit field teks dan dropdown
  Future<void> _editProfileField(String field, String currentValue, String uid) async {
    if (field == 'jenisCabai') {
      String selectedValue = currentValue;

      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2B2B2B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Dropdown Varietas', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w400, fontSize: 16)),
          content: StatefulBuilder(
            builder: (context, setStateDialog) => Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5E5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    child: Column(
                      children: jenisCabaiList.map((e) {
                        final bool isSelected = e == selectedValue;
                        return GestureDetector(
                          onTap: () => setStateDialog(() => selectedValue = e),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF5B776B) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                if (isSelected)
                                  const Icon(Icons.check, color: Colors.white, size: 18),
                                if (isSelected) const SizedBox(width: 8),
                                Text(
                                  e,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFF0B6623),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 15,
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
              child: const Text('Batal', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selectedValue),
              child: const Text('Simpan', style: TextStyle(color: Color(0xFF5B776B), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (result != null && result != currentValue) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({field: result});
        setState(() {});
      }

    } else {
      final controller = TextEditingController(text: currentValue);

      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Edit $field'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Simpan')),
          ],
        ),
      );

      if (result != null && result.isNotEmpty && result != currentValue) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({field: result});
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return AppScaffold(
      currentIndex: 4,
      body: user == null
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

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      const Text(
                        'Profile Pengguna',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B6623),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Foto Profil 
                      Center(
                        child: Column(
                          children: [
                            _uploading
                                ? Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const CircleAvatar(
                                      radius: 60,
                                      backgroundColor: Color(0xFFE0E0E0),
                                      child: CircularProgressIndicator(color: Colors.white),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 60,
                                      backgroundColor: const Color(0xFFE0E0E0),
                                        backgroundImage: photoUrl.startsWith('assets/')
                                          ? AssetImage(photoUrl)
                                          : NetworkImage(photoUrl) as ImageProvider,
                                    ),
                                  ),
                            const SizedBox(height: 8),
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
                                          !profileImages.contains(currentPhoto) &&
                                          currentPhoto != defaultProfile) {
                                        profileImages.insert(0, currentPhoto);
                                      }
                                      final selected = await showDialog<String>(
                                        context: context,
                                        builder: (context) => ProfileImagePickerDialog(
                                          profileImages: profileImages,
                                          currentPhoto: currentPhoto,
                                          defaultProfile: defaultProfile,
                                        ),
                                      );
                                      if (selected != null && selected != currentPhoto) {
                                        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
                                          {'photoUrl': selected},
                                          SetOptions(merge: true),
                                        );
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
                        onEdit: () => _editProfileField('nama', nama, user.uid),
                        cardColor: Colors.white,
                      ),

                      // Card Email 
                      _ProfileInfoCard(
                        icon: Icons.email,
                        title: "Email",
                        value: email,
                        onEdit: () => _editProfileField('email', email, user.uid),
                        cardColor: Colors.white,
                      ),


                      const SizedBox(height: 16),

                      // Ubah Password 
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white,
                        child: ListTile(
                          leading: const Icon(Icons.lock_outline, color: Color(0xFF0B6623)),
                          title: const Text(
                            "Ubah kata sandi",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF0B6623)),
                          onTap: _showChangePasswordDialog,
                        ),
                      ),

                      // Logout — (TIDAK DIUBAH)
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.white,
                        child: ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text(
                            "Keluar akun",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => Dialog(
                                backgroundColor: const Color(0xFF0B6623),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
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
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            elevation: 0,
                                          ),
                                          onPressed: () => Navigator.pop(context, true),
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
                                            backgroundColor: Color(0xFFE5E5E5),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            elevation: 0,
                                          ),
                                          onPressed: () => Navigator.pop(context, false),
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
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                );
              },
            ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onEdit;
  final Color? cardColor;

  const _ProfileInfoCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onEdit,
    this.cardColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0B6623), size: 32),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B6623),
          ),
        ),
        subtitle: Text(value, style: const TextStyle(color: Colors.black87)),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Color(0xFF0B6623)),
          onPressed: onEdit,
        ),
      ),
    );
  }
}
