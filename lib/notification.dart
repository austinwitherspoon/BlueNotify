import 'dart:io';

import 'package:blue_notify/settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer' as developer;

import 'package:url_launcher/url_launcher.dart';

const maxNotificationsToKeep = 100;

Future<bool> checkNotificationPermission() async {
  var permissions =
      await FirebaseMessaging.instance.requestPermission(
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

  var token = await FirebaseMessaging.instance.getToken();
  developer.log('Token: $token');
  if (token == null) {
    developer.log('No token, returning.');
    return false;
  }
  developer.log('Notifications authorized.');
  return true;
}

void catalogNotification(RemoteMessage message) {
  developer.log('Saving notification..');
  final notification = messageToNotification(message);
  if (notification == null) {
    developer.log('No notification to save, returning.');
    return;
  }
  developer.log('Saved notification: $notification');
  settings.addNotification(notification);
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
  final postId = data['post_id'];
  final postUserHandle = data['post_user_handle'];
  final postUserDid = data['post_user_did'];
  final userHandle = data['user_handle'];
  final userDid = data['user_did'];
  final text = data['text'];
  final type = data['type'];
  final timestamp = DateTime.now().toIso8601String();
  final notification = Notification(timestamp, title, subtitle, url, postId,
      postUserHandle, postUserDid, userHandle, userDid, text, type);
  return notification;
}

class Notification {
  final String timestamp;
  final String title;
  final String subtitle;
  final String? url;
  final String? postId;
  final String? postUserHandle;
  final String? postUserDid;
  final String? userHandle;
  final String? userDid;
  final String? text;
  final String? type;

  Notification(
      this.timestamp,
      this.title,
      this.subtitle,
      this.url,
      this.postId,
      this.postUserHandle,
      this.postUserDid,
      this.userHandle,
      this.userDid,
      this.text,
      this.type);

  Future<void> tap() async {
    developer.log('Tapped notification: $this');
    if (url != null) {
      print('Opening URL: $url');
      final Uri uri = Uri.parse(url!);
      if (Platform.isIOS) {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          print('Could not launch $uri');
          return;
        }
      } else {
      if (!await launchUrl(uri)) {
        print('Could not launch $uri');
        return;
      }
      }
    } else {
      developer.log('No URL to open.');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'url': url,
      'postId': postId,
      'postUserHandle': postUserHandle,
      'postUserDid': postUserDid,
      'userHandle': userHandle,
      'userDid': userDid,
      'text': text,
      'type': type,
      'timestamp': timestamp,
    };
  }

  static Notification fromJson(Map<String, dynamic> json) {
    return Notification(
      json['timestamp'],
      json['title'],
      json['subtitle'],
      json['url'],
      json['postId'],
      json['postUserHandle'],
      json['postUserDid'],
      json['userHandle'],
      json['userDid'],
      json['text'],
      json['type'],
    );
  }
  

  @override
  String toString() {
    return 'Notification{timestamp: $timestamp, title: $title, subtitle: $subtitle, url: $url, postId: $postId, postUserHandle: $postUserHandle, postUserDid: $postUserDid, userHandle: $userHandle, userDid: $userDid, text: $text, type: $type}';
  }
}
