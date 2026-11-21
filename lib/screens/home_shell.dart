import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session.dart';
import 'activities_screen.dart';
import 'chat_screen.dart';
import 'competitions_screen.dart';
import 'home_tab.dart';
import 'manage_screen.dart';
import 'profile_screen.dart';

/// الهيكل الرئيسي. المخدوم: الرئيسية، مسابقات، أنشطة، شات، ملفي.
/// الخادم/العام: الرئيسية، الإدارة، مسابقات، أنشطة، شات (الملف من صورة الرأس).
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
    final tabs = <(String, IconData, IconData, Widget)>[
      ('الرئيسية', Icons.home_outlined, Icons.home, const HomeTab()),
      if (me.canReview) ('الإدارة', Icons.dashboard_customize_outlined, Icons.dashboard_customize, const ManageTab()),
      ('مسابقات', Icons.emoji_events_outlined, Icons.emoji_events, const CompetitionsScreen()),
      ('أنشطة', Icons.event_outlined, Icons.event, const ActivitiesScreen()),
      ('الشات', Icons.chat_bubble_outline, Icons.chat_bubble, const ChatTab()),
      if (!me.canReview) ('ملفي', Icons.person_outline, Icons.person, const ProfileScreen()),
    ];
    if (_i >= tabs.length) _i = 0;
    return Scaffold(
      body: IndexedStack(index: _i, children: [for (final t in tabs) t.$4]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.$2), selectedIcon: Icon(t.$3), label: t.$1)],
      ),
    );
  }
}
