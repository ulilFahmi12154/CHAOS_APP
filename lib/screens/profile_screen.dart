import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../widgets/app_scaffold.dart';

import 'reset_password_screen.dart';
import 'login_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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

  // Fungsi upload foto profil
  Future<void> _pickAndUploadPhoto(String uid) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      // kamu juga bisa tambahkan maxWidth / maxHeight untuk resize:
      // maxWidth: 800, maxHeight: 800,
    );
    if (picked == null) return;

    setState(() => _uploading = true);

    try {
      final ref = FirebaseStorage.instance.ref().child('profile_photos/$uid.jpg');

      // Baca sebagai bytes — ini bekerja di mobile & web
      final bytes = await picked.readAsBytes();

      // Optional: tampilkan progress upload
      final uploadTask = ref.putData(bytes);
      uploadTask.snapshotEvents.listen((event) {
        // kalau mau menampilkan progress, simpan di state mis. _progressValue
        // final progress = event.totalBytes > 0 ? event.bytesTransferred / event.totalBytes : 0.0;
        // setState(() => _progressValue = progress);
      });

      await uploadTask.whenComplete(() => null);

      final url = await ref.getDownloadURL();
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      setState(() => _photoUrl = "$url?cb=$cacheBuster");

      await FirebaseFirestore.instance.collection('users').doc(uid).update({'photoUrl': url});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal upload foto: $e')));
      }
    } finally {
      setState(() => _uploading = false);
    }
  }


  // Edit field teks dan dropdown
  Future<void> _editProfileField(String field, String currentValue, String uid) async {
    if (field == 'jenisCabai') {
      String selectedValue = currentValue;
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pilih Jenis Cabai'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) => DropdownButton<String>(
              value: jenisCabaiList.contains(selectedValue) ? selectedValue : jenisCabaiList.first,
              isExpanded: true,
              items: jenisCabaiList
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setStateDialog(() => selectedValue = val ?? currentValue),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(context, selectedValue), child: const Text('Simpan')),
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
                final jenisCabai = data['jenisCabai'] ?? '-';
                final photoUrl = _photoUrl ?? data['photoUrl'];

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

                      // Foto profil
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
                                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                                          ? NetworkImage(photoUrl)
                                          : const AssetImage('assets/images/profile.png') as ImageProvider,
                                    ),
                                  ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _uploading ? null : () => _pickAndUploadPhoto(user.uid),
                              child: const Text(
                                "Edit Foto",
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

                      // Data user
                      _ProfileInfoCard(
                        icon: Icons.person,
                        title: "Nama",
                        value: nama,
                        onEdit: () => _editProfileField('nama', nama, user.uid),
                        cardColor: Colors.white,
                      ),
                      _ProfileInfoCard(
                        icon: Icons.email,
                        title: "Email",
                        value: email,
                        onEdit: () => _editProfileField('email', email, user.uid),
                        cardColor: Colors.white,
                      ),

Card(
  elevation: 3,
  shadowColor: Colors.black26,
  color: Colors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/ikon/cabai.png',
          width: 24, // ukuran ikon sama dengan ikon nama & email
          height: 24,
          color: const Color(0xFF0B6623),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Jenis yang ditanam saat ini",
                style: TextStyle(
                  color: Color(0xFF0B6623),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 36, // tinggi dropdown diseragamkan
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5E5),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: jenisCabaiList.contains(jenisCabai)
                        ? jenisCabai
                        : jenisCabaiList.first,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF0B6623),
                      size: 22,
                    ),
                    style: const TextStyle(
                      color: Color(0xFF0B6623),
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                    ),
                    dropdownColor: Colors.white,
                    items: jenisCabaiList
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (val) async {
                      if (val != null && val != jenisCabai) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .update({'jenisCabai': val});
                        setState(() {});
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
),









                      const SizedBox(height: 16),

                      // Ubah password
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.white,
                        child: ListTile(
                          title: const Text(
                            "Ubah kata sandi",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF0B6623)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ResetPasswordScreen(),
                              ),
                            );
                          },
                        ),
                      ),

                      // Logout
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.white,
                        child: ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text(
                            "Keluar akun",
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Konfirmasi'),
                                content: const Text('Apakah Anda yakin ingin keluar dari akun?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Batal'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Ya, Keluar'),
                                  ),
                                ],
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
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B6623)),
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
