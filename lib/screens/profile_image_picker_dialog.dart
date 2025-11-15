import 'package:flutter/material.dart';

class ProfileImagePickerDialog extends StatefulWidget {
  final List<String> profileImages;
  final String currentPhoto;
  final String defaultProfile;
  const ProfileImagePickerDialog({
    required this.profileImages,
    required this.currentPhoto,
    required this.defaultProfile,
  });

  @override
  State<ProfileImagePickerDialog> createState() => _ProfileImagePickerDialogState();
}

class _ProfileImagePickerDialogState extends State<ProfileImagePickerDialog> {
  late String? selectedPhoto;

  @override
  void initState() {
    super.initState();
    selectedPhoto = widget.currentPhoto;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pilih Gambar Profile',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF0B6623),
                  ),
                ),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: widget.profileImages.map((img) {
                      final isSelected = (selectedPhoto == img);
                      final isCurrent = (widget.currentPhoto == img);
                      String label = '';
                      if (img == widget.defaultProfile) label = 'Petani';
                      // Tambahkan label lain di sini jika gambar baru sudah ada
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedPhoto = img;
                            });
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0B6623) : Colors.transparent,
                                    width: 3,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: CircleAvatar(
                                  radius: 32,
                                  backgroundImage: AssetImage(img),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF0B6623) : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isCurrent)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Terpakai',
                                    style: TextStyle(
                                      color: Color(0xFF0B6623),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B6623),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(context, selectedPhoto),
                    child: const Text(
                      'Simpan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.pop(context, null),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.close, size: 26, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
