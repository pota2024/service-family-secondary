import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../widgets/common.dart';

class _StatusScaffold extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final List<Widget> extra;
  const _StatusScaffold({required this.icon, required this.color, required this.title, required this.message, this.extra = const []});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(radius: 36, backgroundColor: color.withOpacity(0.15), child: Icon(icon, size: 38, color: color)),
                    const SizedBox(height: 16),
                    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Text(message, textAlign: TextAlign.center, style: const TextStyle(height: 1.7)),
                    ...extra,
                    const SizedBox(height: 18),
                    SoftOutlineButton(label: 'تسجيل الخروج', icon: Icons.logout, onPressed: AuthService.signOut),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// حالات الحساب غير المفعّل: pending / rejected / suspended.
class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final u = s.appUser!;
    final req = s.myRequest;
    switch (u.status) {
      case 'rejected':
        return const _StatusScaffold(
          icon: Icons.block,
          color: AppColors.danger,
          title: 'تم رفض طلب التسجيل',
          message: 'يمكنك التواصل مع الخدام لمعرفة السبب.',
        );
      case 'suspended':
        return const _StatusScaffold(
          icon: Icons.pause_circle_outline,
          color: AppColors.danger,
          title: 'الحساب موقوف',
          message: 'تم إيقاف حسابك مؤقتًا. تواصل مع الإدارة.',
        );
      default:
        final what = req == null
            ? ''
            : switch (req.requestedRole) {
                'servant' => 'طلبك: خادم/خادمة – ${sectionLabel(req.requestedSection)}',
                'general' => 'طلبك: حساب عام – تعتمده الإدارة العامة فقط',
                _ => 'طلبك: مخدوم – ${sectionLabel(req.requestedSection)}',
              };
        return _StatusScaffold(
          icon: Icons.hourglass_top,
          color: AppColors.gold,
          title: 'طلبك قيد المراجعة',
          message: 'تم استلام طلب التسجيل. سيتم تفعيل حسابك بعد موافقة الإدارة، وسيظهر لك ذلك هنا تلقائيًا.',
          extra: [if (what.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(what, style: const TextStyle(fontWeight: FontWeight.w700)))],
        );
    }
  }
}

class MaintenanceScreen extends StatelessWidget {
  final bool sectionDisabled;
  const MaintenanceScreen({super.key, this.sectionDisabled = false});
  @override
  Widget build(BuildContext context) => _StatusScaffold(
        icon: Icons.construction,
        color: AppColors.royal,
        title: sectionDisabled ? 'القسم متوقف مؤقتًا' : 'التطبيق في وضع الصيانة',
        message: 'يرجى المحاولة لاحقًا.',
      );
}

/// حساب Auth موجود بلا مستند users (فشل نادر أثناء التسجيل).
class OrphanScreen extends StatelessWidget {
  const OrphanScreen({super.key});
  @override
  Widget build(BuildContext context) => const _StatusScaffold(
        icon: Icons.error_outline,
        color: AppColors.danger,
        title: 'الحساب غير مكتمل',
        message: 'لم تكتمل عملية التسجيل. اطلب من الإدارة حذف الحساب من لوحة Firebase ثم سجّل من جديد.',
      );
}

class ErrorScreen extends StatelessWidget {
  final String? message;
  const ErrorScreen({super.key, this.message});
  @override
  Widget build(BuildContext context) => _StatusScaffold(
        icon: Icons.cloud_off,
        color: AppColors.danger,
        title: 'تعذر تحميل بيانات الحساب',
        message: 'تحقق من الاتصال بالإنترنت ثم أعد فتح التطبيق.\n${message ?? ''}',
      );
}
