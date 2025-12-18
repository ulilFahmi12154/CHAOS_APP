import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

class RekomendasiPupukPage extends StatefulWidget {
  const RekomendasiPupukPage({super.key});

  @override
  State<RekomendasiPupukPage> createState() => _RekomendasiPupukPageState();
}

class _RekomendasiPupukPageState extends State<RekomendasiPupukPage> {
  String selectedVarietas = "Dewata F1";
  String selectedStage = "Vegetatif";

  final List<String> varietasList = [
    "Dewata F1",
    "CRV 211",
    "Patra 3",
    "Mhanu XR",
    "Tavi",
    "Bara",
    "Juwiring",
  ];

  final Map<String, Map<String, Map<String, dynamic>>> rekomendasiData = {
    "Dewata F1": {
      "Vegetatif": {
        "keunggulan": ["Hasil tinggi, tahan aphid"],
        "fokus": ["Menjaga tanaman tetap kuat dan produktif tinggi"],
        "npk": "NPK tinggi N",
        "merk": ["Unimak Super N", "NPK Mutiara merah Granule", "NPK Padi 321"],
        "tambahan": ["Magnesium Sulfat (MgSO₄)"],
        "tujuan": [
          "Mempercepat pertumbuhan daun dan batang, Mg penting untuk fotosintesis",
        ],
      },
      "Generatif": {
        "keunggulan": ["Hasil tinggi, tahan aphid"],
        "fokus": ["Menjaga tanaman tetap kuat dan produktif tinggi"],
        "npk": "NPK tinggi K dan P",
        "merk": [
          "NPK Mutiara Partner 13-13-24",
          "Growmore 10-55-10",
          "Yuvita K32 (16-11-32)",
          "Pupuk Kaeno 3 Kristal (13-0-46)",
          "NPK Super Folium",
        ],
        "tambahan": ["Kalsium Nitrat (Ca(NO₃)₂)"],
        "tujuan": [
          "Cegah busuk ujung buah, bantu pembentukan buah besar dan padat",
        ],
      },
    },
    "CRV 211": {
      "Vegetatif": {
        "keunggulan": ["Tahan penyakit Patek (Antraknosa)"],
        "fokus": ["Meningkatkan daya tahan tanaman terhadap jamur"],
        "npk": "NPK 16-16-16 seimbang",
        "merk": [
          "Mutiara (PT. Meroke Tetap Jaya)",
          "Pak Tani (Rusia)",
          "Npk 16-16-16 Biru (Saprotan Utama)",
        ],
        "tambahan": ["Silika (Si) atau POC dengan Si"],
        "tujuan": ["Perkuat dinding sel tanaman agar tahan jamur"],
      },
      "Generatif": {
        "keunggulan": ["Tahan penyakit Patek (Antraknosa)"],
        "fokus": ["Meningkatkan daya tahan tanaman terhadap jamur"],
        "npk": "NPK tinggi K",
        "merk": [
          "Meroke NPK Mutiara Professional 9-25-25",
          "NPK Mutiara Grower 15-09-20+TE",
          "NPK Mutiara PARTNER 13-13-24",
          "pupuk kalium cair seperti VERTINE-K atau Kaeno 3 cair",
        ],
        "tambahan": ["Unsur mikro Zn dan Mn"],
        "tujuan": [
          "Zn dan Mn bantu sistem pertahanan tanaman terhadap penyakit",
        ],
      },
    },
    "Patra 3": {
      "Vegetatif": {
        "keunggulan": ["Buah tahan lama dan kuat"],
        "fokus": ["Menjaga kekerasan dan ketahanan fisik buah"],
        "npk": "NPK 15-15-15",
        "merk": [
          "Phonska Plus (Petrokimia Gresik)",
          "Pak Tani",
          "DGW",
          "Mutiara Plus",
          "Mahkota",
          "Saprotan Utama",
        ],
        "tambahan": ["Pupuk organik cair"],
        "tujuan": ["Memperkuat struktur batang untuk menopang buah padat"],
      },
      "Generatif": {
        "keunggulan": ["Buah tahan lama dan kuat"],
        "fokus": ["Menjaga kekerasan dan ketahanan fisik buah"],
        "npk": "NPK sangat tinggi K",
        "merk": [
          "NPK Mutiara GROWER 15-09-20+TE",
          "MerokeFLEX-G (8-9-39+3MgO+TE)",
          "MerokeKALINITRA (16% N dan 46% K2O)",
        ],
        "tambahan": ["Kalsium Nitrat (Ca(NO₃)₂)"],
        "tujuan": [
          "Kalium dan kalsium bantu buah lebih keras, berat, dan tahan lama",
        ],
      },
    },
    "Mhanu XR": {
      "Vegetatif": {
        "keunggulan": ["Tahan virus (Gemini) dan hama"],
        "fokus": ["Meningkatkan ketahanan dan pemulihan tanaman"],
        "npk": "NPK 16-16-16 seimbang",
        "merk": [
          "Mutiara (PT. Meroke Tetap Jaya)",
          "Pak Tani (Rusia)",
          "Npk 16-16-16 Biru (Saprotan Utama)",
        ],
        "tambahan": ["Unsur mikro lengkap (B, Fe, Zn, Cu)"],
        "tujuan": ["Membantu metabolisme dan meningkatkan imun tanaman"],
      },
      "Generatif": {
        "keunggulan": ["Tahan virus (Gemini) dan hama"],
        "fokus": ["Meningkatkan ketahanan dan pemulihan tanaman"],
        "npk": "NPK 12-12-17",
        "merk": ["Pak Tani", "Mahkota", "YaraMila", "Cockhead (DGW)"],
        "tambahan": ["ZPT + Asam Amino"],
        "tujuan": [
          "Membantu tanaman pulih dari stres dan menjaga hasil tetap tinggi",
        ],
      },
    },
    "Tavi": {
      "Vegetatif": {
        "keunggulan": ["Tahan kering & Layu Fusarium"],
        "fokus": ["Menguatkan akar agar tahan kekeringan"],
        "npk": "NPK tinggi P ",
        "merk": [
          "Growmore 10-55-10",
          "Yuvita P32 (16-32-16)",
          "Meroke NPK Mutiara Professional 9-25-25",
          "NPK Mutiara Partner 13-13-24",
        ],
        "tambahan": ["Pupuk mengandung sulfur (S)"],
        "tujuan": ["Fosfor bantu akar tumbuh dalam dan kuat"],
      },
      "Generatif": {
        "keunggulan": ["Tahan kering & Layu Fusarium"],
        "fokus": ["Menguatkan akar agar tahan kekeringan"],
        "npk": "NPK tinggi K",
        "merk": [
          "Meroke NPK Mutiara Professional 9-25-25",
          "NPK Mutiara Grower 15-09-20+TE",
          "NPK Mutiara PARTNER 13-13-24",
          "pupuk kalium cair seperti VERTINE-K atau Kaeno 3 cair",
        ],
        "tambahan": ["Agen hayati Trichoderma spp."],
        "tujuan": ["Aplikasi di tanah untuk mencegah penyakit layu akar"],
      },
    },
    "Bara": {
      "Vegetatif": {
        "keunggulan": ["Tumbuh di berbagai dataran, sangat pedas"],
        "fokus": ["Menunjang pembentukan rasa pedas dan adaptasi suhu"],
        "npk": "Pupuk organik melimpah + NPK 16-16-16",
        "merk": [
          "Anda bisa menggunakan pupuk organik cair seperti POC Pangan atau produk GDM (GDM SaMe dan GDM Black BOS) untuk melengkapi pupuk kimia NPK Mutiara 16-16-16 atau NPK Pak Tani 16-16-16",
        ],
        "tambahan": ["Pupuk daun tinggi N"],
        "tujuan": ["Membantu pertumbuhan cepat di berbagai kondisi"],
      },
      "Generatif": {
        "keunggulan": ["Tumbuh di berbagai dataran, sangat pedas"],
        "fokus": ["Menunjang pembentukan rasa pedas dan adaptasi suhu"],
        "npk": "NPK tinggi K dan P",
        "merk": [
          "NPK Mutiara Partner 13-13-24",
          "Growmore 10-55-10",
          "Yuvita K32 (16-11-32)",
          "Pupuk Kaeno 3 Kristal (13-0-46)",
          "NPK Super Folium",
        ],
        "tambahan": ["Sulfur (S)"],
        "tujuan": [
          "Sulfur bantu pembentukan capsaicin (zat pedas) dan daya tahan tanaman",
        ],
      },
    },
    "Juwiring": {
      "Vegetatif": {
        "keunggulan": ["Buah banyak, tahan virus kuning"],
        "fokus": ["Menjaga kualitas dan bobot buah lokal"],
        "npk": "Pupuk organik + NPK 15-15-15",
        "merk": [
          "Anda bisa menggunakan pupuk NPK 15-15-15 (seperti merk Phonska Plus dari Petrokimia Gresik, Pak Tani, atau DGW) dan pupuk organik padat atau cair secara terpisah untuk memenuhi kebutuhan tanaman cabai, atau memilih pupuk NPK Majemuk dengan tambahan unsur hara mikro (TE) jika tersedia",
        ],
        "tambahan": ["Asam Humat & Fulvat"],
        "tujuan": ["Meningkatkan penyerapan hara dari pupuk"],
      },
      "Generatif": {
        "keunggulan": ["Buah banyak, tahan virus kuning"],
        "fokus": ["Menjaga kualitas dan bobot buah lokal"],
        "npk": "NPK tinggi K dan P",
        "merk": [
          "NPK Mutiara Partner 13-13-24",
          "Growmore 10-55-10",
          "Yuvita K32 (16-11-32)",
          "Pupuk Kaeno 3 Kristal (13-0-46)",
          "NPK Super Folium",
        ],
        "tambahan": ["Magnesium Sulfat (MgSO₄)"],
        "tujuan": ["Bantu pembentukan buah padat dan cegah rontok daun"],
      },
    },
  };

