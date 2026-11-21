import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/parts.dart';

/// بطاقة العضوية: QR يحتوي معرّف المخدوم فقط (لا هاتف ولا بيانات خاصة).
class MemberCardScreen extends StatelessWidget {
  const MemberCardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final me = s.appUser!;
    final name = s.profile?.displayName ?? '';
    return Scaffold(
      appBar: gradAppBar('بطاقتي'),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Avatar(photoUrl: s.profile?.photoUrl, name: name, radius: 46),
                const SizedBox(height: 10),
                Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                Text(roleLabel(me.role, me.section), style: const TextStyle(color: AppColors.royal, fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFD8E3FA))),
                  child: QrImageView(data: 'SF1|${me.uid}', size: 220, backgroundColor: Colors.white),
                ),
                const SizedBox(height: 10),
                Text('SF-${me.uid.substring(0, 8).toUpperCase()}', style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('اعرض هذا الرمز على الخادم لتسجيل حضورك', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
