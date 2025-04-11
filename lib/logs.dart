import 'package:blue_notify/main.dart';
import 'package:blue_notify/settings.dart';
import 'package:f_logs/f_logs.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry/sentry_io.dart';
import 'package:stack_trace/stack_trace.dart';
import 'dart:developer' as developer;

String webLogs = "";

void webLog(String message) {
  print(message);
  webLogs += "$message\n";
}

class Logs {
  static Future<bool> sendLogs() async {
    String text;
    if (!kIsWeb) {
      FLog.warning(text: 'Exporting logs');
      var file = await FLog.exportLogs();
      text = await file.readAsString();
    } else {
      webLog('Exporting logs');
      text = webLogs;
    }

    // limit to last 5000 lines
    var lines = text.split('\n');
    if (lines.length > 5000) {
      text = lines.sublist(lines.length - 5000).join('\n');
    }

    var success = false;

    try {
      configSentryUser();
      // Send with sentry
      final attachment = SentryAttachment.fromIntList(
        text.codeUnits,
        'logs.txt',
        contentType: 'text/plain',
      );
      Sentry.captureMessage('User Sent Logs', withScope: (scope) {
        scope.addAttachment(attachment);
      });
      success = true;
    } catch (e) {
      Sentry.captureException(e);
      if (!kIsWeb) {
        FLog.warning(text: 'Error sending logs to sentry: $e');
      } else {
        webLog('Error sending logs to sentry: $e');
      }
    }
    if (success) {
      if (!kIsWeb) {
        FLog.warning(text: 'Logs sent');
      } else {
        webLog('Logs sent');
      }
      return true;
    } else {
      if (!kIsWeb) {
        FLog.warning(text: 'Failed to send logs');
      } else {
        webLog('Failed to send logs');
      }
      return false;
    }
  }

  static void clearLogs() {
    if (!kIsWeb) {
      FLog.clearLogs();
    } else {
      webLogs = "";
    }
  }

  static void debug({
    String? className,
    String? methodName,
    required String text,
    dynamic exception,
    String? dataLogType,
    StackTrace? stacktrace,
  }) async {
    _logThis(className, methodName, text, LogLevel.DEBUG, exception,
        dataLogType, stacktrace);
  }

  /// info
  ///
  /// Logs 'String' data along with class & function name to hourly based file
  /// with formatted timestamps.
  ///
  /// @param className    the class name
  /// @param methodName the method name
  /// @param text         the text
  static void info({
    String? className,
    String? methodName,
    required String text,
    dynamic exception,
    String? dataLogType,
    StackTrace? stacktrace,
  }) async {
    _logThis(className, methodName, text, LogLevel.INFO, exception, dataLogType,
        stacktrace);
  }

  /// warning
  ///
  /// Logs 'String' data along with class & function name to hourly based file
  /// with formatted timestamps.
  ///
  /// @param className    the class name
  /// @param methodName the method name
  /// @param text         the text
  static void warning({
    String? className,
    String? methodName,
    required String text,
    dynamic exception,
    String? dataLogType,
    StackTrace? stacktrace,
  }) async {
    _logThis(className, methodName, text, LogLevel.WARNING, exception,
        dataLogType, stacktrace);
  }

  /// error
  ///
  /// Logs 'String' data along with class & function name to hourly based file
  /// with formatted timestamps.
  ///
  /// @param className    the class name
  /// @param methodName the method name
  /// @param text         the text
  static void error({
    String? className,
    String? methodName,
    required String text,
    dynamic exception,
    String? dataLogType,
    StackTrace? stacktrace,
  }) async {
    _logThis(className, methodName, text, LogLevel.ERROR, exception,
        dataLogType, stacktrace);
  }

  /// severe
  ///
  /// Logs 'String' data along with class & function name to hourly based file
  /// with formatted timestamps.
  ///
  /// @param className    the class name
  /// @param methodName the method name
  /// @param text         the text
  static void severe({
    String? className,
    String? methodName,
    required String text,
    dynamic exception,
    String? dataLogType,
    StackTrace? stacktrace,
  }) async {
    _logThis(className, methodName, text, LogLevel.SEVERE, exception,
        dataLogType, stacktrace);
  }

  /// fatal
  ///
  /// Logs 'String' data along with class & function name to hourly based file
  /// with formatted timestamps.
  ///
  /// @param className    the class name
  /// @param methodName the method name
  /// @param text         the text
  static void fatal({
    String? className,
    String? methodName,
    required String text,
    dynamic exception,
    String? dataLogType,
    StackTrace? stacktrace,
  }) async {
    _logThis(className, methodName, text, LogLevel.FATAL, exception,
        dataLogType, stacktrace);
  }

  static void _logThis(
      String? className,
      String? methodName,
      String text,
      LogLevel type,
      dynamic exception,
      String? dataLogType,
      StackTrace? stacktrace) {
    // This variable can be ClassName.MethodName or only a function name, when it doesn't belong to a class, e.g. main()
    var member = Trace.current().frames[2].member!;

    //check to see if className is not provided
    //then its already been taken from calling class
    if (className == null) {
      // If there is a . in the member name, it means the method belongs to a class. Thus we can split it.
      if (member.contains(".")) {
        className = member.split(".")[0];
      } else {
        className = "";
      }
    }

    //check to see if methodName is not provided
    //then its already been taken from calling class
    if (methodName == null) {
      // If there is a . in the member name, it means the method belongs to a class. Thus we can split it.
      if (member.contains(".")) {
        methodName = member.split(".")[1];
      } else {
        methodName = member;
      }
    }

    // try adding as a breadcrumb to sentry
    try {
      var sentryLevel = SentryLevel.info;
      switch (type) {
        case LogLevel.TRACE:
          sentryLevel = SentryLevel.debug;
          break;
        case LogLevel.DEBUG:
          sentryLevel = SentryLevel.debug;
          break;
        case LogLevel.INFO:
          sentryLevel = SentryLevel.info;
          break;
        case LogLevel.WARNING:
          sentryLevel = SentryLevel.warning;
          break;
        case LogLevel.ERROR:
          sentryLevel = SentryLevel.error;
          break;
        case LogLevel.SEVERE:
          sentryLevel = SentryLevel.error;
          break;
        case LogLevel.FATAL:
          sentryLevel = SentryLevel.fatal;
          break;
        default:
          sentryLevel = SentryLevel.info;
          break;
      }
      if (type != LogLevel.TRACE) {
        Sentry.addBreadcrumb(Breadcrumb(
          message: text,
          category: className,
          level: sentryLevel,
          timestamp: DateTime.now().toUtc(),
        ));
      }
    } catch (e) {
      if (!kIsWeb) {
        FLog.warning(text: 'Error adding breadcrumb: $e');
      } else {
        webLog('Error adding breadcrumb: $e');
      }
    }

    if (stacktrace == null) {
      if (type == LogLevel.ERROR ||
          type == LogLevel.SEVERE ||
          type == LogLevel.FATAL) {
        stacktrace = StackTrace.current;
      }
    }

    if (!kIsWeb) {
      FLog.logThis(
        className: className,
        methodName: methodName,
        text: text,
        type: type,
        exception: exception,
        dataLogType: dataLogType,
        stacktrace: stacktrace,
      );
    } else {
      webLog('$type: $className.$methodName: $text');
      if (stacktrace != null) {
        webLog('Stacktrace: $stacktrace');
      }
    }
  }
}