  Map<String, dynamic> get currentRekomendasi {
    return rekomendasiData[selectedVarietas]?[selectedStage] ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 0,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown(),
            const SizedBox(height: 16),
            Center(
              child: Text(
                selectedVarietas,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildPartCard(),
            const SizedBox(height: 16),
            _buildStageButtons(),
            const SizedBox(height: 16),
            _buildDetailCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.eco, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedVarietas,
                  isExpanded: true,
                  items: varietasList.map((v) {
                    return DropdownMenuItem(
                      value: v,
                      child: Text(v, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => selectedVarietas = value);
                  },
                ),
              ),
            ),
            const Icon(Icons.expand_more, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Rekomendasi pupuk untuk varietas cabai",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                selectedVarietas,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartCard() {
    final rekomendasi = currentRekomendasi;
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tentang Tanaman",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Keunggulan Tanaman",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            ...(rekomendasi['keunggulan'] as List<String>? ?? []).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text("• $item", style: const TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Fokus Pemupukan",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            ...(rekomendasi['fokus'] as List<String>? ?? []).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text("• $item", style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => selectedStage = "Vegetatif"),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selectedStage == "Vegetatif"
                    ? Colors.green
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: selectedStage != "Vegetatif"
                    ? Border.all(color: Colors.grey.shade300)
                    : null,
                boxShadow: selectedStage == "Vegetatif"
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                "Vegetatif",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selectedStage == "Vegetatif"
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => selectedStage = "Generatif"),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selectedStage == "Generatif"
                    ? Colors.green
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: selectedStage != "Generatif"
                    ? Border.all(color: Colors.grey.shade300)
                    : null,
                boxShadow: selectedStage == "Generatif"
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                "Generatif",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selectedStage == "Generatif"
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard() {
    final rekomendasi = currentRekomendasi;
    final merkList = rekomendasi['merk'] as List<String>? ?? [];
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Rekomendasi NPK",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "• ${rekomendasi['npk'] ?? 'N/A'}",
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              "Merk yang direkomendasikan",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            ...merkList.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text("• $item", style: const TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Pupuk tambahan lain",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            ...(rekomendasi['tambahan'] as List<String>? ?? []).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text("• $item", style: const TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Tujuan dan Keterangan",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            ...(rekomendasi['tujuan'] as List<String>? ?? []).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text("• $item", style: const TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
