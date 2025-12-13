import 'package:flutter/material.dart';

class PlantGrowthInfo {
  final int umurHari;
  final String fase;
  final double progressPanen; // 0.0 - 1.0
  final Map<String, dynamic>? jadwalPupukBerikutnya;

  PlantGrowthInfo({
    required this.umurHari,
    required this.fase,
    required this.progressPanen,
    this.jadwalPupukBerikutnya,
  });
}

class PlantUtils {
  static PlantGrowthInfo calculateGrowthInfo({
    required int waktuTanamMillis,
    List<Map<String, dynamic>>? jadwalPupuk,
    int hariPanen = 91,
  }) {
    final now = DateTime.now();
    final waktuTanam = DateTime.fromMillisecondsSinceEpoch(waktuTanamMillis);
    final umur = now.difference(waktuTanam).inDays;
    String fase = 'Vegetatif';
    if (umur >= 91) {
      fase = 'Siap Panen';
    } else if (umur >= 71) {
      fase = 'Pembuahan';
    } else if (umur >= 61) {
      fase = 'Pembungaan';
    } else if (umur >= 31) {
      fase = 'Generatif';
    }
    double progress = (umur / hariPanen).clamp(0.0, 1.0);
    Map<String, dynamic>? pupukBerikutnya;
    if (jadwalPupuk != null) {
      for (final jadwal in jadwalPupuk) {
        final hariJadwal = jadwal['hari'] as int;
        if (umur < hariJadwal) {
          pupukBerikutnya = jadwal;
          break;
        }
      }
    }
    return PlantGrowthInfo(
      umurHari: umur,
      fase: fase,
      progressPanen: progress,
      jadwalPupukBerikutnya: pupukBerikutnya,
    );
  }

  static List<Map<String, dynamic>> defaultJadwalPupuk() {
    return [
      {'hari': 7, 'nama': 'NPK', 'deskripsi': 'Pupuk dasar'},
      {'hari': 14, 'nama': 'NPK', 'deskripsi': 'Pupuk susulan 1'},
      {'hari': 21, 'nama': 'NPK', 'deskripsi': 'Pupuk susulan 2'},
      {'hari': 30, 'nama': 'NPK', 'deskripsi': 'Pupuk susulan 3'},
      {'hari': 45, 'nama': 'NPK', 'deskripsi': 'Pupuk susulan 4'},
      {'hari': 60, 'nama': 'NPK', 'deskripsi': 'Pupuk susulan 5'},
    ];
  }

  static Color faseColor(String fase) {
    switch (fase) {
      case 'Vegetatif':
        return Colors.green;
      case 'Generatif':
        return Colors.blue;
      case 'Pembungaan':
        return Colors.purple;
      case 'Pembuahan':
        return Colors.orange;
      case 'Siap Panen':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
