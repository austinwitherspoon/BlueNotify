import 'dart:io';

import 'package:blue_notify/settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
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
    developer.log('Notifications not authorized.');
    return false;
  }
  
  final token = await settings.getToken();

  developer.log('Token: $token');
  developer.log('Notifications authorized.');
  return true;
}

Future<void> catalogNotification(RemoteMessage message) async {
  await settings.reload();
  developer.log('Saving notification..');
  final notification = messageToNotification(message);
  if (notification == null) {
    developer.log('No notification to save, returning.');
    return;
  }
  developer.log('Saved notification: $notification');
  await settings.addNotification(notification);
}

Notification? messageToNotification(RemoteMessage message) {
  final rawNotification = message.notification;
  if (rawNotification == null) {
    developer.log('No notification in message, returning.');
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
    developer.log('Tapped notification: $this');
    if (url != null) {
      developer.log('Opening URL: $url');
      final Uri uri = Uri.parse(url!);
      if (Platform.isIOS) {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          developer.log('Could not launch $uri');
          return;
        }
      } else {
        if (!await launchUrl(uri)) {
          developer.log('Could not launch $uri');
          return;
        }
      }
    } else {
      Sentry.captureMessage('No URL to open! Notification: $this',
          level: SentryLevel.error);
      developer.log('No URL to open.');
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
