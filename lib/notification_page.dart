import 'package:blue_notify/bluesky.dart';
import 'package:blue_notify/notification.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings.dart';


class UsernameDisplay extends StatelessWidget {
  final String username;
  final String? displayName;

  const UsernameDisplay(this.username, this.displayName);

  static fromProfile(Profile profile) {
    var displayName = profile.displayName;
    if (displayName == null || displayName.isEmpty) {
      displayName = profile.handle;
    }
    return UsernameDisplay(profile.handle, displayName);
  }

  static fromNotificationSetting(NotificationSetting setting) {
    var displayName = setting.cachedName;
    if (displayName == null || displayName.isEmpty) {
      displayName = setting.cachedHandle;
    }
    return UsernameDisplay(setting.cachedHandle, displayName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(displayName ?? username),
        Text(username, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Notification Settings"),
      ),
      body: Consumer<Settings>(builder: (context, settings, child) {
        final notificationSettings = settings.notificationSettings;
        return ListView.builder(
          itemCount: notificationSettings.length,
          itemBuilder: (context, index) {
            final setting = notificationSettings[index];
            return ExpansionTile(
              title: UsernameDisplay.fromNotificationSetting(setting),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.expand_more),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text("Confirm Deletion"),
                            content: const Text(
                                "Are you sure you want to delete this notification setting?"),
                            actions: <Widget>[
                              TextButton(
                                child: const Text("Cancel"),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              TextButton(
                                child: const Text("Delete"),
                                onPressed: () {
                                  settings.removeNotificationSetting(
                                      setting.followDid);
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              children: PostType.values.map((postType) {
                return SwitchListTile(
                  title: Text(postTypeNames[postType] ?? "Unknown"),
                  value: setting.postTypes.contains(postType),
                  onChanged: (value) {
                    setState(() {
                      if (value) {
                        setting.addPostType(postType);
                      } else {
                        setting.removePostType(postType);
                      }
                    });
                  },
                );
              }).toList(),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: addNotification,
        tooltip: 'Add Notification',
        child: const Icon(Icons.add),
      ),
    );
  }

  void addNotification() async {
    final settings = Provider.of<Settings>(context, listen: false);
    final accounts = settings.accounts;
    searchQuery = '';

    await checkNotificationPermission();

    if (accounts.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("No Accounts"),
            content: const Text("Please login to your account first."),
            actions: <Widget>[
              TextButton(
                child: const Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    AccountReference account;
    if (accounts.length == 1) {
      account = accounts.first;
    } else {
      var ask_for_account = await showDialog<AccountReference>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
            title: const Text("Choose one of your accounts to use:"),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: accounts.map((account) {
                      return ListTile(
                        title: Text(account.login),
                        onTap: () {
                          Navigator.of(context).pop(account);
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            },
      );
      if (ask_for_account == null) {
        return;
      }
      account = ask_for_account;
    }

    showLoadingDialog(context);
    final service = await BlueskyService.getPublicConnection();
    final following = await service.getFollowingForUser(account.did);
    following.sort((a, b) =>
        (a.sortName()).compareTo(b.sortName()));

    print(following);
    // while we have the data, update handles and display names for existing profiles
    for (var profile in following) {
      final existingSetting =
          settings.getNotificationSetting(profile.did, account.did);
      if (existingSetting != null) {
        existingSetting.cachedHandle = profile.handle;
        existingSetting.cachedName = profile.displayName ?? profile.handle;
      }
    }

    // remove any following that we already have a notification setting for
    following.removeWhere((profile) =>
        settings.getNotificationSetting(profile.did, account.did) != null);
    Navigator.pop(context);

    if (following.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("No users to follow"),
            content: const Text(
                "You are already following all users that you can receive notifications for."),
            actions: <Widget>[
              TextButton(
                child: const Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Choose a user to receive notifications for:"),
              content: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      hintText: 'Search for a user',
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ListBody(
                        children: following
                            .where((profile) =>
                                profile.handle
                                    .toLowerCase()
                                    .contains(searchQuery) ||
                                (profile.displayName
                                        ?.toLowerCase()
                                        .contains(searchQuery) ??
                                    false))
                            .map((profile) {
                          return ListTile(
                            title: UsernameDisplay.fromProfile(profile),
                            onTap: () async {
                              final newSetting = NotificationSetting(
                                  profile.did,
                                  account.did,
                                  profile.handle,
                                  profile.displayName ?? profile.handle,
                                  {}..addAll(defaultNotificationSettings));
                              Navigator.of(context).pop();
                              await settings.addNotificationSetting(newSetting);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

showLoadingDialog(BuildContext context) {
  AlertDialog alert = AlertDialog(
    content: new Row(
      children: [
        CircularProgressIndicator(),
        Container(margin: EdgeInsets.only(left: 5), child: Text("Loading")),
      ],
    ),
  );
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}
