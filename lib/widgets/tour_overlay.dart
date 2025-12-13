import 'package:flutter/material.dart';

// Tour step model
class TourStep {
  final String targetKey;
  final String title;
  final String description;
  final TourPosition position;

  TourStep({
    required this.targetKey,
    required this.title,
    required this.description,
    required this.position,
  });
}

enum TourPosition { top, bottom }

// Tour steps definition
final List<TourStep> appTourSteps = [
  TourStep(
    targetKey: 'kontrol_button',
    title: 'Panel Kontrol',
    description:
        'Kelola pompa irigasi dengan mode otomatis atau manual. Lihat status pompa dan ambang batas sensor secara real-time.',
    position: TourPosition.bottom,
  ),
  TourStep(
    targetKey: 'history_button',
    title: 'Riwayat Data',
    description:
        'Tampilkan grafik historis kelembapan tanah, suhu udara, kelembapan udara, dan intensitas cahaya. Filter berdasarkan hari ini, bulan ini, atau tahun ini.',
    position: TourPosition.bottom,
  ),
  TourStep(
    targetKey: 'dashboard_button',
    title: 'Dashboard Home',
    description:
        'Monitoring sensor cabai secara real-time. Lihat data kelembapan tanah, suhu, pH tanah, cahaya, dan notifikasi peringatan.',
    position: TourPosition.bottom,
  ),
  TourStep(
    targetKey: 'laporan_button',
    title: 'Laporan',
    description:
        'Lihat analisis data dan laporan lengkap tentang pertanian Anda. Fitur ini membantu Anda memahami pola dan tren dari data sensor.',
    position: TourPosition.bottom,
  ),
  TourStep(
    targetKey: 'settings_button',
    title: 'Pengaturan',
    description:
        'Pilih varietas cabai aktif dan atur ambang batas (suhu, kelembapan udara/tanah, pH, intensitas cahaya) untuk setiap varietas.',
    position: TourPosition.bottom,
  ),
];

// Tour Overlay Widget
class TourOverlayWidget extends StatelessWidget {
  final TourStep step;
  final int currentStep;
  final int totalSteps;
  final GlobalKey? targetKey;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;

  const TourOverlayWidget({
    super.key,
    required this.step,
    required this.currentStep,
    required this.totalSteps,
    required this.targetKey,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  // Dapatkan posisi dan ukuran target button
  Rect? _getTargetRect() {
    if (targetKey?.currentContext == null) return null;

    try {
      final renderObject = targetKey!.currentContext!.findRenderObject();
      if (renderObject == null || renderObject is! RenderBox) return null;

      final RenderBox renderBox = renderObject;

      // Check if the RenderBox has been laid out
      if (!renderBox.hasSize) return null;

      final position = renderBox.localToGlobal(Offset.zero);

      return Rect.fromLTWH(
        position.dx,
        position.dy,
        renderBox.size.width,
        renderBox.size.height,
      );
    } catch (e) {
      // Return null if there's any error getting the rect
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final targetRect = _getTargetRect();

    return Stack(
      children: [
        // Dark overlay dengan hole untuk highlight
        CustomPaint(
          size: size,
          painter: _SpotlightPainter(targetRect: targetRect),
        ),

        // Highlight area untuk tap (jika ada targetRect)
        if (targetRect != null)
          Positioned(
            left: targetRect.left,
            top: targetRect.top,
            width: targetRect.width,
            height: targetRect.height,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

        // Info card (selalu di bottom)
        Positioned(
          bottom: 100,
          left: 20,
          right: 20,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${currentStep + 1} dari $totalSteps',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      Row(
                        children: List.generate(
                          totalSteps,
                          (index) => Container(
                            margin: const EdgeInsets.only(left: 4),
                            width: index == currentStep ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: index == currentStep
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Navigation buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Skip button
                      TextButton(
                        onPressed: onSkip,
                        child: const Text('Lewati'),
                      ),

                      // Navigation buttons
                      Row(
                        children: [
                          if (currentStep > 0)
                            TextButton(
                              onPressed: onPrevious,
                              child: const Text('Kembali'),
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: onNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              currentStep < totalSteps - 1
                                  ? 'Lanjut'
                                  : 'Selesai',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// CustomPainter untuk menggambar overlay dengan spotlight hole
class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;

  _SpotlightPainter({this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark overlay
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    if (targetRect != null) {
      // Buat path dengan hole untuk highlight
      final path = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

      // Tambahkan circular hole di posisi button dengan sedikit padding
      final spotlightPath = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            targetRect!.inflate(4), // Padding 4px
            const Radius.circular(12),
          ),
        );

      // Gabungkan dengan even-odd rule
      final combinedPath = Path.combine(
        PathOperation.difference,
        path,
        spotlightPath,
      );

      canvas.drawPath(combinedPath, paint);
    } else {
      // Jika tidak ada target, gambar overlay penuh
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
