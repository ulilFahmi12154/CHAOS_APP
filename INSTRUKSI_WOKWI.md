# Instruksi Set Lokasi untuk Wokwi

## Masalah yang Terjadi:
- Pompa menyala/mati sendiri karena Wokwi baca mode otomatis dari lokasi berbeda
- Flutter di `lokasi_4`, tapi Wokwi mungkin di lokasi lain

## Solusi: Set Active Location di Firebase RTDB

### Cara 1: Via Firebase Console
1. Buka Firebase Console → Realtime Database
2. Navigasi ke path: `/smartfarm/active_device_location`
3. Set value menjadi: `lokasi_4` (sesuai lokasi di aplikasi Flutter)
4. Restart Wokwi ESP32

### Cara 2: Via JavaScript di Browser Console
```javascript
// Buka Firebase Console di browser
// Tekan F12 untuk buka Console
// Jalankan code berikut:

firebase.database().ref('smartfarm/active_device_location').set('lokasi_4')
  .then(() => console.log('✅ Lokasi Wokwi di-set ke lokasi_4'))
  .catch(err => console.error('❌ Error:', err));
```

### Cara 3: Tambahkan di Wokwi Code Setup
Tambahkan di `setup()` Wokwi:
```cpp
// Di akhir setup(), tambahkan:
Serial.println("📍 SET LOKASI MANUAL (TESTING)");
Firebase.RTDB.setString(&fbdo, "/smartfarm/active_device_location", "lokasi_4");
```

## Verifikasi:
Setelah set lokasi, cek Serial Monitor Wokwi harus muncul:
```
📍 LOKASI BERUBAH: ... → lokasi_4
✅ Lokasi aktif: lokasi_4
```

## Path yang Digunakan:
- **Mode Otomatis**: `smartfarm/locations/lokasi_4/mode_otomatis`
- **Pompa Command**: `smartfarm/locations/lokasi_4/commands/relay_crv_211`
- **Sensor Status**: `smartfarm/locations/lokasi_4/sensors/crv_211/pompa`
- **Varietas**: `smartfarm/locations/lokasi_4/active_varietas`

## Testing:
1. Set lokasi Wokwi ke `lokasi_4`
2. Restart Wokwi
3. Buka aplikasi Flutter → pastikan di `lokasi_4` juga
4. Toggle mode Manual/Otomatis → harus sinkron
5. Nyalakan/Matikan pompa manual → Wokwi harus ikut
