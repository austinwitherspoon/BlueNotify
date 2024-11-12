import 'dart:convert';
import 'package:blue_notify/bluesky.dart';
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
  String cachedName = '';
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
      json['cachedName'] ?? '',
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
  List<Account>? _accounts = null;
  List<NotificationSetting>? _notificationSettings = null;

  init() async {
    _sharedPrefs ??= await SharedPreferences.getInstance();
  }

  bool get enabled => _sharedPrefs!.getBool('enabled') ?? true;
  set enabled(bool value) {
    _sharedPrefs!.setBool('enabled', value);
    notifyListeners();
  }

  int get syncFrequency => _sharedPrefs!.getInt('syncFrequency') ?? 1;
  set syncFrequency(int value) {
    _sharedPrefs!.setInt('syncFrequency', value);
    notifyListeners();
  }

  void loadAccounts() {
    _accounts = _sharedPrefs!.getStringList('accounts')?.map((e) {
      return Account.fromJson(jsonDecode(e));
    }).toList();
  }

  void saveAccounts() {
    _sharedPrefs!.setStringList(
        'accounts', accounts.map((e) => jsonEncode(e)).toList());
    notifyListeners();
  }

  List<Account> get accounts {
    if (_accounts == null) {
      loadAccounts();
    }
    _accounts = _accounts ?? [];
    return _accounts!;
  }

  void addAccount(Account account) {
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
    _notificationSettings!.sort((a, b) => a.cachedName.compareTo(b.cachedName));
  }

  Future<void> saveNotificationSettings() async {
    _sharedPrefs!.setStringList('notificationSettings',
        notificationSettings.map((e) => jsonEncode(e)).toList());
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

    notifyListeners();
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
}
