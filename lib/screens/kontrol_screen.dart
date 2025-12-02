import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class KontrolScreen extends StatefulWidget {
  const KontrolScreen({super.key});

  @override
  State<KontrolScreen> createState() => _KontrolScreenState();
}

class _KontrolScreenState extends State<KontrolScreen> {
  final db = FirebaseDatabase.instance.ref();
  bool modeOtomatis = true;
  bool pompaState = false;
  String? activeVarietas;

  @override
  void initState() {
    super.initState();
    _loadActiveVarietas();
  }

  Future<void> _loadActiveVarietas() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    db.child('users/${user.uid}/active_varietas').onValue.listen((event) {
      if (event.snapshot.exists) {
        setState(() {
          activeVarietas = event.snapshot.value.toString();
        });
      } else {
        setState(() {
          activeVarietas = null;
        });
      }
    });
  }

  Future<void> _toggleMode(bool value) async {
    await db.child('smartfarm/mode_otomatis').set(value);
    setState(() {
      modeOtomatis = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mode berubah ke ${value ? "Otomatis" : "Manual"}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _togglePompa(bool state) async {
    if (activeVarietas != null) {
      await db
          .child('smartfarm/commands/relay_$activeVarietas')
          .set(state ? 1 : 0);
      setState(() {
        pompaState = state;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pompa ${state ? "Dinyalakan" : "Dimatikan"}'),
          backgroundColor: state ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          _buildHeaderCard(),
          const SizedBox(height: 24),

          // Mode Control Card
          _buildModeControlCard(),
          const SizedBox(height: 20),

          // Pompa Control Card
          _buildPompaControlCard(),
          const SizedBox(height: 20),

          // Ambang Batas Settings
          _buildThresholdSettingsCard(),
          const SizedBox(height: 20),

          // Status Dashboard
          _buildStatusDashboard(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kontrol Sistem Irigasi',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kelola pompa dan mode otomatis/manual',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Varietas: ${activeVarietas?.replaceAll("_", " ").toUpperCase() ?? "Belum dipilih"}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeControlCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Otomatis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pompa mengikuti kelembapan tanah',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StreamBuilder<dynamic>(
                stream: db
                    .child('smartfarm/mode_otomatis')
                    .onValue
                    .map((e) => e.snapshot.value),
                builder: (context, snapshot) {
                  bool isAuto = snapshot.data == true;
                  return Switch(
                    value: isAuto,
                    onChanged: _toggleMode,
                    activeColor: Colors.green,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Mode Otomatis: Pompa otomatis ON jika tanah kering dan OFF jika tanah basah sesuai ambang batas.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                      height: 1.3,
                    ),
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Mode Manual: Anda bisa mengontrol pompa ON/OFF secara manual.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      height: 1.3,
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPompaControlCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kontrol Pompa',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          StreamBuilder<dynamic>(
            stream: db
                .child('smartfarm/mode_otomatis')
                .onValue
                .map((e) => e.snapshot.value),
            builder: (context, modeSnapshot) {
              bool isAuto = modeSnapshot.data == true;
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        StreamBuilder<dynamic>(
                          stream: db
                              .child('smartfarm/sensors/$activeVarietas/pompa')
                              .onValue
                              .map((e) => e.snapshot.value),
                          builder: (context, snapshot) {
                            bool isOn = snapshot.data == 'ON';
                            return Column(
                              children: [
                                Icon(
                                  isOn
                                      ? Icons.water
                                      : Icons.water_drop_outlined,
                                  size: 60,
                                  color: isOn ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isOn ? '🟢 POMPA AKTIF' : '🔴 POMPA STANDBY',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isOn ? Colors.green : Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isOn
                                      ? 'Pompa sedang menyiram tanaman'
                                      : 'Pompa dalam mode standby',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isAuto)
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _togglePompa(true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.power, size: 20),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Nyalakan\nPompa',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _togglePompa(false);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.power_off, size: 20),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Matikan\nPompa',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.yellow.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.yellow.shade200),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber,
                                color: Colors.orange,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Mode Manual: Gunakan dengan hati-hati untuk menghindari kerusakan pada tanaman.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                  ),
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.auto_mode, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Mode Otomatis aktif. Pompa dikontrol secara otomatis berdasarkan kelembapan tanah.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                              ),
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings, size: 20),
              SizedBox(width: 8),
              Text(
                'Pengaturan Ambang Batas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Pengaturan ambang batas kelembapan tanah, suhu, dan cahaya dapat diatur dari halaman Profile sesuai dengan varietas yang dipilih.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 3,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/profile');
              },
              icon: const Icon(Icons.settings, size: 18),
              label: const Text(
                'Pergi ke Pengaturan',
                style: TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDashboard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dashboard, size: 20),
              SizedBox(width: 8),
              Text(
                'Status Sistem',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<dynamic>(
            stream: db
                .child('smartfarm/mode_otomatis')
                .onValue
                .map((e) => e.snapshot.value),
            builder: (context, snapshot) {
              bool isAuto = snapshot.data == true;
              return _buildStatusItem(
                'Mode Sistem',
                isAuto ? '⚙️ Otomatis' : '🖱️ Manual',
                isAuto ? Colors.blue : Colors.orange,
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<dynamic>(
            stream: db
                .child('smartfarm/sensors/$activeVarietas/pompa')
                .onValue
                .map((e) => e.snapshot.value),
            builder: (context, snapshot) {
              bool isOn = snapshot.data == 'ON';
              return _buildStatusItem(
                'Status Pompa',
                isOn ? '🟢 ON' : '🔴 OFF',
                isOn ? Colors.green : Colors.red,
              );
            },
          ),
          const SizedBox(height: 12),
          _buildStatusItem(
            'Varietas Aktif',
            activeVarietas?.replaceAll('_', ' ').toUpperCase() ??
                'Belum dipilih',
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
