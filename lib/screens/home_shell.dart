import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/queries.dart';
import '../services/session.dart';
import 'home_tab.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';

/// الهيكل الرئيسي. تظهر فقط التبويبات المنفذة فعليًا (المراحل التالية تضيف الباقي).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    final tabs = <_Tab>[
      _Tab('الرئيسية', Icons.home_outlined, Icons.home, const HomeTab()),
      if (me.canReview) _Tab('الطلبات', Icons.how_to_reg_outlined, Icons.how_to_reg, const RequestsScreen(), badge: true),
      _Tab('ملفي', Icons.person_outline, Icons.person, const ProfileScreen()),
    ];
    if (_i >= tabs.length) _i = 0;
    return Scaffold(
      body: IndexedStack(index: _i, children: [for (final t in tabs) t.page]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: t.badge ? _PendingBadge(icon: t.icon) : Icon(t.icon),
              selectedIcon: t.badge ? _PendingBadge(icon: t.selectedIcon) : Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _Tab {
  final String label;
  final IconData icon, selectedIcon;
  final Widget page;
  final bool badge;
  _Tab(this.label, this.icon, this.selectedIcon, this.page, {this.badge = false});
}

class _PendingBadge extends StatelessWidget {
  final IconData icon;
  const _PendingBadge({required this.icon});
  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: pendingRequestsQuery(me).snapshots(),
      builder: (context, snap) {
        final n = snap.data?.size ?? 0;
        return Badge(isLabelVisible: n > 0, label: Text('$n'), child: Icon(icon));
      },
    );
  }
}
