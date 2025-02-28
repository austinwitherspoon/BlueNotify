import 'package:blue_notify/main.dart';
import 'package:blue_notify/settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f_logs/f_logs.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry/sentry_io.dart';
import 'package:stack_trace/stack_trace.dart';

class Logs {
  static Future<void> sendLogs() async {
    FLog.warning(text: 'Exporting logs');
    var file = await FLog.exportLogs();
    var text = await file.readAsString();

    final attachment = IoSentryAttachment.fromPath(file.path);
    configSentryUser();
    // Send with sentry
    Sentry.configureScope((scope) {
      scope.addAttachment(attachment);
    });
    Sentry.captureMessage('User Sent Logs');
    Sentry.configureScope((scope) {
      scope.clear();
    });
    configSentryUser();
    
    // and save to firestore
    var logs = FirebaseFirestore.instance.collection('logs');
    var token = await settings.getToken();
    await logs.doc(token).set({'logs': text});
    FLog.warning(text: 'Logs sent');
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
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      FLog.warning(text: 'Error adding breadcrumb: $e');
    }

    if (stacktrace == null) {
      if (type == LogLevel.ERROR ||
          type == LogLevel.SEVERE ||
          type == LogLevel.FATAL) {
        stacktrace = StackTrace.current;
      }
    }

    //creating log object
    FLog.logThis(
      className: className,
      methodName: methodName,
      text: text,
      type: type,
      exception: exception,
      dataLogType: dataLogType,
      stacktrace: stacktrace,
    );
  }
}
