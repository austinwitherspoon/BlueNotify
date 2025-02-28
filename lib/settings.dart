import 'dart:convert';
import 'package:blue_notify/bluesky.dart';
import 'package:blue_notify/logs.dart';
import 'package:blue_notify/main.dart';
import 'package:blue_notify/notification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    Logs.info(text: 'Adding post type $value for $followDid');
    _postTypes.add(value);
    await settings.saveNotificationSettings();
  }

  Future<void> removePostType(PostType value) async {
    Logs.info(text: 'Removing post type $value for $followDid');
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
    Logs.info(text: 'Loading accounts');
    _accounts = _sharedPrefs!.getStringList('accounts')?.map((e) {
      return AccountReference.fromJson(jsonDecode(e));
    }).toList();
  }

  void saveAccounts() {
    Logs.info(text: 'Saving accounts');
    _sharedPrefs!
        .setStringList('accounts', accounts.map((e) => jsonEncode(e)).toList());
    notifyListeners();
  }

  List<AccountReference> get accounts {
    if (_accounts == null) {
      loadAccounts();
    }
    _accounts = _accounts ?? [];
    return _accounts!;
  }

  String? get lastToken {
    return _sharedPrefs!.getString('lastToken');
  }

  set lastToken(String? token) {
    if (token == null) {
      _sharedPrefs!.remove('lastToken');
      return;
    }
    _sharedPrefs!.setString('lastToken', token);
  }

  Future<String> getToken() async {
    Logs.info(text: 'Getting FCM token');
    String? token;
    if (kIsWeb) {
      token = await FirebaseMessaging.instance.getToken(
          vapidKey:
              "BCZ1teaHiX4IfEBaVnYAzWEbuHvBFryInhf9gf0qVHORHB7j9Mlkr59PAmgvMJD-vMRzaAqYkumtRHNNqo93H2I");
    } else {
      token = await FirebaseMessaging.instance.getToken();
    }
    if (token != null) {
      lastToken = token;
    }
    Logs.info(text: 'FCM token: $token');
    return lastToken!;
  }

  void addAccount(AccountReference account) {
    Logs.info(text: 'Adding account with DID: ${account.did}');
    accounts.add(account);
    saveAccounts();
  }

  void removeAccount(String did) {
    Logs.info(text: 'Removing account with DID: $did');
    accounts.removeWhere((element) => element.did == did);
    saveAccounts();
  }

  void loadNotificationSettings() {
    Logs.info(text: 'Loading notification settings');
    _notificationSettings =
        _sharedPrefs!.getStringList('notificationSettings')?.map((e) {
              return NotificationSetting.fromJson(jsonDecode(e));
            }).toList() ??
            [];
    _notificationSettings!.sort((a, b) => (a.cachedName ?? a.cachedHandle)
        .compareTo(b.cachedName ?? b.cachedHandle));
  }

  Future<void> saveNotificationSettings() async {
    Logs.info(text: 'Saving notification settings');
    _sharedPrefs!.setStringList('notificationSettings',
        notificationSettings.map((e) => jsonEncode(e)).toList());
    notifyListeners();
    final fcmToken = await getToken();
    configSentryUser();
    CollectionReference subscriptions =
        FirebaseFirestore.instance.collection('subscriptions');
    var settings = {};
    for (final setting in notificationSettings) {
      settings[setting.followDid] = setting.toFirestore();
    }
    var account_dids = accounts.map((e) => e.did).toList();

    var settings_data = {
      'settings': settings,
      "accounts": account_dids,
      "fcmToken": fcmToken
    };
    Logs.info(text: 'Saving settings to firestore: $settings_data');
    await subscriptions.doc(fcmToken).set(
        settings_data);

    Logs.info(text: 'Notification settings saved');
  }

  List<NotificationSetting> get notificationSettings {
    if (_notificationSettings == null) {
      loadNotificationSettings();
    }
    _notificationSettings = _notificationSettings ?? [];
    return _notificationSettings!;
  }

  Future<void> addNotificationSetting(NotificationSetting setting,
      {bool save = true}) async {
    Logs.info(text: 'Adding notification setting for ${setting.followDid}');
    notificationSettings.add(setting);
    if (save) {
      await saveNotificationSettings();
    }
  }

  NotificationSetting? getNotificationSetting(
      String followDid, String accountDid) {
    Logs.info(text: 'Getting notification setting for $followDid');
    for (final setting in notificationSettings) {
      if (setting.followDid == followDid && setting.accountDid == accountDid) {
        Logs.info(text: 'Found notification setting for $followDid');
        return setting;
      }
    }
    Logs.info(text: 'No notification setting found for $followDid');
    return null;
  }

  Future<void> removeNotificationSetting(String did) async {
    Logs.info(text: 'Removing notification setting for $did');
    notificationSettings.removeWhere((element) => element.followDid == did);
    await saveNotificationSettings();
  }

  Future<void> removeAllNotificationSettings() async {
    Logs.info(text: 'Removing all notification settings');
    _notificationSettings?.clear();
    await _sharedPrefs!.remove('notificationSettings');
    notifyListeners();
    final fcmToken = await getToken();
    CollectionReference subscriptions =
        FirebaseFirestore.instance.collection('subscriptions');
    await subscriptions.doc(fcmToken).delete();
  }

  List<Notification> get notificationHistory {
    Logs.info(text: 'Getting notification history');
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
    Logs.info(text: 'Adding notification to history: $notification');
    final history = notificationHistory;
    history.insert(0, notification);
    if (history.length > maxNotificationsToKeep) {
      history.removeRange(maxNotificationsToKeep, history.length);
    }
    await _sharedPrefs!.setStringList(
        'notificationHistory', history.map((e) => jsonEncode(e)).toList());
    notifyListeners();
    Logs.info(text: 'Notification added to history: $notification');
  }

  Future<void> removeNotification(Notification notification) async {
    Logs.info(text: 'Removing notification from history: $notification');
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
    Logs.info(text: 'Clearing notification history');
    await _sharedPrefs!.setStringList('notificationHistory', []);
    notifyListeners();
  }

  Future<void> forceResync() async {
    Logs.info(text: 'Forcing resync');
    await saveNotificationSettings();
  }
}
