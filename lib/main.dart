import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/status_screens.dart';
import 'services/session.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.light;
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString('themeMode');
      mode = v == 'dark' ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> set(ThemeMode m) async {
    mode = m;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('themeMode', m == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // الإعدادات تأتي من android/app/google-services.json عبر إضافة google-services.
  await Firebase.initializeApp();
  final theme = ThemeController();
  await theme.load();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: theme),
      ChangeNotifierProvider(create: (_) => Session()),
      ChangeNotifierProvider(create: (_) => UiGate()),
    ],
    child: const App(),
  ));
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: theme.mode,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _splashDone
            ? const AuthGate(key: ValueKey('gate'))
            : SplashScreen(key: const ValueKey('splash'), onDone: () => setState(() => _splashDone = true)),
      ),
    );
  }
}

/// يقرر الشاشة حسب حالة الجلسة. الصلاحية النهائية دائمًا من Firestore (users/{uid}).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    switch (s.state) {
      case SessionState.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case SessionState.signedOut:
        return const LoginScreen();
      case SessionState.orphan:
        return const OrphanScreen();
      case SessionState.error:
        return ErrorScreen(message: s.errorMessage);
      case SessionState.ready:
        final u = s.appUser!;
        if (!u.isActive) return const AccountStatusScreen();
        final sectionOff = (u.section == 'boys' && !s.settings.boysEnabled) || (u.section == 'girls' && !s.settings.girlsEnabled);
        if (!u.isGeneral && (s.settings.maintenanceMode || sectionOff)) {
          return MaintenanceScreen(sectionDisabled: !s.settings.maintenanceMode && sectionOff);
        }
        return const HomeShell();
    }
  }
}
