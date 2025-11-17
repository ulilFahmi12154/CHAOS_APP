# Cara Cek Integrasi Firebase Settings

## 🔍 Langkah-langkah Pengecekan

### 1. **Restart Aplikasi**
```powershell
flutter clean
flutter pub get
flutter run
```

### 2. **Login ke Aplikasi**
- Masuk dengan akun yang sudah terdaftar
- Pastikan Anda sudah login sebelum masuk ke halaman Settings

### 3. **Buka Halaman Settings**
- Navigasi ke halaman Settings (biasanya di bottom navigation)
- Tunggu loading selesai (akan ada loading indicator)

### 4. **Cek Data Varietas dari Firestore**

#### Di Aplikasi:
- Tap dropdown "Varietas yang ditanam saat ini"
- Pilih varietas lain (misal: **Bara**)
- Perhatikan:
  - ✅ Range slider **Suhu** berubah sesuai varietas (18°C - 30°C untuk Bara)
  - ✅ Range slider **Kelembapan Udara** berubah (40% - 80% untuk Bara)
  - ✅ Range slider **pH Tanah** berubah (1.1 - 1.9 untuk Bara)
  - ✅ Range slider **Intensitas Cahaya** berubah (1800 - 4095 lux untuk Bara)

#### Di Firebase Console:
1. Buka Firebase Console → **Firestore Database**
2. Lihat collection `varietas_config` → Document `bara`
3. **PENTING**: Tambahkan field baru untuk pH (jika belum ada):
   ```
   ph_min: 5.8
   ph_max: 6.5
   ```
4. Pastikan data lengkap sesuai:
   ```
   suhu_min: 18
   suhu_max: 30
   kelembapan_udara_min: 40
   kelembapan_udara_max: 80
   ph_min: 5.8
   ph_max: 6.5
   soil_min: 1100        (ini untuk sensor kelembapan tanah, bukan pH)
   soil_max: 1900        (ini untuk sensor kelembapan tanah, bukan pH)
   light_min: 1800
   light_max: 4095
   ```

### 5. **Cek Simpan Settings ke Realtime Database**

#### Di Aplikasi:
1. Ubah varietas ke **Bara**
2. Geser slider **Suhu** ke nilai 25°C
3. Geser slider **Kelembapan Udara** ke 60%
4. Toggle **Notifikasi Status Pompa Irigasi** ON/OFF
5. Toggle **Notifikasi Tanaman Kritis** ON/OFF

#### Di Firebase Console:
1. Buka Firebase Console → **Realtime Database**
2. Navigasi ke path: `users/{userId}/settings`
3. Pastikan data ter-update:
   ```json
   {
     "varietas": "bara",
     "ambang_batas": {
       "suhu": 25,
       "kelembapan_udara": 60,
       "ph_tanah": 6.0,
       "intensitas_cahaya": 22000
     },
     "notifikasi": {
       "enabled": true,
       "pompa_irigasi": true,
       "tanaman_kritis": true
     }
   }
   ```

### 6. **Cek Load Settings dari Firebase**

#### Test Scenario:
1. **Ubah data di aplikasi** (misal: varietas = Bara, suhu = 25)
2. **Restart aplikasi** (stop dan run lagi)
3. **Login kembali**
4. **Buka halaman Settings**
5. **Verifikasi**:
   - ✅ Varietas terpilih = **Bara** (bukan default Patra 3)
   - ✅ Slider suhu di posisi 25°C
   - ✅ Range slider sesuai varietas Bara
   - ✅ Notifikasi sesuai dengan yang terakhir di-set

## 📊 Struktur Data Firebase

### Firestore Database
```
varietas_config/
  bara/
    nama: "Bara"
    suhu_min: 18
    suhu_max: 30
    kelembapan_udara_min: 40
    kelembapan_udara_max: 80
    ph_min: 5.8              ← TAMBAHKAN INI
    ph_max: 6.5              ← TAMBAHKAN INI
    soil_min: 1100           (sensor kelembapan tanah)
    soil_max: 1900           (sensor kelembapan tanah)
    light_min: 1800
    light_max: 4095
    catatan: "..."
    dataran: "..."
    jenis_tanah: "..."

  patra_3/
    nama: "Patra 3"
    suhu_min: 22
    suhu_max: 28
    kelembapan_udara_min: 50
    kelembapan_udara_max: 58
    ph_min: 5.8              ← TAMBAHKAN INI
    ph_max: 6.5              ← TAMBAHKAN INI
    soil_min: 1100           (sensor kelembapan tanah)
    soil_max: 1900           (sensor kelembapan tanah)
    light_min: 1800
    light_max: 4095
```

