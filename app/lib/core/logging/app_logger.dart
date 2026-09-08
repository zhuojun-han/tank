import 'package:flutter/foundation.dart';

abstract interface class AppLogger {
  void info(String event);
  void error(String event, {Object? error, StackTrace? stackTrace});
}

/// 仅记录预定义事件名称；调用方不得传入照片、备注或其他本地敏感数据。
final class DebugAppLogger implements AppLogger {
  const DebugAppLogger();

  @override
  void info(String event) => debugPrint('[INFO] $event');

  @override
  void error(String event, {Object? error, StackTrace? stackTrace}) {
    debugPrint('[ERROR] $event ${error.runtimeType}');
  }
}
