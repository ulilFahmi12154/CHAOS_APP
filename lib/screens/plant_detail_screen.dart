
import 'package:flutter/material.dart';

import '../widgets/app_scaffold.dart';

class KenaliTanamanmuScreen extends StatefulWidget {
  const KenaliTanamanmuScreen({Key? key}) : super(key: key);

  @override
  State<KenaliTanamanmuScreen> createState() => _KenaliTanamanmuScreenState();
}

class _KenaliTanamanmuScreenState extends State<KenaliTanamanmuScreen> {
  // Static data for plant varieties (replace with your actual data)
  final List<Map<String, String>> _plants = [
    {
      'name': 'Dewata F1',
      'description_short': 'Dewata F1 adalah varietas cabai hibrida yang sangat produktif dan kuat. Cocok untuk dataran rendah hingga menengah...',
      'description_full': 'Dewata F1 adalah varietas cabai hibrida yang sangat produktif dan kuat, cocok ditanam di dataran rendah hingga menengah, terutama pada daerah yang mendapatkan sinar matahari penuh sepanjang hari. Tanaman Dewata F1 membutuhkan suplai air yang stabil—tidak terlalu berlebih, namun juga tidak kekurangan—karena ritme produktivitasnya cepat dan intensif. Tanah liat berpasir yang subur membantu akar berkembang optimal, sementara pH tanah ideal berkisar antara 6.0 hingga 7.0. Dengan intensitas cahaya ideal 20.000–60.000 lux, varietas ini mampu menghasilkan buah seragam dan berkualitas tinggi. Dewata F1 sangat direkomendasikan untuk petani yang ingin mengejar hasil panen maksimal, asalkan lingkungan budidaya cukup panas dan pencahayaan kuat tersedia.',
      'image': 'assets/images/DewataF1.png',
    },
    {
      'name': 'CRV 211',
      'description_short': 'CRV 211 adalah varietas cabai hibrida dengan produktivitas tinggi dan ketahanan penyakit utama...',
      'description_full': 'CRV 211 adalah varietas cabai hibrida yang dikenal dengan produktivitas tinggi dan ketahanan terhadap penyakit utama. Cocok untuk dataran rendah hingga menengah, buahnya besar, seragam, dan tahan lama setelah panen. Varietas ini membutuhkan pencahayaan penuh dan penyiraman teratur agar hasil optimal.',
      'image': 'assets/images/CRV211.png',
    },
    {
      'name': 'Patra 3',
      'description_short': 'Patra 3 adaptif di berbagai kondisi lahan, tahan cuaca panas dan hujan, pertumbuhan cepat...',
      'description_full': 'Patra 3 adalah varietas cabai yang adaptif di berbagai kondisi lahan, tahan terhadap cuaca panas maupun hujan, serta memiliki pertumbuhan yang cepat. Buahnya merah cerah, tahan lama setelah panen, dan cocok untuk petani yang membutuhkan varietas fleksibel.',
      'image': 'assets/images/Patra3.png',
    },
    {
      'name': 'Mhanu XR',
      'description_short': 'Mhanu XR unggul dalam ketahanan terhadap kekeringan, cocok untuk lahan tadah hujan...',
      'description_full': 'Mhanu XR adalah varietas cabai yang unggul dalam ketahanan terhadap kekeringan. Cocok untuk lahan tadah hujan, hasil buah tetap stabil meski curah hujan rendah. Buahnya pedas, berwarna merah cerah, dan tanaman relatif tahan penyakit.',
      'image': 'assets/images/MhanuXR.png',
    },
    {
      'name': 'Juwiring',
      'description_short': 'Juwiring adalah varietas cabai lokal adaptif di berbagai kondisi lahan, buah merah cerah...',
      'description_full': 'Juwiring adalah varietas cabai lokal yang adaptif di berbagai kondisi lahan. Buahnya merah cerah, tahan lama setelah panen, dan memiliki rasa pedas yang khas. Varietas ini cocok untuk petani tradisional maupun modern.',
      'image': 'assets/images/Juwiring.png',
    },
    {
      'name': 'Bara',
      'description_short': 'Bara adalah varietas cabai rawit unggul, cocok untuk dataran rendah hingga menengah...',
      'description_full': 'Bara adalah varietas cabai rawit unggul yang cocok untuk dataran rendah hingga menengah. Tahan terhadap cuaca panas dan memiliki buah kecil yang pedas. Tanaman ini juga relatif tahan penyakit dan mudah beradaptasi.',
      'image': 'assets/images/Bara.png',
    },
    {
      'name': 'Tavi',
      'description_short': 'Tavi cocok untuk dataran menengah hingga tinggi, buah besar dan pedas...',
      'description_full': 'Tavi adalah varietas cabai yang cocok untuk dataran menengah hingga tinggi, dengan buah besar dan rasa pedas yang khas. Tanaman ini membutuhkan suhu sejuk dan pencahayaan cukup agar hasil optimal.',
      'image': 'assets/images/Tavi.png',
    },
  ];

  List<bool> _expanded = [];

  @override
  void initState() {
    super.initState();
    _expanded = List.generate(_plants.length, (index) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 2, // Dashboard
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: const Center(
              child: Text(
                'Kenali Tanamanmu',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B6623),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _plants.length,
              separatorBuilder: (context, index) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                final plant = _plants[index];
                final isExpanded = _expanded[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF0B6623), width: 1.2),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: AssetImage(plant['image'] ?? ''),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plant['name'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0B6623),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final short = plant['description_short'] ?? '-';
                                  final full = plant['description_full'] ?? '-';
                                  if (isExpanded) {
                                    return Text(
                                      full,
                                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                                    );
                                  } else {
                                    final showEllipsis = short.length > 90;
                                    return Text(
                                      showEllipsis ? short.substring(0, 90).trimRight() + '...' : short,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _expanded[index] = !_expanded[index];
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF0B6623)),
                                      foregroundColor: const Color(0xFF0B6623),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    child: Text(isExpanded ? 'Lebih Sedikit' : 'Selengkapnya'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
