import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../services/realtime_db_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RealtimeDbService _dbService = RealtimeDbService();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 2,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Kontrol Sistem Irigasi Card
            _buildIrigasiCard(),
            const SizedBox(height: 16),

            // Peringatan Penting Card
            _buildPeringatanCard(),
            const SizedBox(height: 16),

            // Sensor Data Cards
            Row(
              children: [
                Expanded(child: _buildSensorCard(
                  'Kelembapan tanah',
                  Icons.water_drop,
                  Colors.blue,
                  _dbService.kelembapanTanahStream,
                  '%',
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildSensorCard(
                  'Suhu udara',
                  Icons.thermostat,
                  Colors.orange,
                  _dbService.suhuStream,
                  '°C',
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildSensorCard(
                  'Kelembapan Udara',
                  Icons.opacity,
                  Colors.green,
                  _dbService.kelembapanUdaraStream,
                  '%',
                )),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()), // placeholder
              ],
            ),
            const SizedBox(height: 16),

            // Rekomendasi Pupuk & Kenali Tanamanmu
            Row(
              children: [
                Expanded(child: _buildRecommendationCard(
                  'Rekomendasi\nPupuk',
                  Icons.eco,
                  Colors.green,
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildRecommendationCard(
                  'Kenali\ntanamanmu',
                  Icons.local_florist,
                  Colors.red.shade700,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIrigasiCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kontrol Sistem Irigasi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Text(
                      'ON',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.toggle_on, color: Colors.white, size: 28),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Mode : Otomatis',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPeringatanCard() {
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
          const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text(
                'Peringatan Penting',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWarningItem('Kelembapan Tanah rendah !'),
          _buildWarningItem('Pompa Irigasi Aktif ( 5 menit lalu)'),
          _buildWarningItem('Suhu udara tinggi !'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Lihat semua',
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(
    String title,
    IconData icon,
    Color color,
    Stream<dynamic> dataStream,
    String unit,
  ) {
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
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          StreamBuilder<dynamic>(
            stream: dataStream,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Text(
                  '${snapshot.data}$unit',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }
              return const Text(
                '--',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              );
            },
          ),
          const SizedBox(height: 8),
          // Gauge indicator placeholder
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.speed, color: color, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(String title, IconData icon, Color color) {
    return Container(
      height: 140,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
        ],
      ),
    );
  }
}
