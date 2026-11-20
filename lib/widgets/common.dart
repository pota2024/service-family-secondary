import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme.dart';

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// خلفية سماوية متدرجة كما في التصميم المرجعي.
class SkyBackground extends StatelessWidget {
  final Widget child;
  const SkyBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF0A1F5C), Color(0xFF0B1226)]
              : const [Color(0xFF6FC3FF), Color(0xFFBFE0FF), AppColors.paleSky],
          stops: dark ? null : const [0, 0.45, 1],
        ),
      ),
      child: child,
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF16213F) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: AppColors.royal.withOpacity(dark ? 0 : 0.10), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  const GradientButton({super.key, required this.label, this.onPressed, this.loading = false, this.icon});
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.royal.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                      Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

class SoftOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const SoftOutlineButton({super.key, required this.label, this.onPressed, this.icon});
  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.person_add_alt_1, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        style: OutlinedButton.styleFrom(
          foregroundColor: dark ? Colors.white : AppColors.royal,
          backgroundColor: dark ? const Color(0xFF16213F) : Colors.white,
          side: BorderSide(color: dark ? Colors.white24 : const Color(0xFFD8E3FA)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

/// صورة شخصية: data URI أو رابط أو الحرف الأول من الاسم.
class Avatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  const Avatar({super.key, this.photoUrl, required this.name, this.radius = 28});

  static final Map<String, Uint8List> _cache = {};

  ImageProvider? _provider() {
    final u = photoUrl;
    if (u == null || u.isEmpty) return null;
    if (u.startsWith('data:')) {
      final bytes = _cache.putIfAbsent(u, () => base64Decode(u.substring(u.indexOf(',') + 1)));
      return MemoryImage(bytes);
    }
    if (u.startsWith('http')) return NetworkImage(u);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? p;
    try {
      p = _provider();
    } catch (_) {
      p = null;
    }
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.paleSky,
        backgroundImage: p,
        child: p == null
            ? Text(name.isEmpty ? '؟' : String.fromCharCode(name.runes.first),
                style: TextStyle(fontSize: radius * 0.8, color: AppColors.royal, fontWeight: FontWeight.w800))
            : null,
      ),
    );
  }
}

/// شعار: دائرة بيضاء وصليب ذهبي.
class CrossLogo extends StatelessWidget {
  final double size;
  const CrossLogo({super.key, this.size = 96});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: AppColors.gold, width: 3),
          boxShadow: [BoxShadow(color: AppColors.royal.withOpacity(0.25), blurRadius: 20)],
        ),
        child: CustomPaint(painter: _CrossPainter()),
      );
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = AppColors.royal;
    final c = s.center(Offset.zero);
    final w = s.width * 0.12;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w, height: s.height * 0.56), Radius.circular(w / 3)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, -s.height * 0.06), width: s.width * 0.36, height: w), Radius.circular(w / 3)), p);
    canvas.drawCircle(c.translate(0, -s.height * 0.06), s.width * 0.05, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.royalDark,
      behavior: SnackBarBehavior.floating,
    ));
}
