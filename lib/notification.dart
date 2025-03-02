import 'dart:io';

import 'package:blue_notify/logs.dart';
import 'package:blue_notify/settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:url_launcher/url_launcher.dart';

const maxNotificationsToKeep = 100;

Future<bool> checkNotificationPermission() async {
  var permissions = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  if (permissions.authorizationStatus != AuthorizationStatus.authorized) {
    Logs.error(text: 'Notifications not authorized.');
    return false;
  }
  
  final token = await settings.getToken();

  Logs.info(text: 'Token: $token');
  Logs.info(text: 'Notifications authorized.');
  return true;
}

Future<void> catalogNotification(RemoteMessage message) async {
  await settings.reload();
  Logs.info(text: 'Saving notification..');
  final notification = await messageToNotification(message);
  if (notification == null) {
    Logs.info(text: 'No notification to save, returning.');
    return;
  }
  Logs.info(text: 'Saved notification: $notification');
  await settings.addNotification(notification);
}

Future<Notification?> messageToNotification(RemoteMessage message) async {
  // try for up to 3 seconds to read the message if null
  // workaround for stupid bug in firebase_messaging
  // https://github.com/firebase/flutterfire/issues/17107
  var seconds = 3.0;
  while (message.notification?.title == null && seconds > 0) {
    Logs.info(text: 'Waiting for notification..');
    await Future.delayed(const Duration(milliseconds: 500));
    seconds -= .5;
  }
  Logs.info(
      text:
          'Done waiting for notification.. Result: ${message.notification?.toMap()}');
  final rawNotification = message.notification;
  if (rawNotification == null) {
    Logs.info(text: 'No notification in message, returning.');
    return null;
  }
  final data = message.data;

  final title = rawNotification.title ?? '[No notification title!]';
  final subtitle =
      rawNotification.body ?? data["text"] ?? '[No notification body!]';
  final url = data['url'];
  final timestamp = DateTime.now().toIso8601String();
  final notification = Notification(timestamp, title, subtitle, url);
  return notification;
}

Future<void> openUrl(String url) async {
  Logs.info(text: 'Opening URL: $url');
  final Uri uri = Uri.parse(url);
  if (Platform.isIOS) {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Logs.error(text: 'Could not launch $uri');
      return;
    }
  } else {
    if (!await launchUrl(uri)) {
      Logs.info(text: 'Could not launch $uri');
      return;
    }
  }
}

class Notification {
  final String timestamp;
  final String title;
  final String subtitle;
  final String? url;

  Notification(
    this.timestamp,
    this.title,
    this.subtitle,
    this.url,
  );

  Future<void> tap() async {
    Logs.info(text: 'Tapped notification: $this');
    if (url != null) {
      await openUrl(url!);
    } else {
      Sentry.captureMessage('No URL to open! Notification: $this',
          level: SentryLevel.error);
      Logs.error(text: 'No URL to open! Notification: $this');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'url': url,
      'timestamp': timestamp,
    };
  }

  static Notification fromJson(Map<String, dynamic> json) {
    return Notification(
      json['timestamp'],
      json['title'],
      json['subtitle'],
      json['url'],
    );
  }

  String get friendlyTimestamp {
    final parsed = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(parsed);
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    }
    return 'Just now';
  }

  @override
  String toString() {
    return 'Notification{timestamp: $timestamp, title: $title, subtitle: $subtitle, url: $url}';
  }
}
