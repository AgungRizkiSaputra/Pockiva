import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/application/auth_controller.dart';

class TabunganPribadiApp extends ConsumerStatefulWidget {
  const TabunganPribadiApp({super.key});

  @override
  ConsumerState<TabunganPribadiApp> createState() => _TabunganPribadiAppState();
}

class _TabunganPribadiAppState extends ConsumerState<TabunganPribadiApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref.read(authControllerProvider.notifier).checkInactivityOnResume(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) =>
          ref.read(authControllerProvider.notifier).recordUserActivity(),
      onPointerSignal: (_) =>
          ref.read(authControllerProvider.notifier).recordUserActivity(),
      child: MaterialApp.router(
        title: 'Tabungan Pribadi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        routerConfig: router,
        locale: const Locale('id', 'ID'),
        supportedLocales: const [
          Locale('id', 'ID'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
