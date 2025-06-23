// services/logger_service.dart
import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LoggerService {
  static bool _isEnabled = kDebugMode; // 디버그 모드에서만 활성화
  static LogLevel _minimumLevel = LogLevel.debug;

  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  static void setMinimumLevel(LogLevel level) {
    _minimumLevel = level;
  }

  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, error: error, stackTrace: stackTrace);
  }

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  static void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_isEnabled || level.index < _minimumLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(7);
    final logMessage = '[$timestamp] $levelStr: $message';

    // 콘솔에 출력
    if (kDebugMode) {
      print(logMessage);
      
      if (error != null) {
        print('Error: $error');
      }
      
      if (stackTrace != null) {
        print('StackTrace: $stackTrace');
      }
    }

    // 프로덕션에서는 로그 수집 서비스로 전송
    // (Firebase Crashlytics, Sentry 등)
    if (kReleaseMode && level == LogLevel.error) {
      _sendToLogService(level, message, error, stackTrace);
    }
  }

  static void _sendToLogService(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    // 실제 앱에서는 여기에 로그 수집 서비스 연동
    // 예: Firebase Crashlytics.instance.recordError(error, stackTrace);
  }
}