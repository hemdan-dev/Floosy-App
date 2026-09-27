import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'app_providers.dart';
import 'core/app_localizations.dart';
import 'core/app_theme.dart';
import 'ui/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FloosyApp()));
}

class FloosyApp extends ConsumerStatefulWidget {
  const FloosyApp({super.key});

  @override
  ConsumerState<FloosyApp> createState() => _FloosyAppState();
}

class _FloosyAppState extends ConsumerState<FloosyApp>
    with WidgetsBindingObserver {
  Locale _locale = const Locale('en');
  ThemeMode _themeMode = ThemeMode.system;
  bool _ready = false;
  bool _unlocked = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final db = ref.read(databaseProvider);
    final locale = await db.getSetting('locale') ?? 'en';
    final theme = await db.getSetting('theme') ?? 'system';
    final lockEnabled = await db.getSetting('lockEnabled') == 'true';
    if (!mounted) return;
    setState(() {
      _locale = Locale(locale);
      _themeMode = ThemeMode.values.firstWhere(
        (item) => item.name == theme,
        orElse: () => ThemeMode.system,
      );
      _unlocked = !lockEnabled;
      _ready = true;
    });
    if (lockEnabled) await _unlock();
  }

  Future<void> _unlock() async {
    try {
      final success = await LocalAuthentication().authenticate(
        localizedReason: 'Unlock Floosy',
        persistAcrossBackgrounding: true,
      );
      if (mounted) setState(() => _unlocked = success);
    } catch (_) {
      if (mounted) setState(() => _unlocked = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed) return;
    try {
      await ref.read(captureServiceProvider).ingestPlatformCaptures();
    } catch (_) {
      // Shortcut/SMS capture is optional and can be retried on the next resume.
    }
    final enabled =
        await ref.read(databaseProvider).getSetting('lockEnabled') == 'true';
    if (enabled && mounted) {
      setState(() => _unlocked = false);
      await _unlock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Floosy',
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: !_ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : !_unlocked
          ? _LockedScreen(onUnlock: _unlock)
          : HomeShell(
              onLocaleChanged: (locale) => setState(() => _locale = locale),
              onThemeChanged: (mode) => setState(() => _themeMode = mode),
            ),
    );
  }
}

class _LockedScreen extends StatelessWidget {
  const _LockedScreen({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton.icon(
          onPressed: onUnlock,
          icon: const Icon(Icons.lock_open_rounded),
          label: const Text('Unlock Floosy'),
        ),
      ),
    );
  }
}
