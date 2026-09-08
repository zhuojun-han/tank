import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/notifications/local_notification.dart';
import '../features/maintenance/application/maintenance_notification_providers.dart';
import 'router.dart';
import 'theme.dart';

class LanjiaoApp extends ConsumerStatefulWidget {
  const LanjiaoApp({this.router, super.key});

  final GoRouter? router;

  @override
  ConsumerState<LanjiaoApp> createState() => _LanjiaoAppState();
}

class _LanjiaoAppState extends ConsumerState<LanjiaoApp>
    with WidgetsBindingObserver {
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = widget.router ?? appRouter;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(notificationsEnabledProvider)) {
      unawaited(
        ref.read(maintenanceNotificationCoordinatorProvider).reconcileNow(),
      );
    }
  }

  @override
  void didUpdateWidget(covariant LanjiaoApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      _router = widget.router ?? appRouter;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(maintenanceNotificationCoordinatorProvider);
    ref.listen(localNotificationTapProvider, (_, next) {
      next.whenData(_handleNotificationTap);
    });
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return MaterialApp.router(
      title: '澜礁水质助手',
      debugShowCheckedModeBanner: false,
      theme: LanjiaoTheme.light,
      darkTheme: LanjiaoTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }

  void _handleNotificationTap(LocalNotificationTap tap) {
    final location = switch (tap.payload.type) {
      LocalNotificationType.maintenanceTask => Uri(
        path: '/maintenance',
        queryParameters: <String, String>{'taskId': tap.payload.targetId},
      ).toString(),
      LocalNotificationType.testTimer => Uri(
        path: '/test-flow',
        queryParameters: <String, String>{'sessionId': tap.payload.targetId},
      ).toString(),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _router.go(location);
      }
    });
  }
}