### Realtime Database
```
users/
  {userId}/
    settings/
      varietas: "bara"
      ambang_batas/
        suhu: 25
        kelembapan_udara: 60
        ph_tanah: 6.0
        intensitas_cahaya: 22000
      notifikasi/
        enabled: true
        pompa_irigasi: true
        tanaman_kritis: true
```

## 🐛 Troubleshooting

### Problem: Error "value is not between minimum and maximum"
**Penyebab:**
- Nilai slider saat ini berada di luar range yang baru dari Firestore
- Contoh: Intensitas cahaya = 36303, tapi range baru = 1800-4095

**Solusi:**
1. **Tambahkan field `ph_min` dan `ph_max`** di semua document varietas_config:
   ```
   ph_min: 5.8
   ph_max: 6.5
   ```

2. **Restart aplikasi** setelah menambahkan field baru:
   ```powershell
   flutter run
   ```

3. Aplikasi akan otomatis **clamp** (membatasi) nilai yang di luar range:
   - Jika intensitasCahaya = 36303 dan max = 4095, akan di-set ke 4095
   - Jika phTanah = 6.0 dan range baru = 1.1-1.9, akan di-set ke 1.9

### Problem: Range slider tidak berubah saat ganti varietas
**Solusi:**
- Pastikan document ID di Firestore sesuai (lowercase dengan underscore)
- Misal: "Bara" → document ID = `bara`
- Misal: "Patra 3" → document ID = `patra_3`

### Problem: Data tidak tersimpan ke Realtime Database
**Solusi:**
1. Cek Firebase Rules di Realtime Database:
   ```json
   {
     "rules": {
       "users": {
         "$uid": {
           ".read": "$uid === auth.uid",
           ".write": "$uid === auth.uid"
         }
       }
     }
   }
   ```
2. Pastikan user sudah login (FirebaseAuth.instance.currentUser != null)

### Problem: Loading terus-menerus
**Solusi:**
- Cek koneksi internet
- Cek Firebase Console untuk memastikan data ada
- Cek log di terminal untuk error message

## � Real-time Notifications

### Fitur Real-time Updates

Aplikasi menggunakan **Firebase Realtime Database Stream** untuk update notifikasi secara otomatis:

```dart
// Stream listener di settings_screen.dart
_dbService.userSettingsStream(_userId!).listen((settings) {
  // Update UI otomatis saat data berubah
  setState(() {
    notifEnabled = settings['notifikasi']['enabled'];
    notifSiklus = settings['notifikasi']['pompa_irigasi'];
    notifKritis = settings['notifikasi']['tanaman_kritis'];
  });
});
```

### Testing Real-time Updates

1. **Buka aplikasi di device/emulator**
2. **Buka Firebase Console → Realtime Database**
3. **Edit data langsung di console:**
   ```
   users/{userId}/settings/notifikasi/enabled: true → false
   ```
4. **Lihat aplikasi** - Toggle switch akan berubah otomatis tanpa refresh!

### Cara Kerja:
- ✅ Perubahan di database langsung terdeteksi
- ✅ UI update otomatis tanpa perlu reload
- ✅ Multi-device sync (edit di satu device, update di semua device)
- ✅ Connection handling (auto-reconnect jika koneksi putus)

**Debug Log:**
```
Real-time update - Notifikasi:
  Enabled: true
  Pompa: true
  Kritis: false
```

## �📱 Expected Behavior

1. **Saat Pertama Buka Settings:**
   - Loading indicator muncul
   - Load list varietas dari Firestore
   - Load settings user dari Realtime Database
   - Load config varietas dari Firestore (untuk min/max range)
   - UI ter-update dengan data yang di-load

2. **Saat Ganti Varietas:**
   - Load config varietas baru dari Firestore
   - Range slider berubah sesuai config
   - Nilai current slider di-adjust agar tetap dalam range
   - Simpan perubahan ke Realtime Database

3. **Saat Geser Slider:**
   - State lokal ter-update (UI berubah)
   - Auto-save ke Realtime Database

4. **Saat Toggle Notifikasi:**
   - State lokal ter-update (switch berubah)
   - Auto-save ke Realtime Database

## ✅ Checklist Verifikasi

- [ ] List varietas muncul dari Firestore (bukan hardcoded)
- [ ] Range slider berubah saat ganti varietas
- [ ] Nilai slider tersimpan ke Realtime Database
- [ ] Notifikasi settings tersimpan ke Realtime Database
- [ ] Setelah restart, settings ter-load kembali
- [ ] Nama varietas ditampilkan dengan benar (bukan ID)
