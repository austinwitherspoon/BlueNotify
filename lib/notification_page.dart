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
  final String? owner;

  const UsernameDisplay(this.username, this.displayName, this.owner,
      {super.key});

  static fromProfile(Profile profile) {
    var displayName = profile.displayName;
    if (displayName == null || displayName.isEmpty) {
      displayName = profile.handle;
    }
    return UsernameDisplay(profile.handle, displayName, null);
  }

  static fromNotificationSetting(NotificationSetting setting) {
    var displayName = setting.cachedName;
    if (displayName == null || displayName.isEmpty) {
      displayName = setting.cachedHandle;
    }
    AccountReference? ownerAccount;
    String? ownerDisplay;

    if (settings.accounts.length > 1) {
      try {
        ownerAccount = settings.accounts
            .firstWhere((account) => account.did == setting.accountDid);
      } catch (e) {
        ownerAccount = null;
      }
      ownerDisplay = ownerAccount?.login ?? setting.accountDid;
    }

    return UsernameDisplay(setting.cachedHandle, displayName, ownerDisplay);
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
        if (owner != null)
          Text(
            "Account: $owner",
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primaryContainer),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class SingleNotificationSettings extends StatelessWidget {
  final NotificationSetting setting;

  const SingleNotificationSettings({
    super.key,
    required this.setting,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Column(
          children: (PostType.values
                  .map((postType) {
                    return SwitchListTile(
                      title: Text(postTypeNames[postType] ?? "Unknown"),
                      value: setting.postTypes.contains(postType),
                      onChanged: (value) {
                        if (value) {
                          setting.addPostType(postType);
                        } else {
                          setting.removePostType(postType);
                        }
                      },
                    );
                  })
                  .toList()
                  .cast<Widget>()) +
              [
                const Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Notification Filters:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    )),
                const Padding(
                    padding: EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      "If set, only notifications that match these filters will be shown.",
                      softWrap: true,
                    )),
                GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return RequiredWordsDialog(
                            requiredWords: setting.wordAllowList ?? [],
                            description:
                                "Only posts that contain one of these words will be shown. Leave empty to receive all notifications.",
                            onConfirm: (words) {
                              setting.wordAllowList =
                                  words.isEmpty ? null : words;
                              Provider.of<Settings>(context, listen: false)
                                  .saveNotificationSettings();
                            },
                          );
                        },
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                          top: 10.0, left: 20.0, right: 20.0, bottom: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Required words: ",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: Text(
                              setting.wordAllowList?.join(', ') ?? "Not Set",
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                            ),
                          ),
                          const Text("Tap to Edit",
                              style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    )),
                GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return RequiredWordsDialog(
                            requiredWords: setting.wordBlockList ?? [],
                            description:
                                "If a post contains any of these words, you will not receive a notification.",
                            onConfirm: (words) {
                              setting.wordBlockList =
                                  words.isEmpty ? null : words;
                              Provider.of<Settings>(context, listen: false)
                                  .saveNotificationSettings();
                            },
                          );
                        },
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                          top: 10.0, left: 20.0, right: 20.0, bottom: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Blocked words: ",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: Text(
                              setting.wordBlockList?.join(', ') ?? "Not Set",
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                            ),
                          ),
                          const Text("Tap to Edit",
                              style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ))
              ],
        ));
  }
}

class RequiredWordsDialog extends StatefulWidget {
  final List<String> requiredWords;
  final String? description;
  final Function(List<String>) onConfirm;

  const RequiredWordsDialog({
    super.key,
    required this.requiredWords,
    this.description,
    required this.onConfirm,
  });

  @override
  State<RequiredWordsDialog> createState() => _RequiredWordsDialogState();
}

class _RequiredWordsDialogState extends State<RequiredWordsDialog> {
  late List<String> words;
  String? description;

  @override
  void initState() {
    super.initState();
    words = List<String>.from(widget.requiredWords);
    description = widget.description;
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController wordController = TextEditingController();

    return AlertDialog(
      title: const Text("Edit Required Words"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Text(
                description!,
                softWrap: true,
              ),
            ),
          TextField(
            controller: wordController,
            decoration: const InputDecoration(
              labelText: "Add a word",
              hintText: "Enter a word",
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (wordController.text.isNotEmpty) {
                setState(() {
                  words.add(wordController.text.trim());
                });
                wordController.clear();
              }
            },
            child: const Text("Add"),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(words[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            words.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                )),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            widget.onConfirm(words);
            Navigator.of(context).pop();
          },
          child: const Text("Save"),
        ),
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
  HashSet<(String, String)> expandedDids = HashSet();

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search',
                hintText: 'Search notification settings',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                  expandedDids.clear();
                });
              },
            ),
          ),
          Expanded(
            child: Consumer<Settings>(builder: (context, settings, child) {
              final notificationSettings = settings.notificationSettings
                  .where((setting) =>
                      (setting.cachedName ?? setting.cachedHandle)
                          .toLowerCase()
                          .contains(searchQuery) ||
                      setting.cachedHandle.toLowerCase().contains(searchQuery))
                  .toList();
              notificationSettings.sort((a, b) => (a.cachedName ??
                      a.cachedHandle)
                  .toLowerCase()
                  .compareTo((b.cachedName ?? b.cachedHandle).toLowerCase()));
              return ListView.builder(
                itemCount: notificationSettings.length + 1,
                itemBuilder: (context, index) {
                  if (index == notificationSettings.length) {
                    return const SizedBox(height: 80);
                  }
                  final setting = notificationSettings[index];
                  var expanded = expandedDids
                      .contains((setting.accountDid, setting.followDid));
                  return ExpansionTile(
                    title: UsernameDisplay.fromNotificationSetting(setting),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    key: GlobalKey(),
                    onExpansionChanged: (expanded) {
                      setState(() {
                        if (expanded) {
                          expandedDids
                              .add((setting.accountDid, setting.followDid));
                        } else {
                          expandedDids
                              .remove((setting.accountDid, setting.followDid));
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
                                            setting.accountDid,
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
                    children: [
                      SingleNotificationSettings(
                        setting: setting,
                      ),
                    ],
                  );
                },
              );
            }),
          ),
        ],
      ),
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

    var newExpandedDids = HashSet<(String, String)>();

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
                newExpandedDids.add((account.did, profile.did));
              }
              settings.saveNotificationSettings();
            });
      },
    );
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
