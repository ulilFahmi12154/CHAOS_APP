import 'package:flutter/material.dart';

class KenaliTanamanmuScreen extends StatefulWidget {
  const KenaliTanamanmuScreen({Key? key}) : super(key: key);

  @override
  State<KenaliTanamanmuScreen> createState() => _KenaliTanamanmuScreenState();
}

class _KenaliTanamanmuScreenState extends State<KenaliTanamanmuScreen> {
  final List<Map<String, String>> _plants = [
    {
      'name': 'Dewata F1',
      'description_short':
          'Dewata F1 adalah varietas cabai hibrida yang sangat produktif dan kuat. Cocok untuk dataran rendah hingga menengah...',
      'description_full':
          'Dewata F1 adalah varietas cabai hibrida yang sangat produktif dan kuat, cocok ditanam di dataran rendah hingga menengah, terutama pada daerah yang mendapatkan sinar matahari penuh sepanjang hari. Tanaman Dewata F1 membutuhkan suplai air yang stabil—tidak terlalu berlebih, namun juga tidak kekurangan—karena ritme produktivitasnya cepat dan intensif. Tanah liat berpasir yang subur membantu akar berkembang optimal, sementara pH tanah ideal berkisar antara 6.0 hingga 7.0. Dengan intensitas cahaya ideal 20.000–60.000 lux, varietas ini mampu menghasilkan buah seragam dan berkualitas tinggi.',
      'image': 'assets/images/DewataF1.png',
    },
    {
      'name': 'CRV 211',
      'description_short':
          'CRV 211 adalah varietas cabai hibrida dengan produktivitas tinggi dan ketahanan penyakit utama...',
      'description_full':
          'CRV 211 adalah varietas cabai hibrida yang dikenal dengan produktivitas tinggi dan ketahanan terhadap penyakit utama. Cocok untuk dataran rendah hingga menengah, buahnya besar, seragam, dan tahan lama setelah panen. Varietas ini membutuhkan pencahayaan penuh dan penyiraman teratur agar hasil optimal.',
      'image': 'assets/images/CRV211.png',
    },
    {
      'name': 'Patra 3',
      'description_short':
          'Patra 3 adaptif di berbagai kondisi lahan, tahan cuaca panas dan hujan, pertumbuhan cepat...',
      'description_full':
          'Patra 3 adalah varietas cabai yang adaptif di berbagai kondisi lahan, tahan terhadap cuaca panas maupun hujan, serta memiliki pertumbuhan yang cepat. Buahnya merah cerah, tahan lama setelah panen, dan cocok untuk petani yang membutuhkan varietas fleksibel.',
      'image': 'assets/images/Patra3.png',
    },
    {
      'name': 'Mhanu XR',
      'description_short':
          'Mhanu XR unggul dalam ketahanan terhadap kekeringan, cocok untuk lahan tadah hujan...',
      'description_full':
          'Mhanu XR adalah varietas cabai yang unggul dalam ketahanan terhadap kekeringan. Cocok untuk lahan tadah hujan, hasil buah tetap stabil meski curah hujan rendah. Buahnya pedas, berwarna merah cerah, dan tanaman relatif tahan penyakit.',
      'image': 'assets/images/MhanuXR.png',
    },
    {
      'name': 'Juwiring',
      'description_short':
          'Juwiring adalah varietas cabai lokal adaptif di berbagai kondisi lahan, buah merah cerah...',
      'description_full':
          'Juwiring adalah varietas cabai lokal yang adaptif di berbagai kondisi lahan. Buahnya merah cerah, tahan lama setelah panen, dan memiliki rasa pedas yang khas. Varietas ini cocok untuk petani tradisional maupun modern.',
      'image': 'assets/images/Juwiring.png',
    },
    {
      'name': 'Bara',
      'description_short':
          'Bara adalah varietas cabai rawit unggul, cocok untuk dataran rendah hingga menengah...',
      'description_full':
          'Bara adalah varietas cabai rawit unggul yang cocok untuk dataran rendah hingga menengah. Tahan terhadap cuaca panas dan memiliki buah kecil yang pedas. Tanaman ini juga relatif tahan penyakit dan mudah beradaptasi.',
      'image': 'assets/images/Bara.png',
    },
    {
      'name': 'Tavi',
      'description_short':
          'Tavi cocok untuk dataran menengah hingga tinggi, buah besar dan pedas...',
      'description_full':
          'Tavi adalah varietas cabai yang cocok untuk dataran menengah hingga tinggi, dengan buah besar dan rasa pedas yang khas. Tanaman ini membutuhkan suhu sejuk dan pencahayaan cukup agar hasil optimal.',
      'image': 'assets/images/Tavi.png',
    },
  ];

  late List<bool> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = List.generate(_plants.length, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card (tetap)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1B5E20),
                  Color(0xFF2E7D32),
                  Color(0xFF4CAF50),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.local_florist,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kenali\nTanamanmu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Varietas cabai &\nkarakteristiknya',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.eco, color: Colors.white, size: 22),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          ...List.generate(_plants.length, (index) {
            final plant = _plants[index];
            final isExpanded = _expanded[index];

            final title = plant['name'] ?? '-';
            final short = plant['description_short'] ?? '-';
            final full = plant['description_full'] ?? '-';
            final image = plant['image'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0B6623), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: AssetImage(image),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B6623),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isExpanded ? full : short,
                            maxLines: isExpanded ? null : 3,
                            overflow: isExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _expanded[index] = !_expanded[index];
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF0B6623),
                                ),
                                foregroundColor: const Color(0xFF0B6623),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: Text(
                                isExpanded ? 'Lebih Sedikit' : 'Selengkapnya',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
