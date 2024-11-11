import 'dart:convert';
import 'package:blue_notify/bluesky.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settings = Settings();

const defaultNotificationSettings = {
  PostType.post,
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

  void addPostType(PostType value) {
    _postTypes.add(value);
    settings.saveNotificationSettings();
  }

  void removePostType(PostType value) {
    _postTypes.remove(value);
    settings.saveNotificationSettings();
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
        'accounts', _accounts!.map((e) => jsonEncode(e)).toList());
    notifyListeners();
  }

  List<Account> get accounts {
    if (_accounts == null) {
      loadAccounts();
    }
    return _accounts ?? [];
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
    }).toList();
    _notificationSettings!.sort((a, b) => a.cachedName.compareTo(b.cachedName));
  }

  void saveNotificationSettings() {
    _sharedPrefs!.setStringList('notificationSettings',
        _notificationSettings!.map((e) => jsonEncode(e)).toList());
    notifyListeners();
  }

  List<NotificationSetting> get notificationSettings {
    if (_notificationSettings == null) {
      loadNotificationSettings();
    }
    return _notificationSettings ?? [];
  }

  void addNotificationSetting(NotificationSetting setting) {
    notificationSettings.add(setting);
    saveNotificationSettings();
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

  void removeNotificationSetting(String did) {
    notificationSettings.removeWhere((element) => element.followDid == did);
    saveNotificationSettings();
  }
}
