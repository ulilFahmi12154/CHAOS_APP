

  import 'package:chaos_app/screens/plant_detail_screen.dart';
  import 'package:flutter/material.dart';
  import 'package:firebase_database/firebase_database.dart';
  import '../widgets/app_scaffold.dart';
  import '../services/realtime_db_service.dart';

  Widget _buildSensorCard(
    String title,
    IconData icon,
    Color color,
    Stream<dynamic> dataStream,
    String unit,
    num minBatas,
    num maxBatas,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          StreamBuilder<dynamic>(
            stream: dataStream,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final value = snapshot.data;
                return Column(
                  children: [
                    Text(
                      '$value$unit',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ideal: $minBatas - $maxBatas',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ((value - minBatas) / (maxBatas - minBatas)).clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          color.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const Text(
                '--',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              );
            },
          ),
        ],
      ),
    );
  }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RealtimeDbService _dbService = RealtimeDbService();
  String? activeVarietas;
  bool pompaStatus = false;


  @override
  void initState() {
    super.initState();
    _loadActiveVarietas();
  }

  Future<void> _loadActiveVarietas() async {
    final ref = FirebaseDatabase.instance.ref('smartfarm/active_varietas');
    ref.onValue.listen((event) {
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

  Stream<List<Map<String, dynamic>>> getWarningStream() {
    final path = activeVarietas != null && activeVarietas!.isNotEmpty
        ? 'smartfarm/warning/$activeVarietas'
        : 'smartfarm/warning/default';

    final db = FirebaseDatabase.instance.ref(path);
    return db.onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        return data.values
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
            .take(3)
            .toList();
      }
      return [];
    });
  }

  Future<void> _togglePompa(bool state) async {
    final varietasToUse = activeVarietas ?? 'default';
    final db = FirebaseDatabase.instance.ref();
    await db
        .child('smartfarm/commands/relay_$varietasToUse')
        .set(state ? 1 : 0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pompa ${state ? 'Dinyalakan' : 'Dimatikan'}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final belumPilih = activeVarietas == null || activeVarietas!.isEmpty;

    return AppScaffold(
      currentIndex: 2,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderCard(context),
            const SizedBox(height: 16),
            if (belumPilih)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dashboard Default',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Pilih varietas untuk data real-time',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _buildIrigasiCard(),
            const SizedBox(height: 16),
            _buildWarningNotif(),
            const SizedBox(height: 16),
            _buildSensorGrid(),
            const SizedBox(height: 16),
            _buildRecommendationRow(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }





  Widget _buildHeaderCard(BuildContext context) {
    final belumPilih = activeVarietas == null || activeVarietas!.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
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
            'Halo Farmer!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Varietas yang sedang dimonitor:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          if (belumPilih)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white.withOpacity(0.8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Belum ada varietas yang dipilih',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      activeVarietas!.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                  icon: Icon(belumPilih ? Icons.add : Icons.edit),
                  label: Text(belumPilih ? 'Pilih Varietas' : 'Ubah'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (!belumPilih) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    _showDeleteConfirmation(context);
                  },
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Hapus'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Varietas'),
          content: const Text(
            'Apakah Anda yakin ingin menghapus varietas yang sedang dimonitor?\n\n'
            'Dashboard akan menampilkan data default.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                _deleteActiveVarietas();
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteActiveVarietas() async {
    try {
      final db = FirebaseDatabase.instance.ref();
      await db.child('smartfarm/active_varietas').remove();

      setState(() {
        activeVarietas = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Varietas berhasil dihapus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildIrigasiCard() {
    final varietasToUse = activeVarietas ?? 'default';

    return Container(
      padding: const EdgeInsets.all(16),
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
            'Kontrol Sistem Irigasi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<dynamic>(
            stream: FirebaseDatabase.instance
                .ref('smartfarm/sensors/$varietasToUse/pompa')
                .onValue
                .map((e) => e.snapshot.value),
            builder: (context, snapshot) {
              bool isOn = snapshot.data == 'ON';
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status Pompa'),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isOn ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isOn ? '🟢 ON' : '🔴 OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _togglePompa(true),
                        icon: const Icon(Icons.power),
                        label: const Text('Nyalakan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _togglePompa(false),
                        icon: const Icon(Icons.power_off),
                        label: const Text('Matikan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<dynamic>(
            stream: FirebaseDatabase.instance
                .ref('smartfarm/mode_otomatis')
                .onValue
                .map((e) => e.snapshot.value),
            builder: (context, snapshot) {
              bool isAuto = snapshot.data == true;
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isAuto ? Colors.blue.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    isAuto
                        ? Icon(Icons.auto_mode, color: Colors.blue)
                        : Icon(Icons.touch_app, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Mode: ${isAuto ? "Otomatis" : "Manual"}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isAuto ? Colors.blue : Colors.orange,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWarningNotif() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getWarningStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Semua kondisi dalam keadaan normal ✨',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }

        final warnings = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'Peringatan Sistem',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              w['type'] ?? 'Peringatan',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              w['message'] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSensorGrid() {
    final varietasToUse = activeVarietas ?? 'default';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Sensor Real-time',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                'Suhu Udara',
                Icons.thermostat,
                Colors.orange,
                _dbService.suhuStream(varietasToUse),
                '°C',
                25,
                30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                'Kelembapan Udara',
                Icons.opacity,
                Colors.blue,
                _dbService.kelembapanUdaraStream(varietasToUse),
                '%',
                40,
                80,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                'Kelembapan Tanah',
                Icons.water_drop,
                Colors.green,
                _dbService.kelembapanTanahStream(varietasToUse),
                'ADC',
                1200,
                2000,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                'Intensitas Cahaya',
                Icons.light_mode,
                Colors.yellow.shade700,
                _dbService.cahayaStream(varietasToUse),
                'Lux',
                2000,
                4095,
              ),
            ),
          ],
        ),
      ],
    );
  }



  Widget _buildRecommendationRow() {
    return Row(
      children: [
        Expanded(
          child: _buildRecommendationCard(
            context,
            'Rekomendasi\nPupuk',
            Icons.eco,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRecommendationCard(
            context,
            'Kenali\nTanamanmu',
            Icons.local_florist,
            Colors.red.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              if (title.toLowerCase().contains('tanaman')) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => KenaliTanamanmuScreen(),
                    ),
                  );
              } else {
                Navigator.pushNamed(context, '/profile');
              }
            },
            child: const Text("Lihat Detail"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

