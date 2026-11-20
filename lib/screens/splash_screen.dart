import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../core/theme.dart';

/// مقدمة سينمائية: سماء متحركة وسحب وصورة الفارس تجري بحركة خفيفة ثم ظهور الاسم.
/// الصورة الأصلية تُوضع في assets/images/intro_george.(png|webp|jpg).
/// إن لم توجد يظهر مشهد بديل مرسوم بالكود.
class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _total = Duration(seconds: 6);
  late final AnimationController _c = AnimationController(vsync: this, duration: _total);
  Uint8List? _hero;
  bool _canSkip = false;
  bool _done = false;
  Timer? _skipTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _loadHero();
    _c.forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
    _skipTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _canSkip = true);
    });
  }

  Future<void> _loadHero() async {
    for (final n in ['intro_george.png', 'intro_george.webp', 'intro_george.jpg']) {
      try {
        final d = await rootBundle.load('assets/images/$n');
        if (mounted) setState(() => _hero = d.buffer.asUint8List());
        return;
      } catch (_) {}
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final gallop = math.sin(t * math.pi * 2 * 9) * 4; // اهتزاز الركض
          final zoom = 1.0 + 0.10 * t;
          final slide = (1 - Curves.easeOutCubic.transform(math.min(1, t / 0.45))) * -size.width * 0.5;
          final titleOpacity = Curves.easeIn.transform(((t - 0.45) / 0.3).clamp(0.0, 1.0));
          final fadeOut = ((t - 0.92) / 0.08).clamp(0.0, 1.0);
          return Stack(fit: StackFit.expand, children: [
            CustomPaint(painter: _SkyPainter(t)),
            Positioned(
              left: 0,
              right: 0,
              top: size.height * 0.08,
              height: size.height * 0.56,
              child: Transform.translate(
                offset: Offset(slide, gallop),
                child: Transform.scale(
                  scale: zoom,
                  child: _hero != null
                      ? Image.memory(_hero!, fit: BoxFit.contain)
                      : CustomPaint(painter: _PlaceholderHeroPainter()),
                ),
              ),
            ),
            if (kDebugMode && _hero == null)
              const Positioned(
                top: 60,
                left: 16,
                right: 16,
                child: Text('ضع صورة المقدمة في assets/images/intro_george.png',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            Positioned(
              left: 24,
              right: 24,
              bottom: size.height * 0.10,
              child: Opacity(
                opacity: titleOpacity,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - titleOpacity)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: const [
                    Text(AppConfig.appName,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 14, color: Colors.black54)])),
                    SizedBox(height: 8),
                    Text(AppConfig.churchName,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 8, color: Colors.black54)])),
                  ]),
                ),
              ),
            ),
            if (_canSkip)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(backgroundColor: Colors.black26, foregroundColor: Colors.white),
                  child: const Text('تخطي'),
                ),
              ),
            IgnorePointer(child: Container(color: Colors.white.withOpacity(fadeOut))),
          ]);
        },
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  final double t;
  _SkyPainter(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(AppColors.navy, AppColors.royalDark, t)!,
            Color.lerp(AppColors.royal, AppColors.sky, t)!,
            const Color(0xFFBFE0FF),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    // سحب تتحرك ببطء
    final cloud = Paint()..color = Colors.white.withOpacity(0.18);
    for (var i = 0; i < 6; i++) {
      final speed = 0.15 + i * 0.06;
      final x = ((i * 0.23 + t * speed) % 1.2 - 0.1) * s.width;
      final y = s.height * (0.10 + i * 0.09);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: s.width * 0.5, height: 38 + i * 4), cloud);
    }
    // وهج ذهبي خلف الفارس
    final glow = Paint()
      ..shader = RadialGradient(colors: [AppColors.gold.withOpacity(0.35 * t), Colors.transparent])
          .createShader(Rect.fromCircle(center: Offset(s.width / 2, s.height * 0.33), radius: s.width * 0.7));
    canvas.drawRect(rect, glow);
    // أرض / ضباب سفلي
    canvas.drawRect(
      Rect.fromLTWH(0, s.height * 0.72, s.width, s.height * 0.28),
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppColors.navy.withOpacity(0.85)])
            .createShader(Rect.fromLTWH(0, s.height * 0.72, s.width, s.height * 0.28)),
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.t != t;
}

/// مشهد بديل (قبل إضافة الصورة الأصلية): صليب ذهبي بهالة وأشعة.
class _PlaceholderHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final ray = Paint()..color = AppColors.gold.withOpacity(0.22);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - 0.06) * s.width * 0.6, c.dy + math.sin(a - 0.06) * s.width * 0.6)
        ..lineTo(c.dx + math.cos(a + 0.06) * s.width * 0.6, c.dy + math.sin(a + 0.06) * s.width * 0.6)
        ..close();
      canvas.drawPath(path, ray);
    }
    canvas.drawCircle(c, s.width * 0.22, Paint()..color = Colors.white.withOpacity(0.15));
    final gold = Paint()..color = AppColors.gold;
    final w = s.width * 0.06;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w, height: s.width * 0.34), Radius.circular(w / 3)), gold);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, -s.width * 0.04), width: s.width * 0.22, height: w), Radius.circular(w / 3)), gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
