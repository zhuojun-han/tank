import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef NativeWebRequestHandler =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> params,
    );

/// Sends native changes (database reload, notification opening) to the one
/// locally packaged page. Events queued during initial loading are delivered
/// only after both DOM loading and the page's app.ready handshake.
class WebViewHostController {
  MethodChannel? _channel;
  bool _domReady = false;
  bool _appReady = false;
  final Map<String, Object?> _pendingEvents = {};

  bool get _ready => _domReady && _appReady;

  Future<void> emit(String name, [Object? detail]) async {
    if (!_ready || _channel == null) {
      _pendingEvents[name] = detail;
      return;
    }
    try {
      await _channel!.invokeMethod<void>('event', {
        'name': name,
        'detail': detail,
      });
    } on PlatformException {
      _pendingEvents[name] = detail;
      _resetReady();
    }
  }

  /// Call only after the JS page has installed its business event listeners.
  Future<void> markAppReady() async {
    _appReady = true;
    await _flushEvents();
  }

  Future<void> _markDomReady() async {
    _domReady = true;
    await _flushEvents();
  }

  void _resetReady() {
    _domReady = false;
    _appReady = false;
  }

  Future<void> _flushEvents() async {
    if (!_ready || _channel == null) return;
    final events = Map<String, Object?>.of(_pendingEvents);
    _pendingEvents.clear();
    for (final event in events.entries) {
      await emit(event.key, event.value);
    }
  }
}

/// The native view remains mounted across keyboard, fold and orientation
/// changes. Page content and business state are not rebuilt by Flutter.
class WebViewHost extends StatefulWidget {
  const WebViewHost({
    required this.handler,
    this.controller,
    this.onResume,
    super.key,
  });

  final NativeWebRequestHandler handler;
  final WebViewHostController? controller;
  final Future<void> Function()? onResume;

  @override
  State<WebViewHost> createState() => _WebViewHostState();
}

class _WebViewHostState extends State<WebViewHost> with WidgetsBindingObserver {
  late final WebViewHostController _controller =
      widget.controller ?? WebViewHostController();
  MethodChannel? _channel;
  String? _error;
  bool _loading = true;
  bool _handlingBack = false;
  bool _webViewPaused = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _created(int viewId) async {
    final channel = MethodChannel('lanjiao/local-webview/$viewId');
    _channel = channel;
    _controller._channel = channel;
    _controller._resetReady();
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'loading':
          _controller._resetReady();
          if (mounted) setState(() => _loading = true);
          return null;
        case 'request':
          final request = Map<String, dynamic>.from(call.arguments as Map);
          final method = request['method'] as String;
          final params = Map<String, dynamic>.from(request['params'] as Map);
          try {
            return await widget.handler(method, params);
          } on PlatformException {
            rethrow;
          } on FormatException catch (error) {
            throw PlatformException(
              code: 'invalid_input',
              message: error.message,
            );
          } catch (error, stack) {
            debugPrint('Native web request failed: $method\n$error\n$stack');
            throw PlatformException(
              code: 'operation_failed',
              message: '操作未完成，请重试。',
            );
          }
        case 'ready':
          if (mounted) setState(() => _loading = false);
          await _controller._markDomReady();
          return null;
        case 'error':
          if (mounted) {
            setState(() {
              _loading = false;
              _error = call.arguments as String? ?? '本地页面加载失败。';
            });
          }
          return null;
        default:
          throw MissingPluginException('Unsupported native callback');
      }
    });
    try {
      await channel.invokeMethod<void>('start');
      if (_webViewPaused) await _setLifecycle('paused');
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message ?? '本地页面无法打开。';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A native select dialog temporarily removes window focus. Pausing here
    // would hide that dialog; wait until the app is actually hidden instead.
    if (state == AppLifecycleState.inactive) return;
    final paused = state != AppLifecycleState.resumed;
    if (_webViewPaused == paused) return;
    _webViewPaused = paused;
    unawaited(_setLifecycle(paused ? 'paused' : 'resumed'));
  }

  Future<void> _setLifecycle(String state) async {
    try {
      await _channel?.invokeMethod<void>('lifecycle', state);
      if (state == 'resumed') await widget.onResume?.call();
    } on PlatformException catch (error) {
      debugPrint('WebView lifecycle update skipped: ${error.code}');
    }
  }

  Future<void> _back() async {
    if (_handlingBack) return;
    _handlingBack = true;
    try {
      final consumed = await _channel?.invokeMethod<bool>('back') ?? false;
      if (!consumed) await SystemNavigator.pop();
    } on PlatformException {
      await SystemNavigator.pop();
    } finally {
      _handlingBack = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.setMethodCallHandler(null);
    _controller._channel = null;
    _controller._resetReady();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const Scaffold(body: Center(child: Text('此入口用于 Android 本地网页应用。')));
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        backgroundColor: const Color(0xfff4faf8),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: AndroidView(
                  key: ValueKey(_generation),
                  viewType: 'lanjiao/local-webview',
                  layoutDirection: TextDirection.ltr,
                  onPlatformViewCreated: _created,
                ),
              ),
              if (_loading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0xfff4faf8),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (_error != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xfff4faf8),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () {
                                _channel?.setMethodCallHandler(null);
                                _controller._resetReady();
                                setState(() {
                                  _error = null;
                                  _loading = true;
                                  _generation++;
                                });
                              },
                              child: const Text('重新打开'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
