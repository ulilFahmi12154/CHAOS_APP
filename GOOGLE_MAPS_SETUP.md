# Setup Peta Gratis (OpenStreetMap)

Sekarang aplikasi menggunakan **OpenStreetMap (OSM)** dengan plugin `flutter_map`.
Tidak perlu API key, kartu kredit, atau setting Google Cloud!

## Cara Pakai

1. Pastikan dependencies berikut sudah ada di `pubspec.yaml`:
    - flutter_map
    - latlong2

2. Build ulang aplikasi:
    ```bash
    flutter pub get
    flutter run
    ```

3. Saat tambah/edit lokasi:
    - Klik **Pilih Lokasi di Peta**
    - Peta OSM akan muncul
    - Geser peta, pin merah di tengah menunjukkan lokasi terpilih
    - Klik **Pilih Lokasi Ini** untuk konfirmasi

4. Koordinat latitude/longitude akan otomatis terisi

## Kelebihan OSM
- 100% GRATIS, tanpa batasan kuota
- Tidak perlu kartu kredit
- Bisa digunakan di development & produksi

## Catatan
- Tidak ada reverse geocoding (alamat otomatis) pada versi OSM basic
- Jika ingin fitur alamat otomatis, bisa pakai API Nominatim (juga gratis, tapi rate limit rendah)
3. ✅ **Tombol Lokasi Saya** - Langsung ke posisi GPS Anda
4. ✅ **Auto Geocoding** - Alamat otomatis muncul dari koordinat
5. ✅ **Koordinat GPS** - Latitude & longitude tersimpan

## Struktur Data

Setiap lokasi sekarang punya:
- `name`: Nama lokasi
- `address`: Alamat lengkap (dari geocoding)
- `latitude`: Koordinat GPS
- `longitude`: Koordinat GPS
- `active_varietas`: Varietas yang ditanam
- `waktu_tanam`: Waktu tanam
- `mode_otomatis`: Mode pompa

## Catatan

- Untuk testing tanpa API key, Anda bisa skip (map tidak akan muncul)
- API key gratis dari Google dengan quota terbatas
- Pastikan enable **Geocoding API** juga untuk reverse geocoding
