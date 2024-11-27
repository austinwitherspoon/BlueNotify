import 'dart:convert';
import 'package:blue_notify/bluesky.dart';
import 'package:blue_notify/notification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

final settings = Settings();

const defaultNotificationSettings = {
  PostType.post,
};

const postTypeToFirebaseNames = {
  PostType.post: 'post',
  PostType.repost: 'repost',
  PostType.reply: 'reply',
  PostType.replyToFriend: 'replyToFriend',
};

class NotificationSetting {
  final String followDid;
  final String accountDid;
  String cachedHandle = '';
  String? cachedName = null;
  final Set<PostType> _postTypes;

  NotificationSetting(this.followDid, this.accountDid, this.cachedHandle,
      this.cachedName, this._postTypes);

  static NotificationSetting fromJson(Map<String, dynamic> json) {
    final postTypes = json['postTypes'];
    Set<PostType> postTypeSet = {};
    try {
      for (final postType in postTypes) {
        for (final type in PostType.values) {
          if (postType == type.name) {
            postTypeSet.add(type);
            break;
          }
        }
      }
    } catch (e) {
      postTypeSet.addAll(defaultNotificationSettings);
    }
    return NotificationSetting(
      json['followDid'],
      json['accountDid'],
      json['cachedHandle'] ?? '',
      json['cachedName'],
      postTypeSet,
    );
  }

  Map<String, dynamic> toJson() => {
        'followDid': followDid,
        'accountDid': accountDid,
        'cachedHandle': cachedHandle,
        'cachedName': cachedName,
        'postTypes': _postTypes.map((e) => e.name).toList(),
      };

  Set<PostType> get postTypes => _postTypes;

  Map<String, dynamic> toFirestore() {
    var postTypes = _postTypes.map((e) => postTypeToFirebaseNames[e]).toList();
    return {
      'did': followDid,
      'postTypes': postTypes,
    };
  }

  Future<void> addPostType(PostType value) async {
    _postTypes.add(value);
    await settings.saveNotificationSettings();
  }

  Future<void> removePostType(PostType value) async {
    _postTypes.remove(value);
    await settings.saveNotificationSettings();
  }
}

class Settings with ChangeNotifier {
  static SharedPreferences? _sharedPrefs;
  List<AccountReference>? _accounts = null;
  List<NotificationSetting>? _notificationSettings = null;

  init() async {
    _sharedPrefs ??= await SharedPreferences.getInstance();
  }

  void loadAccounts() {
    _accounts = _sharedPrefs!.getStringList('accounts')?.map((e) {
      return AccountReference.fromJson(jsonDecode(e));
    }).toList();
  }

  void saveAccounts() {
    _sharedPrefs!.setStringList(
        'accounts', accounts.map((e) => jsonEncode(e)).toList());
    notifyListeners();
  }

  List<AccountReference> get accounts {
    if (_accounts == null) {
      loadAccounts();
    }
    _accounts = _accounts ?? [];
    return _accounts!;
  }

  void addAccount(AccountReference account) {
    accounts.add(account);
    saveAccounts();
  }

  void removeAccount(String did) {
    accounts.removeWhere((element) => element.did == did);
    saveAccounts();
  }

  void loadNotificationSettings() {
    _notificationSettings =
        _sharedPrefs!.getStringList('notificationSettings')?.map((e) {
      return NotificationSetting.fromJson(jsonDecode(e));
            }).toList() ??
            [];
    _notificationSettings!.sort((a, b) => (a.cachedName ?? a.cachedHandle)
        .compareTo(b.cachedName ?? b.cachedHandle));
  }

  Future<void> saveNotificationSettings() async {
    _sharedPrefs!.setStringList('notificationSettings',
        notificationSettings.map((e) => jsonEncode(e)).toList());
    notifyListeners();
    final fcmToken = (await FirebaseMessaging.instance.getToken())!;
    CollectionReference subscriptions =
        FirebaseFirestore.instance.collection('subscriptions');
    var settings = {};
    for (final setting in notificationSettings) {
      settings[setting.followDid] = setting.toFirestore();
    }
    var account_dids = accounts.map((e) => e.did).toList();
    await subscriptions.doc(fcmToken).set(
        {'settings': settings, "accounts": account_dids, "fcmToken": fcmToken});
  }

  List<NotificationSetting> get notificationSettings {
    if (_notificationSettings == null) {
      loadNotificationSettings();
    }
    _notificationSettings = _notificationSettings ?? [];
    return _notificationSettings!;
  }

  Future<void> addNotificationSetting(NotificationSetting setting) async {
    notificationSettings.add(setting);
    await saveNotificationSettings();
  }

  NotificationSetting? getNotificationSetting(
      String followDid, String accountDid) {
    for (final setting in notificationSettings) {
      if (setting.followDid == followDid && setting.accountDid == accountDid) {
        return setting;
      }
    }
    return null;
  }

  Future<void> removeNotificationSetting(String did) async {
    notificationSettings.removeWhere((element) => element.followDid == did);
    await saveNotificationSettings();
  }

  Future<void> removeAllNotificationSettings() async {
    _notificationSettings?.clear();
    await _sharedPrefs!.remove('notificationSettings');
    notifyListeners();
    final fcmToken = (await FirebaseMessaging.instance.getToken())!;
    CollectionReference subscriptions =
        FirebaseFirestore.instance.collection('subscriptions');
    await subscriptions.doc(fcmToken).delete();
  }

  List<Notification> get notificationHistory {
    developer.log('Getting notification history');
    return _sharedPrefs!.getStringList('notificationHistory')?.map((e) {
          return Notification.fromJson(jsonDecode(e));
        }).toList() ??
        [];
  }

  Future<void> reload() async {
    await _sharedPrefs!.reload();
    notifyListeners();
  }

  Future<void> addNotification(Notification notification) async {
    final history = notificationHistory;
    history.insert(0, notification);
    if (history.length > maxNotificationsToKeep) {
      history.removeRange(maxNotificationsToKeep, history.length);
    }
    await _sharedPrefs!.setStringList(
        'notificationHistory', history.map((e) => jsonEncode(e)).toList());
    notifyListeners();
  }

  Future<void> removeNotification(Notification notification) async {
    final history = notificationHistory;
    final matching = history.firstWhere(
      (element) =>
          element.timestamp == notification.timestamp &&
          element.title == notification.title &&
          element.subtitle == notification.subtitle,
    );
    history.remove(matching);
    await _sharedPrefs!.setStringList(
        'notificationHistory', history.map((e) => jsonEncode(e)).toList());
    notifyListeners();
  }

  Future<void> clearNotificationHistory() async {
    await _sharedPrefs!.setStringList('notificationHistory', []);
    notifyListeners();
  }

  Future<void> forceResync() async {
    await saveNotificationSettings();
  }
}
