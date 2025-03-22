import 'dart:convert';
import 'dart:io';

import 'package:blue_notify/logs.dart';
import 'package:blue_notify/settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:url_launcher/url_launcher.dart';

const serverUrl = 'http://192.168.1.29:8004';

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

  final token = await settings.retrieveToken();

  Logs.info(text: 'Token: $token');
  Logs.info(text: 'Notifications authorized.');
  return true;
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

String? urlFromPushNotification(RemoteMessage message) {
  Logs.info(
      text:
          'Done waiting for notification.. Result: ${message.notification?.toMap()}');
  final rawNotification = message.notification;
  if (rawNotification == null) {
    Logs.info(text: 'No notification in message, returning.');
    return null;
  }
  final data = message.data;
  Logs.info(text: 'Data in message: $data');
  if (data.isEmpty) {
    Logs.info(text: 'No data in message, returning.');
    return null;
  }
  return data['url'];
}

class ServerNotification {
  final int id;
  final String createdAt;
  final String title;
  final String body;
  final String? url;
  final String? image;

  ServerNotification(
    this.id,
    this.createdAt,
    this.title,
    this.body,
    this.url,
    this.image,
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
      'body': body,
      'url': url,
      'timestamp': createdAt,
    };
  }

  static ServerNotification fromJson(Map<String, dynamic> json) {
    return ServerNotification(
      json['id'] ?? 0,
      json['created_at'] ?? '',
      json['title'] ?? '',
      json['body'] ?? '',
      json['url'],
      json['image'],
    );
  }

  String get friendlyTimestamp {
    final parsed = DateTime.parse(createdAt);
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
    return 'Notification{timestamp: $createdAt, title: $title, body: $body, url: $url}';
  }

  Future<void> markAsRead() async {
    // Simulate marking the notification as read on a server
    var fcmId = await settings.fcmToken();
    var url = '$serverUrl/notifications/$fcmId/$id/read';
    await HttpClient()
        .postUrl(Uri.parse(url))
        .then((request) => request.close());
  }

  Future<void> delete() async {
    // Simulate deleting the notification on a server
    var fcmId = await settings.fcmToken();
    var url = '$serverUrl/notifications/$fcmId/$id';
    var result = await HttpClient()
        .deleteUrl(Uri.parse(url))
        .then((request) => request.close());
    if (result.statusCode != 200) {
      Logs.error(text: 'network error ${result.statusCode}');
      throw Exception('network error ${result.statusCode}');
    }
  }

  static Future<List<ServerNotification>> getAllNotifications() async {
    // Simulate fetching notifications from a server
    var fcmId = await settings.fcmToken();
    var url = '$serverUrl/notifications/$fcmId';
    final response = await HttpClient()
        .getUrl(Uri.parse(url))
        .then((request) => request.close());
    if (response.statusCode != 200) {
      Logs.error(text: 'network error ${response.statusCode}');
      throw Exception('network error ${response.statusCode}');
    }
    final responseBody = await response.transform(const Utf8Decoder()).join();
    final List<dynamic> jsonResponse = jsonDecode(responseBody);
    return jsonResponse
        .map((json) => ServerNotification.fromJson(json))
        .toList();
  }

  static Future<void> clearNotifications() async {
    // Simulate clearing notifications on a server
    var fcmId = await settings.fcmToken();
    var url = '$serverUrl/notifications/$fcmId/clear';
    final response = await HttpClient()
        .deleteUrl(Uri.parse(url))
        .then((request) => request.close());
    if (response.statusCode != 200) {
      Logs.error(text: 'network error ${response.statusCode}');
      throw Exception('network error ${response.statusCode}');
    }
    Logs.info(text: 'Notifications cleared');
    return;
  }
}
