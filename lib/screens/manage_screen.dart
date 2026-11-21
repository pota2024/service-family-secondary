
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/data.dart';
import '../services/queries.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/parts.dart';
import 'attendance_screen.dart';
import 'dashboard_screen.dart';
import 'points_screen.dart';
import 'reports_screen.dart';
import 'requests_screen.dart';
import 'users_screen.dart';
import 'verses_screen.dart';

/// لوحة تحكم الخادم/العام: كل أدوات الإدارة في مكان واحد.
class ManageTab extends StatelessWidget {
  const ManageTab({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;

    void go(Widget w) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => w),
        );

    final items = <_Item>[
      _Item(
        'مسح QR للحضور',
        Icons.qr_code_scanner,
        () => go(const ScanAttendanceScreen()),
        primary: true,
      ),
      _Item(
        'حضور يدوي',
        Icons.fact_check,
        () => go(const ManualAttendanceScreen()),
      ),
      _Item(
        'إضافة نقاط',
        Icons.stars,
        () => go(const AddPointsScreen()),
      ),
      _Item(
        'طلبات التسجيل',
        Icons.how_to_reg,
        () => go(const RequestsScreen()),
        badge: true,
      ),
      _Item(
        'المستخدمون',
        Icons.manage_accounts,
        () => go(const UsersScreen()),
      ),
      _Item(
        'الإحصائيات',
        Icons.insights,
        () => go(const DashboardScreen()),
      ),
      _Item(
        'التقارير',
        Icons.assessment,
        () => go(const ReportsScreen()),
      ),
      _Item(
        'إرسال إشعار',
        Icons.campaign,
        () => _announce(context, me),
      ),
      if (me.isGeneral)
        _Item(
          'الآيات',
          Icons.menu_book,
          () => go(const VersesScreen()),
        ),
      if (me.isGeneral)
        _Item(
          'إعدادات التطبيق',
          Icons.settings,
          () => go(const AppSettingsScreen()),
        ),
    ];

    return Scaffold(
      appBar: gradAppBar(
        me.isGeneral ? 'لوحة الإدارة' : 'لوحة تحكم الخادم',
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(14),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: [for (final i in items) _Tile(i)],
      ),
    );
  }
}

class _Item {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;
  final bool primary;

  _Item(
    this.title,
    this.icon,
    this.onTap, {
    this.badge = false,
    this.primary = false,
  });
}

class _Tile extends StatelessWidget {
  final _Item i;

  const _Tile(this.i);

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;

    Widget icon = Icon(
      i.icon,
      size: 34,
      color: i.primary ? Colors.white : AppColors.royal,
    );

    if (i.badge) {
      icon = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: pendingRequestsQuery(me).snapshots(),
        builder: (c, s) => Badge(
          isLabelVisible: (s.data?.size ?? 0) > 0,
          label: Text('${s.data?.size ?? 0}'),
          child: Icon(
            i.icon,
            size: 34,
            color: AppColors.royal,
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: i.onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: i.primary ? AppColors.buttonGradient : null,
          color: i.primary
              ? null
              : (isDark(context)
                  ? const Color(0xFF16213F)
                  : Colors.white),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.royal.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 8),
            Text(
              i.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: i.primary ? Colors.white : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _announce(BuildContext context, AppUser me) async {
  final title = TextEditingController();
  final body = TextEditingController();

  var target = me.isGeneral ? 'all' : me.section;

  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: const Text('إعلان إداري'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: body,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'النص',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: target,
                decoration: const InputDecoration(
                  labelText: 'إلى',
                ),
                items: [
                  if (me.isGeneral || me.section == 'boys')
                    const DropdownMenuItem(
                      value: 'boys',
                      child: Text('البنين'),
                    ),
                  if (me.isGeneral || me.section == 'girls')
                    const DropdownMenuItem(
                      value: 'girls',
                      child: Text('البنات'),
                    ),
                  if (me.isGeneral)
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('الجميع'),
                    ),
                ],
                onChanged: (v) => setS(() => target = v ?? target),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('إرسال'),
          ),
        ],
      ),
    ),
  );

  title.dispose();
  body.dispose();

  if (ok != true || !context.mounted) return;

  if (title.text.trim().isEmpty) {
    showSnack(context, 'اكتب عنوان الإعلان', error: true);
    return;
  }

  try {
    await sendNotification(
      target,
      title.text.trim(),
      body.text.trim(),
      'announcement',
    );

    if (context.mounted) {
      showSnack(context, 'تم إرسال الإعلان');
    }
  } catch (e) {
    if (context.mounted) {
      showSnack(
        context,
        AuthService.arabicError(e),
        error: true,
      );
    }
  }
}

/// إعدادات التطبيق (للعام): settings/app.
class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradAppBar('إعدادات التطبيق'),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.doc('settings/app').snapshots(),
        builder: (c, s) {
          final d = s.data?.data() ?? {};

          Future<void> set(String k, bool v) async {
            try {
              await db.doc('settings/app').set({
                'appName': d['appName'] ?? 'خدمة أسرة ثانوي',
                'boysEnabled': d['boysEnabled'] ?? true,
                'girlsEnabled': d['girlsEnabled'] ?? true,
                'registrationEnabled':
                    d['registrationEnabled'] ?? true,
                'maintenanceMode': d['maintenanceMode'] ?? false,
                k: v,
              });
            } catch (e) {
              if (context.mounted) {
                showSnack(
                  context,
                  AuthService.arabicError(e),
                  error: true,
                );
              }
            }
          }

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('التسجيل الجديد مفتوح'),
                      value: d['registrationEnabled'] != false,
                      onChanged: (v) => set('registrationEnabled', v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('قسم البنين مفعّل'),
                      value: d['boysEnabled'] != false,
                      onChanged: (v) => set('boysEnabled', v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('قسم البنات مفعّل'),
                      value: d['girlsEnabled'] != false,
                      onChanged: (v) => set('girlsEnabled', v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text(
                        'وضع الصيانة (يغلق التطبيق عن غير العام)',
                      ),
                      value: d['maintenanceMode'] == true,
                      onChanged: (v) => set('maintenanceMode', v),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
