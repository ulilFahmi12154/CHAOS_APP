import 'package:flutter/material.dart';

class IntroSlidesScreen extends StatefulWidget {
  const IntroSlidesScreen({Key? key}) : super(key: key);

  @override
  State<IntroSlidesScreen> createState() => _IntroSlidesScreenState();
}

class _IntroSlidesScreenState extends State<IntroSlidesScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<_SlideData> _slides = const [
    _SlideData(
      image: 'assets/images/Sp 1.png',
      text:
          'Pantau suhu, kelembapan, nutrisi, pH tanah, dan kondisi media tanam cabai secara real-time dalam satu aplikasi.',
    ),
    _SlideData(
      image: 'assets/images/Sp 2.png',
      text:
          'Sistem penyiraman otomatis bekerja sesuai kebutuhan tanaman, menjaga kelembapan tetap ideal tanpa pemantauan manual.',
    ),
    _SlideData(
      image: 'assets/images/Sp 3.png',
      text:
          'Dapatkan rekomendasi pupuk yang tepat berdasarkan usia dan jenis cabai yang dipilih untuk pertumbuhan yang optimal.',
    ),
  ];

  void _next() {
    if (_index < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  void _skip() {
    Navigator.pushReplacementNamed(context, '/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Paged background images
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final slide = _slides[i];
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  Image.asset(
                    slide.image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: Colors.green.shade200),
                  ),
                  // Top gradient bar
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: 200,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xBB1B5E20), Color(0x001B5E20)],
                        ),
                      ),
                    ),
                  ),
                  // Bottom gradient with text
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xCC1B5E20), Color(0x001B5E20)],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slide.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Dots
                              Row(
                                children: List.generate(_slides.length, (d) {
                                  final active = d == _index;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(right: 8),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }),
                              ),
                              // Next button
                              InkWell(
                                onTap: _next,
                                borderRadius: BorderRadius.circular(28),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward,
                                    color: Color(0xFF1B5E20),
                                    size: 28,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tombol Kembali (kiri atas)
                  if (_index > 0)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 16,
                      child: InkWell(
                        onTap: () => _controller.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF1B5E20),
                            size: 24,
                          ),
                        ),
                      ),
                    ),

                  // Teks Lewati (kanan atas)
                  if (_index < _slides.length - 1)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      right: 16,
                      child: TextButton(
                        onPressed: _skip,
                        child: const Text(
                          'Lewati',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final String image;
  final String text;
  const _SlideData({required this.image, required this.text});
}
