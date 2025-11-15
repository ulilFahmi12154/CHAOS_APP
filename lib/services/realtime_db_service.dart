import 'package:firebase_database/firebase_database.dart';

/// Service untuk mengambil data dari Firebase Realtime Database
class RealtimeDbService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Stream untuk kelembapan tanah
  Stream<int?> kelembapanTanahStream(String varietas) {
    return _dbRef
        .child('smartfarm/sensors/$varietas/kelembaban_tanah')
        .onValue
        .map((event) => event.snapshot.value as int?);
  }

  /// Stream untuk kelembapan udara
  Stream<double?> kelembapanUdaraStream(String varietas) {
    return _dbRef
        .child('smartfarm/sensors/$varietas/kelembapan_udara')
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value is int) return value.toDouble();
          if (value is double) return value;
          return null;
        });
  }

  /// Stream untuk suhu
  Stream<double?> suhuStream(String varietas) {
    return _dbRef.child('smartfarm/sensors/$varietas/suhu').onValue.map((
      event,
    ) {
      final value = event.snapshot.value;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return null;
    });
  }

  /// Stream untuk intensitas cahaya
  Stream<int?> cahayaStream(String varietas) {
    return _dbRef
        .child('smartfarm/sensors/$varietas/intensitas_cahaya')
        .onValue
        .map((event) => event.snapshot.value as int?);
  }

  /// Get one-time data untuk kelembapan tanah
  Future<int?> getKelembapanTanah(String varietas) async {
    final snapshot = await _dbRef
        .child('smartfarm/sensors/$varietas/kelembaban_tanah')
        .get();
    return snapshot.value as int?;
  }

  /// Get one-time data untuk kelembapan udara
  Future<double?> getKelembapanUdara(String varietas) async {
    final snapshot = await _dbRef
        .child('smartfarm/sensors/$varietas/kelembapan_udara')
        .get();
    final value = snapshot.value;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return null;
  }

  /// Get one-time data untuk suhu
  Future<double?> getSuhu(String varietas) async {
    final snapshot = await _dbRef
        .child('smartfarm/sensors/$varietas/suhu')
        .get();
    final value = snapshot.value;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return null;
  }

  /// Get one-time data untuk intensitas cahaya
  Future<int?> getCahaya(String varietas) async {
    final snapshot = await _dbRef
        .child('smartfarm/sensors/$varietas/intensitas_cahaya')
        .get();
    return snapshot.value as int?;
  }
}
