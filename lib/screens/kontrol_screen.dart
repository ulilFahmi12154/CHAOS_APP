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
  bool _isTogglingPompa = false; // Track if pompa toggle is in progress

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
    print(
      'DEBUG: _togglePompa called with state=$state, activeVarietas=$activeVarietas',
    );

    if (activeVarietas == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan pilih varietas terlebih dahulu'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_isTogglingPompa) {
      print('DEBUG: Already toggling, returning');
      return;
    }

    setState(() => _isTogglingPompa = true);
    print('DEBUG: Set _isTogglingPompa to true');

    try {
      // Update Firebase command ke MULTIPLE paths supaya Wokwi pasti bisa baca
      final commandValue = state ? 1 : 0;
      final statusValue = state ? 'ON' : 'OFF';

      // Path 1: smartfarm/commands/relay_varietas (command)
      final commandPath1 = 'smartfarm/commands/relay_$activeVarietas';
      print('DEBUG: Updating path 1: $commandPath1 with value: $commandValue');
      await db.child(commandPath1).set(commandValue);

      // Path 2: smartfarm/devices/pump/command (untuk Wokwi)
      final commandPath2 = 'smartfarm/devices/pump/command';
      print('DEBUG: Updating path 2: $commandPath2 with value: $commandValue');
      await db.child(commandPath2).set(commandValue);

      // Path 3: UPDATE SENSOR STATUS LANGSUNG (tidak tunggu Wokwi)
      final sensorPath = 'smartfarm/sensors/$activeVarietas/pompa';
      print(
        'DEBUG: Updating sensor status: $sensorPath with value: $statusValue',
      );
      await db.child(sensorPath).set(statusValue);

      print('DEBUG: All Firebase updates sent successfully');

      // Tunggu sebentar untuk propagasi
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pompa ${state ? "Dinyalakan" : "Dimatikan"}'),
            backgroundColor: state ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error in _togglePompa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status pompa: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTogglingPompa = false);
        print('DEBUG: Set _isTogglingPompa to false');
      }
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
                    StreamBuilder<dynamic>(
                      stream: db
                          .child('smartfarm/sensors/$activeVarietas/pompa')
                          .onValue
                          .map((e) => e.snapshot.value),
                      builder: (context, pompaSnapshot) {
                        bool isOn = pompaSnapshot.data == 'ON';
                        print(
                          'DEBUG: pompaSnapshot.data = ${pompaSnapshot.data}, isOn = $isOn, _isTogglingPompa = $_isTogglingPompa',
                        );
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: (_isTogglingPompa || isOn)
                                        ? null
                                        : () {
                                            _togglePompa(true);
                                          },
                                    icon: const Icon(Icons.power),
                                    label: const Text('Nyalakan Pompa'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          (_isTogglingPompa || isOn)
                                          ? Colors.grey
                                          : Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: (_isTogglingPompa || !isOn)
                                        ? null
                                        : () {
                                            _togglePompa(false);
                                          },
                                    icon: const Icon(Icons.power_off),
                                    label: const Text('Matikan Pompa'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          (_isTogglingPompa || !isOn)
                                          ? Colors.grey
                                          : Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_isTogglingPompa)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.blue,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Mengirim perintah ke pompa...',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (!isOn)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.yellow.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.yellow.shade200,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Pompa standby. Klik "Nyalakan Pompa" untuk menyirami.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.yellow.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.yellow.shade200,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Pompa sedang aktif. Klik "Matikan Pompa" untuk berhenti.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
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
                Navigator.pushNamed(context, '/settings');
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
