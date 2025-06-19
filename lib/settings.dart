import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:blue_notify/bluesky.dart';
import 'package:blue_notify/notification.dart';
import 'package:blue_notify/logs.dart';
import 'package:blue_notify/main.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

final settings = Settings();

const defaultNotificationSettings = {
  PostType.post,
};

const postTypeToApiNames = {
  PostType.post: 'Post',
  PostType.repost: 'Repost',
  PostType.reply: 'Reply',
  PostType.replyToFriend: 'ReplyToFriend',
};

class NotificationSetting {
  final String followDid;
  final String accountDid;
  String cachedHandle = '';
  String? cachedName;
  final Set<PostType> _postTypes;
  List<String>? wordBlockList;
  List<String>? wordAllowList;

  NotificationSetting(this.followDid, this.accountDid, this.cachedHandle,
      this.cachedName, this._postTypes,
      {this.wordBlockList, this.wordAllowList});

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
      wordBlockList: (json['wordBlockList'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      wordAllowList: (json['wordAllowList'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'followDid': followDid,
        'accountDid': accountDid,
        'cachedHandle': cachedHandle,
        'cachedName': cachedName,
        'postTypes': _postTypes.map((e) => e.name).toList(),
        'wordBlockList': wordBlockList,
        'wordAllowList': wordAllowList,
      };

  Set<PostType> get postTypes => _postTypes;

  Map<String, dynamic> toApiJson() {
    var postTypes = _postTypes.map((e) => postTypeToApiNames[e]).toList();
    return {
      'user_account_did': accountDid,
      'following_did': followDid,
      'post_type': postTypes,
      'word_block_list': wordBlockList,
      'word_allow_list': wordAllowList,
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
  List<AccountReference>? _accounts;
  List<NotificationSetting>? _notificationSettings;
  HashMap<(String, String), NotificationSetting>? _notificationSettingsMap;

  init() async {
    _sharedPrefs ??= await SharedPreferences.getInstance();
  }

  // Clear the history the first time we run each day
  void checkClearLogHistory() {
    final lastClear = _sharedPrefs!.getInt('lastClearLogHistory') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastClearDate = DateTime.fromMillisecondsSinceEpoch(lastClear);
    final nowDate = DateTime.fromMillisecondsSinceEpoch(now);
    if (lastClearDate.year != nowDate.year ||
        lastClearDate.month != nowDate.month ||
        lastClearDate.day != nowDate.day) {
      Logs.info(text: 'Clearing log history');
      _sharedPrefs!.setInt('lastClearLogHistory', now);
      Logs.clearLogs();
      Logs.info(text: 'Log history cleared');
    }
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

  set newestFirst(bool value) {
    _sharedPrefs!.setBool('newestFirst', value);
  }

  bool get newestFirst {
    return _sharedPrefs!.getBool('newestFirst') ?? true;
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

  Future<String> retrieveToken() async {
    Logs.info(text: 'Getting FCM token');

    // On IOS, always load APNS first!
    bool isIOS = false;
    try {
      if (Platform.isIOS) {
        isIOS = true;
      }
    } catch (e) {
      // ignore the error if we're not running on iOS
    }
    if (isIOS) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken == null) {
        Logs.error(text: 'No APNS token found');
        throw Exception('No APNS token found');
      }
    }
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

  Future<String> fcmToken() async {
    if (lastToken != null) {
      return lastToken!;
    }
    return await retrieveToken();
  }

  void addAccount(AccountReference account) {
    Logs.info(text: 'Adding account with DID: ${account.did}');
    if (accounts.any((element) => element.did == account.did)) {
      Logs.info(text: 'Account already exists, not adding');
      return;
    }
    accounts.add(account);
    saveAccounts();
  }

  void removeAccount(String did) {
    Logs.info(text: 'Removing account with DID: $did');
    accounts.removeWhere((element) => element.did == did);
    saveAccounts();
  }

  void _buildNotificationSettingsMap() {
    _notificationSettingsMap = HashMap();
    for (final setting in notificationSettings) {
      _notificationSettingsMap![(setting.followDid, setting.accountDid)] =
          setting;
    }
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
    _buildNotificationSettingsMap();
  }

  Future<void> saveNotificationSettings() async {
    Logs.info(text: 'Saving notification settings');
    _sharedPrefs!.setStringList('notificationSettings',
        notificationSettings.map((e) => jsonEncode(e)).toList());
    notifyListeners();

    final fcmToken = await retrieveToken();
    configSentryUser();

    var settings = [];
    for (final setting in notificationSettings) {
      settings.add(setting.toApiJson());
    }
    var accountJson = accounts
        .map((e) => {
              'account_did': e.did,
            })
        .toList();

    var settingsData = {
      'notification_settings': settings,
      "accounts": accountJson,
      "fcm_token": fcmToken
    };

    if (!kIsWeb) {
      settingsData['device_uuid'] = await FlutterUdid.udid;
    }

    Logs.info(text: 'Uploading settings to api: $settingsData');
    var url = '$apiServer/settings/$fcmToken';
    var rawJson = jsonEncode(settingsData);
    Logs.info(text: 'Uploading settings to api: $rawJson');
    final response = await http.post(Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: rawJson);
    if (response.statusCode != 200) {
      Logs.error(text: 'network error $response');
      throw Exception('network error ${response.statusCode}');
    }

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
    _buildNotificationSettingsMap();
    if (save) {
      await saveNotificationSettings();
    }
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

  Future<void> removeNotificationSetting(String account, String did) async {
    Logs.info(
        text: 'Removing notification setting for $did (account $account)');
    notificationSettings.removeWhere(
        (element) => element.followDid == did && element.accountDid == account);
    _buildNotificationSettingsMap();
    await saveNotificationSettings();
  }

  Future<void> removeAllNotificationSettings() async {
    Logs.info(text: 'Removing all notification settings');
    _notificationSettings?.clear();
    _notificationSettingsMap?.clear();
    await _sharedPrefs!.remove('notificationSettings');
    notifyListeners();
    final fcmToken = await retrieveToken();

    var url = '$apiServer/settings/$fcmToken';
    final response = await http.delete(Uri.parse(url));
    if (response.statusCode != 200) {
      Logs.error(text: 'network error ${response.statusCode}');
      throw Exception('network error ${response.statusCode}');
    }
    Logs.info(text: 'Notification settings removed');
  }

  Future<void> reload() async {
    await _sharedPrefs!.reload();
    notifyListeners();
  }

  Future<void> resetToken() async {
    Logs.info(text: 'Resetting FCM token');
    lastToken = null;
    await FirebaseMessaging.instance.deleteToken();
    await checkNotificationPermission();
  }

  Future<void> forceResync() async {
    Logs.info(text: 'Forcing resync');
    if (!kIsWeb) {
      Logs.info(text: 'Deleting FCM token');
      await resetToken();
    }
    await saveNotificationSettings();
  }

  /// Backup all settings to JSON
  String backupSettingsToJson() {
    final backupData = {
      'accounts': accounts.map((e) => e.toJson()).toList(),
      'notificationSettings':
          notificationSettings.map((e) => e.toJson()).toList(),
    };
    return jsonEncode(backupData);
  }

  /// Restore all settings from JSON data
  Future<void> restoreSettingsFromJson(String json) async {
    final data = jsonDecode(json);

    // Restore accounts
    final restoredAccounts = (data['accounts'] as List<dynamic>)
        .map((e) => AccountReference.fromJson(e))
        .toList();
    _accounts = restoredAccounts;
    _sharedPrefs!.setStringList(
        'accounts', restoredAccounts.map((e) => jsonEncode(e)).toList());

    // Restore notification settings
    final restoredSettings = (data['notificationSettings'] as List<dynamic>)
        .map((e) => NotificationSetting.fromJson(e))
        .toList();
    _notificationSettings = restoredSettings;
    _sharedPrefs!.setStringList('notificationSettings',
        restoredSettings.map((e) => jsonEncode(e)).toList());
    _buildNotificationSettingsMap();

    await saveNotificationSettings();

    notifyListeners();
  }

  /// Delete all account data
  Future<void> deleteAccountData() async {
    Logs.info(text: 'Deleting all account data');
    final uuid = await FlutterUdid.udid;
    var fcmId = await settings.fcmToken();
    var url = '$apiServer/account';
    var body = {
      'fcm_token': fcmId,
      'device_uuid': uuid,
    };
    var response = await http.delete(Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body));

    if (response.statusCode != 200) {
      Logs.error(text: 'network error ${response.statusCode}');
      throw Exception('network error ${response.statusCode}');
    }
    await removeAllNotificationSettings();
    accounts.clear();
    _sharedPrefs!.remove('accounts');
    _sharedPrefs!.remove('notificationSettings');
    _sharedPrefs!.remove('lastToken');
    _sharedPrefs!.remove('newestFirst');
    _sharedPrefs!.remove('lastClearLogHistory');
    notifyListeners();
  }
}
