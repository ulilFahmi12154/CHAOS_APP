import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Key to anchor the custom dropdown menu right under the field
  final GlobalKey _varietasFieldKey = GlobalKey();
  // Dropdown varietas
  final List<String> _varietasList = const [
    'Dewata F1',
    'CRV 211',
    'Patra 3',
    'Mhanu XR',
    'Wartavi',
    'Bara',
    'Juwiring',
  ];
  String _selectedVarietas = 'Patra 3';

  // Notifikasi
  bool notifEnabled = true;
  bool notifKritis = true;
  bool notifSiklus = true;
  bool notifSuhuAmbang = true;
  bool notifKelembapanUdaraAmbang = true;
  bool notifPhAmbang = true;
  bool notifCahayaAmbang = true;

  // Nilai ambang (editable via slider)
  final double suhuMin = 22, suhuMax = 28;
  double suhu = 24;
  final double humMin = 50, humMax = 58;
  double kelembapanUdara = 53;
  final double phMin = 5.8, phMax = 6.5;
  double phTanah = 6.0;
  final double luxMin = 19000, luxMax = 55000;
  double intensitasCahaya = 22000;

  // Asset icon paths to verify and precache
  final List<String> _iconAssets = [
    'assets/ikon/cabai.png',
    'assets/ikon/material-symbols_air.png',
    'assets/ikon/game-icons_land-mine.png',
    'assets/ikon/cahaya.png',
  ];

  @override
  void initState() {
    super.initState();
    // Try to precache icon assets after first frame to surface any missing asset errors early
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final path in _iconAssets) {
        try {
          await precacheImage(AssetImage(path), context);
          // ignore: avoid_print
          print('Precache OK: $path');
        } catch (e) {
          // ignore: avoid_print
          print('Precache FAILED for $path -> $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 3,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Pengaturan Sistem',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF234D2B),
                ),
              ),
              const SizedBox(height: 24),
              // Varietas yang ditanam saat ini
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/ikon/cabai.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.local_fire_department,
                                  color: Color(0xFF234D2B),
                                  size: 20,
                                ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Varietas yang ditanam saat ini',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        key: _varietasFieldKey,
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final selected = await _showVarietasMenu(context);
                          if (selected != null) {
                            setState(() => _selectedVarietas = selected);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF2D5F40),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedVarietas,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Ambang Batas Optimal
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Ambang Batas Optimal',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                            child: Text(
                              _selectedVarietas,
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Suhu
                      _SliderIndicator(
                        icon: const Icon(
                          Icons.thermostat_outlined,
                          color: Color(0xFF234D2B),
                        ),
                        label: 'Suhu',
                        minLabel: '${suhuMin.toStringAsFixed(0)}°C',
                        maxLabel: '${suhuMax.toStringAsFixed(0)}°C',
                        min: suhuMin,
                        max: suhuMax,
                        value: suhu,
                        valueLabel: '${suhu.toStringAsFixed(0)}°C',
                        onChanged: (v) => setState(() => suhu = v),
                        divisions: (suhuMax - suhuMin).toInt(),
                      ),
                      const SizedBox(height: 14),

                      // Kelembapan Udara
                      _SliderIndicator(
                        icon: Image.asset(
                          'assets/ikon/material-symbols_air.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.water_drop_outlined,
                                color: Color(0xFF234D2B),
                                size: 20,
                              ),
                        ),
                        label: 'Kelembapan Udara',
                        minLabel: '${humMin.toStringAsFixed(0)}%',
                        maxLabel: '${humMax.toStringAsFixed(0)}%',
                        min: humMin,
                        max: humMax,
                        value: kelembapanUdara,
                        valueLabel: '${kelembapanUdara.toStringAsFixed(0)}%',
                        onChanged: (v) => setState(() => kelembapanUdara = v),
                        divisions: (humMax - humMin).toInt(),
                      ),
                      const SizedBox(height: 14),

                      // pH Tanah
                      _SliderIndicator(
                        icon: Image.asset(
                          'assets/ikon/game-icons_land-mine.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.grass_outlined,
                                color: Color(0xFF234D2B),
                                size: 20,
                              ),
                        ),
                        label: 'pH Tanah',
                        minLabel: phMin.toStringAsFixed(1),
                        maxLabel: phMax.toStringAsFixed(1),
                        min: phMin,
                        max: phMax,
                        value: phTanah,
                        valueLabel: phTanah.toStringAsFixed(1),
                        onChanged: (v) => setState(() => phTanah = v),
                        divisions: 7, // ~0.1 step
                      ),
                      const SizedBox(height: 14),

                      // Intensitas Cahaya
                      _SliderIndicator(
                        icon: Image.asset(
                          'assets/ikon/cahaya.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.wb_sunny_outlined,
                                color: Color(0xFF234D2B),
                                size: 20,
                              ),
                        ),
                        label: 'Intensitas Cahaya',
                        minLabel: '${_formatNumber(luxMin)} lux',
                        maxLabel: '${_formatNumber(luxMax)} lux',
                        min: luxMin,
                        max: luxMax,
                        value: intensitasCahaya,
                        valueLabel: _formatNumber(intensitasCahaya),
                        onChanged: (v) => setState(() => intensitasCahaya = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Notifikasi
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notifikasi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Aktifkan notifikasi aplikasi',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Switch(
                            value: notifEnabled,
                            activeColor: Colors.white,
                            activeTrackColor: Colors.green,
                            onChanged: (v) {
                              setState(() => notifEnabled = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _notifTile(
                        'Notifikasi kondisi tanaman kritis',
                        notifKritis,
                        (v) => setState(() => notifKritis = v ?? false),
                      ),
                      _notifTile(
                        'Notifikasi siklus irigasi (pompa on/off)',
                        notifSiklus,
                        (v) => setState(() => notifSiklus = v ?? false),
                      ),
                      const SizedBox(height: 8),
                      // Tambahan: Notifikasi ambang batas per-metrik
                      _notifTile(
                        'Notifikasi Suhu Mencapai Ambang Batas',
                        notifSuhuAmbang,
                        (v) => setState(() => notifSuhuAmbang = v ?? false),
                      ),
                      _notifTile(
                        'Notifikasi Kelembapan Udara Mencapai Ambang Batas',
                        notifKelembapanUdaraAmbang,
                        (v) => setState(
                          () => notifKelembapanUdaraAmbang = v ?? false,
                        ),
                      ),
                      _notifTile(
                        'Notifikasi pH Tanah Mencapai Ambang Batas',
                        notifPhAmbang,
                        (v) => setState(() => notifPhAmbang = v ?? false),
                      ),
                      _notifTile(
                        'Notifikasi Intensitas Cahaya Mencapai Ambang Batas',
                        notifCahayaAmbang,
                        (v) => setState(() => notifCahayaAmbang = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Ubah kata sandi
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: ListTile(
                  leading: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF234D2B),
                  ),
                  title: const Text(
                    'Ubah kata sandi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                  onTap: () async {
                    final oldPasswordController = TextEditingController();
                    final newPasswordController = TextEditingController();
                    final confirmPasswordController = TextEditingController();
                    bool showOldPassword = false;
                    bool showNewPassword = false;
                    bool showConfirmPassword = false;

                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => StatefulBuilder(
                        builder: (context, setState) => AlertDialog(
                          title: const Text('Ubah Kata Sandi'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: oldPasswordController,
                                obscureText: !showOldPassword,
                                decoration: InputDecoration(
                                  labelText: 'Kata Sandi Lama',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      showOldPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        showOldPassword = !showOldPassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: newPasswordController,
                                obscureText: !showNewPassword,
                                decoration: InputDecoration(
                                  labelText: 'Kata Sandi Baru',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      showNewPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        showNewPassword = !showNewPassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: confirmPasswordController,
                                obscureText: !showConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'Konfirmasi Kata Sandi Baru',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      showConfirmPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        showConfirmPassword =
                                            !showConfirmPassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Simpan'),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (result == true) {
                      final oldPassword = oldPasswordController.text.trim();
                      final newPassword = newPasswordController.text.trim();
                      final confirmPassword = confirmPasswordController.text
                          .trim();

                      if (newPassword != confirmPassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kata sandi baru tidak cocok'),
                          ),
                        );
                        return;
                      }

                      try {
                        final authService = AuthService();
                        await authService.changePassword(
                          oldPassword,
                          newPassword,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kata sandi berhasil diubah'),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Gagal mengubah kata sandi: ${e.toString()}',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Keluar akun
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Keluar akun',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Konfirmasi'),
                        content: const Text(
                          'Apakah Anda yakin ingin keluar dari akun?',
                        ),
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
                      try {
                        final authService = AuthService();
                        await authService.logout();
                        if (mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/welcome',
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal keluar: ${e.toString()}'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showVarietasMenu(BuildContext context) async {
    final RenderBox button =
        _varietasFieldKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset buttonTopLeft = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final Offset buttonBottomLeft = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );

    // Position the menu right under the field
    final RelativeRect position = RelativeRect.fromLTRB(
      buttonBottomLeft.dx,
      buttonBottomLeft.dy,
      overlay.size.width - buttonTopLeft.dx - button.size.width,
      overlay.size.height - buttonBottomLeft.dy,
    );

    // Ensure non-transparent popup background with rounded corners
    final result = await showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      items: _varietasList.map((v) {
        final bool isSelected = v == _selectedVarietas;
        return PopupMenuItem<String>(
          value: v,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFB9B9B9) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              v,
              style: TextStyle(
                color: isSelected ? Colors.black87 : const Color(0xFF2D5F40),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );

    return result;
  }

  Widget _notifTile(String text, bool value, ValueChanged<bool?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  // Versi interaktif: slider tipis + label nilai + min/max
  Widget _SliderIndicator({
    required Widget icon,
    required String label,
    required String minLabel,
    required String maxLabel,
    required double min,
    required double max,
    required double value,
    required String valueLabel,
    required ValueChanged<double> onChanged,
    int? divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 24, height: 24, child: icon),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                valueLabel,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            inactiveTrackColor: Colors.grey.shade300,
            activeTrackColor: const Color(0xFF2E7D32),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(minLabel, style: const TextStyle(color: Colors.black54)),
            Text(maxLabel, style: const TextStyle(color: Colors.black45)),
          ],
        ),
      ],
    );
  }

  String _formatNumber(double v) {
    if (v >= 1000) {
      final k = (v / 1000).round();
      return '${k}k';
    }
    return v.toStringAsFixed(0);
  }
}
