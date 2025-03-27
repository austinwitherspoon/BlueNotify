import 'dart:collection';

import 'package:blue_notify/bluesky.dart';
import 'package:blue_notify/notification.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'account_page.dart';
import 'settings.dart';

late BlueskyService service;

const followCountLimit = 10000;

class UsernameDisplay extends StatelessWidget {
  final String username;
  final String? displayName;

  const UsernameDisplay(this.username, this.displayName, {super.key});

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
        Text(
          displayName ?? username,
          softWrap: true,
          textAlign: TextAlign.center,
        ),
        Text(username,
            style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
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
  List<Profile> autoCompleteResults = [];
  HashSet<String> expandedDids = HashSet();

  @override
  void initState() {
    super.initState();
    BlueskyService.getPublicConnection().then((value) {
      service = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Notification Settings"),
      ),
      body: Consumer<Settings>(builder: (context, settings, child) {
        final notificationSettings = settings.notificationSettings;
        notificationSettings.sort((a, b) => (a.cachedName ?? a.cachedHandle)
            .toLowerCase()
            .compareTo((b.cachedName ?? b.cachedHandle).toLowerCase()));
        return ListView.builder(
          itemCount:
              notificationSettings.length + 1, // Add one for the blank space
          itemBuilder: (context, index) {
            if (index == notificationSettings.length) {
              return const SizedBox(height: 80); // Blank space at the bottom
            }
            final setting = notificationSettings[index];
            var expanded = expandedDids.contains(setting.followDid);
            return ExpansionTile(
              title: UsernameDisplay.fromNotificationSetting(setting),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              key:
                  GlobalKey(), // This is a workaround to fix the issue of ExpansionTile not expanding when the list is updated
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    expandedDids.add(setting.followDid);
                  } else {
                    expandedDids.remove(setting.followDid);
                  }
                });
              },
              maintainState: false,
              initiallyExpanded: expanded,
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
            content: const Text(
                "You aren't connected to a bluesky account yet, would you like to do that now?"),
            actions: <Widget>[
              TextButton(
                child: const Text("Add Account"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AccountPage()),
                  );
                },
              ),
              TextButton(
                child: const Text("Cancel"),
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
      var askForAccount = await showDialog<AccountReference>(
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
      if (askForAccount == null) {
        return;
      }
      account = askForAccount;
    }

    var newExpandedDids = HashSet<String>();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddNotificationWidget(
            user: Profile(account.did, account.login, null, null),
            onConfirm: (selectedProfiles) {
              for (var profile in selectedProfiles) {
                final newSetting = NotificationSetting(
                    profile.did,
                    account.did,
                    profile.handle,
                    profile.displayName,
                    {}..addAll(defaultNotificationSettings));
                settings.addNotificationSetting(newSetting, save: false);
                newExpandedDids.add(profile.did);
              }
              settings.saveNotificationSettings();
            });
      },
    );
    print("expanded" + newExpandedDids.toString());
    setState(() {
      expandedDids.addAll(newExpandedDids);
    });
  }
}

class AddNotificationWidget extends StatefulWidget {
  final Profile user;
  final Function(List<Profile>) onConfirm;
  const AddNotificationWidget(
      {super.key, required this.user, required this.onConfirm});

  @override
  State<AddNotificationWidget> createState() =>
      // ignore: no_logic_in_create_state
      _AddNotificationWidgetState(user);
}

class _AddNotificationWidgetState extends State<AddNotificationWidget> {
  String searchQuery = '';
  List<Profile> autoCompleteResults = [];
  List<Profile> selectedProfiles = [];
  List<Profile> following = [];
  bool isLoading = false;
  final Profile account;
  bool tooManyFollowing = false;

  _AddNotificationWidgetState(this.account);

  @override
  void initState() {
    super.initState();
    loadFollowing();
  }

  Future<void> loadFollowing() async {
    setState(() {
      isLoading = true;
    });
    var followingCount = await service.getFollowingCountForUser(account.did);
    if (followingCount > followCountLimit) {
      tooManyFollowing = true;
      setState(() {
        isLoading = false;
      });
      return;
    }
    var results = await service.getFollowingForUser(account.did);
    results.sort((a, b) => (a.sortName()).compareTo(b.sortName()));

    if (!mounted) {
      return;
    }
    final settings = Provider.of<Settings>(context, listen: false);
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
    results.removeWhere((profile) =>
        settings.getNotificationSetting(profile.did, account.did) != null);

    setState(() {
      following = results;
      isLoading = false;
    });
  }

  Future<void> loadAutoCompleteResults() async {
    var results = await service.searchUsers(searchQuery);
    setState(() {
      autoCompleteResults = results;
    });
  }

  List<Profile> get searchResults {
    return following
        .where((profile) =>
            profile.handle.toLowerCase().contains(searchQuery) ||
            (profile.displayName?.toLowerCase().contains(searchQuery) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    String? error;
    MaterialColor? errorColor;
    if (tooManyFollowing) {
      error =
          "You are following too many people to display them all. Searching all of bluesky..";
      errorColor = Colors.red;
    } else if (searchResults.isEmpty &&
        autoCompleteResults.isEmpty &&
        searchQuery.isNotEmpty) {
      error = "No users found.";
    } else if (searchResults.isEmpty && searchQuery.isNotEmpty) {
      error = "No users found, searching all of bluesky.";
    }

    return AlertDialog(
      title: const Text("Choose users to receive notifications for:"),
      content: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search',
              hintText: 'Search for users',
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value.toLowerCase();
              });
              loadAutoCompleteResults();
            },
          ),
          Expanded(
              child: isLoading
                  ? Container(
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.all(16.0),
                      child: const CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(children: [
                        if (error != null)
                          Text(error, style: TextStyle(color: errorColor)),
                        ListBody(
                          children: (searchResults.isEmpty
                                  ? autoCompleteResults
                                  : searchResults)
                              .map((profile) {
                            return CheckboxListTile(
                              title: UsernameDisplay.fromProfile(profile),
                              value: selectedProfiles.contains(profile),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    selectedProfiles.add(profile);
                                  } else {
                                    selectedProfiles.remove(profile);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ]),
                    )),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: const Text("Cancel"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text("Add"),
          onPressed: () async {
            widget.onConfirm(selectedProfiles);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

showLoadingDialog(BuildContext context) {
  AlertDialog alert = AlertDialog(
    content: Row(
      children: [
        const CircularProgressIndicator(),
        Container(
            margin: const EdgeInsets.only(left: 5),
            child: const Text("Loading")),
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
