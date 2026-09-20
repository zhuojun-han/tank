import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/database/app_database.dart';
import 'webview/native_platform_services.dart';
import 'webview/native_state_store.dart';
import 'webview/native_task_actions.dart';
import 'webview/webview_host.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '澜礁',
      home: LocalWebsiteApp(),
    ),
  );
}

class LocalWebsiteApp extends StatefulWidget {
  const LocalWebsiteApp({super.key});

  @override
  State<LocalWebsiteApp> createState() => _LocalWebsiteAppState();
}

class _LocalWebsiteAppState extends State<LocalWebsiteApp> {
  final _database = AppDatabase.open(seedDefaultTank: false);
  final _host = WebViewHostController();
  late final _store = NativeStateStore(_database);
  late final _tasks = NativeTaskActions(_database, _store);
  late final _platform = NativePlatformServices(_database, emit: _host.emit);
  late final Future<void> _initialized = _platform.initialize();
  Future<void> _requests = Future.value();

  Future<Map<String, dynamic>> _handle(
    String method,
    Map<String, dynamic> params,
  ) {
    // Serialize commands around the real database, including restore. A page
    // cannot commit a stale snapshot while a native operation is still open.
    final operation = _requests.then((_) async {
      await _initialized;
      switch (method) {
        case 'app.resume':
          await _platform.onResume();
          return <String, dynamic>{'resumed': true};
        case 'app.ready':
          await _host.markAppReady();
          return <String, dynamic>{'ready': true};
        case 'state.read':
          return _store.readState();
        case 'state.save':
          final revision = params['expectedRevision'];
          final state = params['state'];
          if (revision is! int || state is! Map) {
            throw const FormatException('保存请求无效，请重新读取数据。');
          }
          await _store.commitState(
            Map<String, dynamic>.from(state),
            expectedRevision: revision,
          );
          await _platform.reconcile(force: false);
          return _store.readState();
        case 'task.action':
          await _tasks.apply(params);
          await _platform.reconcile(force: false);
          return _store.readState();
        default:
          return _platform.handle(method, params);
      }
    });
    _requests = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  @override
  void dispose() {
    unawaited(
      _requests.whenComplete(() async {
        await _platform.dispose();
        await _database.close();
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: const Color(0xfff4faf8),
      systemNavigationBarColor: const Color(0xfff4faf8),
    ),
    child: WebViewHost(
      handler: _handle,
      controller: _host,
      onResume: () async {
        await _handle('app.resume', {});
      },
    ),
  );
}
