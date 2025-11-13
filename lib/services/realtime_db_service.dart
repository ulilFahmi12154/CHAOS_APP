import 'package:firebase_database/firebase_database.dart';

/// Service untuk mengambil data dari Firebase Realtime Database
class RealtimeDbService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Stream untuk kelembapan tanah
  Stream<int?> get kelembapanTanahStream {
    return _dbRef
        .child('smartfarm/sensors/kelembaban_tanah')
        .onValue
        .map((event) => event.snapshot.value as int?);
  }

  /// Stream untuk kelembapan udara
  Stream<int?> get kelembapanUdaraStream {
    return _dbRef
        .child('smartfarm/sensors/kelembapan_udara')
        .onValue
        .map((event) => event.snapshot.value as int?);
  }

  /// Stream untuk suhu
  Stream<double?> get suhuStream {
    return _dbRef
        .child('smartfarm/sensors/suhu')
        .onValue
        .map((event) {
      final value = event.snapshot.value;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return null;
    });
  }

  /// Get one-time data untuk kelembapan tanah
  Future<int?> getKelembapanTanah() async {
    final snapshot = await _dbRef.child('smartfarm/sensors/kelembaban_tanah').get();
    return snapshot.value as int?;
  }

  /// Get one-time data untuk kelembapan udara
  Future<int?> getKelembapanUdara() async {
    final snapshot = await _dbRef.child('smartfarm/sensors/kelembapan_udara').get();
    return snapshot.value as int?;
  }

  /// Get one-time data untuk suhu
  Future<double?> getSuhu() async {
    final snapshot = await _dbRef.child('smartfarm/sensors/suhu').get();
    final value = snapshot.value;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return null;
  }
}
