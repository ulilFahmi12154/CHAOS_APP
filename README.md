<div align="center">

# 🌶️ CHAOS_APP — Smart Farming Cabai Rawit
Aplikasi **Smart Farming** berbasis **Flutter + Firebase** untuk monitoring kondisi lahan, kontrol irigasi, riwayat data sensor, notifikasi peringatan, dan laporan.

<br/>

![Flutter](https://img.shields.io/badge/Flutter-3.35.6-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-Language-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Realtime%20DB%20%7C%20Firestore-FFCA28?logo=firebase&logoColor=black)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web%20%7C%20Desktop-1F6FEB)

</div>

---

## 📌 Deskripsi
**CHAOS_APP** adalah aplikasi **Smart Farming Cabai Rawit** yang membantu pengguna memantau kondisi lahan secara real-time dan mengambil keputusan berbasis data.

Aplikasi menyediakan beberapa modul utama:
- 🧭 **Dashboard**: ringkasan kondisi lahan (lokasi aktif, varietas yang ditanam, fase pertumbuhan, status normal/peringatan).
- 🕘 **Riwayat**: visualisasi data historis sensor dan pemilihan periode (bulanan/tahunan/custom).
- 💧 **Kontrol**: kontrol sistem irigasi/pompa dalam mode **Manual** maupun **Otomatis**.
- 📑 **Laporan**: analisis performa dan **download laporan** (PDF/Excel) berdasarkan periode/rentang tanggal.
- ⚙️ **Pengaturan**: kelola lokasi, varietas aktif, waktu tanam, dan **ambang batas optimal** (threshold sensor).
- 👤 **Profil & Notifikasi**: pengelolaan profil pengguna serta daftar peringatan/alerts.

> Backend menggunakan **Firebase** untuk autentikasi dan penyimpanan data real-time.  
> Integrasi Firebase dikonfigurasi melalui `firebase_options.dart` (FlutterFire).

---

## ✨ Fitur Utama
- 🔐 **Login/Autentikasi** (Firebase Auth)
- 📡 **Monitoring Real-time** (Firebase Realtime Database)
- 🧠 **Konfigurasi & data statis** (Firebase Firestore)
- 🗺️ **Lokasi & peta** (Google Maps — API Key via AndroidManifest)
- 📈 **Grafik & Riwayat** data sensor (filter periode)
- 🚨 **Peringatan** saat melewati ambang batas
- 📄 **Export Laporan** ke **PDF/Excel**
- 🧩 UI modern dengan bottom navigation + modul terpisah

---

## 🧱 Arsitektur Singkat
**(Device/IoT → Firebase → App)**

1. Perangkat (mis. ESP32 / simulasi Wokwi) mengirim data sensor ke **Firebase Realtime Database**
2. Aplikasi membaca data real-time untuk Dashboard & Kontrol
3. Konfigurasi seperti varietas aktif / threshold disimpan di **Firestore**
4. Aplikasi menampilkan riwayat, peringatan, dan menghasilkan laporan

---

## 🛠️ Tech Stack
- **Flutter**: `3.35.6` (stable)
- **Firebase**:
  - Authentication
  - Realtime Database
  - Firestore
- **Google Maps**: API Key ditaruh di **AndroidManifest.xml**
- Wokwi untuk simulasi IoT


---

## ✅ Prasyarat
Pastikan sudah terpasang:
- Flutter SDK **3.35.6**
- Android Studio / VS Code
- Git
- Perangkat Android / Emulator

> Note: untuk build Windows app di perangkat Windows, butuh **Visual Studio + Desktop development with C++**.
> (Tidak wajib kalau hanya develop Android.)

---

## 🚀 Cara Instalasi

### 1) Clone Repository
```bash
git clone https://github.com/jessicaamelia17/CHAOS_APP.git
cd CHAOS_APP
