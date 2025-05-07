import 'package:blue_notify/account_page.dart';
import 'package:blue_notify/logs.dart';
import 'package:blue_notify/main.dart';
import 'package:blue_notify/notification.dart';
import 'package:blue_notify/shoutout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'settings.dart';

List<ServerNotification>? notificationCache;
DateTime? lastNotificationCacheTime;
const notificationCacheTimeout = Duration(minutes: 1);
OverviewPageState? overviewPageState;

void callForReload() {
  lastNotificationCacheTime = null;
  if (overviewPageState != null) {
    try {
      overviewPageState!.reloadNotifications(showLoading: false);
    } catch (e) {
      Logs.error(text: 'Error calling for reload: $e');
    }
  }
}

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => OverviewPageState();
}

class OverviewPageState extends State<OverviewPage> {
  List<ServerNotification> notificationHistory = [];
  bool loading = true;
  bool newestFirst = settings.newestFirst;

  @override
  void initState() {
    super.initState();
    var useCache = DateTime.now().difference(lastNotificationCacheTime ??
            DateTime.fromMillisecondsSinceEpoch(0)) <
        notificationCacheTimeout;
    if (useCache) {
      notificationHistory = notificationCache!;
      loading = false;
    } else {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => reloadNotifications());
    }

    overviewPageState = this;
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  void reloadNotifications({bool showLoading = true}) async {
    if (settings.lastToken == null) {
      setState(() {
        loading = false;
      });
      Logs.info(text: 'No token available, cannot reload notifications');
      return;
    }
    if (showLoading) {
      setState(() {
        loading = true;
      });
    }
    List<ServerNotification> notifications;
    try {
      notifications = await ServerNotification.getAllNotifications();
    } catch (e) {
      Logs.error(text: 'Error loading notifications: $e');
      try {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading notifications: $e')),
          );
        }
      } catch (e) {
        Logs.error(text: 'Error showing snackbar: $e');
      }
      return;
    }
    setState(() {
      notificationHistory = notifications;
      sortNotifications();
      loading = false;
    });
    notificationCache = notifications;
    lastNotificationCacheTime = DateTime.now();
  }

  void removeNotification(ServerNotification notification) {
    var index = notificationHistory.indexOf(notification);
    Logs.info(text: 'Removing notification at index $index');
    setState(() {
      notificationHistory.remove(notification);
    });
    notification.delete().then((_) {
      Logs.info(text: 'Notification deleted successfully');
    }, onError: (error) {
      Logs.error(text: 'Error deleting notification: $error');
      setState(() {
        notificationHistory.insert(index, notification);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting notification: $error')),
        );
      }
    });
  }

  Future<void> clearNotifications() async {
    try {
      await ServerNotification.clearNotifications();
    } catch (e) {
      Logs.error(text: 'Error clearing notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing notifications: $e')),
        );
      }
      return;
    }
    setState(() {
      notificationHistory.clear();
    });
    notificationCache = [];
  }

  void updateSortMode() {
    setState(() {
      newestFirst = !newestFirst;
      settings.newestFirst = newestFirst;
    });
    sortNotifications();
  }

  void sortNotifications() {
    setState(() {
      if (newestFirst) {
        notificationHistory.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        notificationHistory.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if accounts are empty
    if (settings.accounts.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Overview"),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "No accounts set up.",
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AccountPage()),
                  ).then((_) => setState(() {}));
                },
                child: const Text("Add Account"),
              ),
            ],
          ),
        ),
      );
    }

    // flip the icon based on the sort mode
    var sortIcon = Transform(
        alignment: Alignment.center,
        transform:
            newestFirst ? Matrix4.rotationX(0) : Matrix4.rotationX(math.pi),
        child: const Icon(Icons.sort));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Overview"),
        actions: [
          IconButton(
            icon: sortIcon,
            onPressed: updateSortMode,
            tooltip: newestFirst ? 'Sort Newest First' : 'Sort Oldest First',
          ),
          Consumer<Settings>(
            builder: (context, settings, child) {
              return IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Confirm Clear'),
                        content: const Text(
                            'Are you sure you want to clear all notifications?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Clear'),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirm == true) {
                    clearNotifications();
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? Container(
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.all(16.0),
                    child: const CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Consumer<Settings>(
                      builder: (context, settings, child) {
                        return RefreshIndicator(
                            onRefresh: () async {
                              try {
                                reloadNotifications(showLoading: true);
                              } catch (e) {
                                Logs.error(text: 'Error loading history: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Error loading history: $e')),
                                );
                              }
                            },
                            child: notificationHistory.isEmpty
                                ? ListView(children: const [
                                    Center(
                                      child:
                                          Text("No notifications available."),
                                    )
                                  ])
                                : ListView.builder(
                                    itemCount: notificationHistory.length,
                                    itemBuilder: (context, index) {
                                      final notification =
                                          notificationHistory[index];

                                      String? image;

                                      if (kIsWeb) {
                                        if (notification.image != null) {
                                          var urlEncoded = Uri.encodeComponent(
                                              notification.image!);
                                          image =
                                              '$apiServer/image/$urlEncoded';
                                        }
                                      }
                                      return Dismissible(
                                        key: Key(notification.id.toString()),
                                        onDismissed: (direction) {
                                          removeNotification(notification);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Notification dismissed')),
                                          );
                                        },
                                        background:
                                            Container(color: Colors.red),
                                        child: Card(
                                          child: ListTile(
                                            leading: Container(
                                                padding: const EdgeInsets.only(
                                                    top: 8.0),
                                                child: const Icon(
                                                    Icons.notifications_sharp)),
                                            titleAlignment:
                                                ListTileTitleAlignment.top,
                                            title: Text(notification.title),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(notification.body),
                                                if (image != null)
                                                  Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 8.0),
                                                      child: Image.network(
                                                        image,
                                                        width:
                                                            kIsWeb ? 300 : null,
                                                        loadingBuilder: (context,
                                                            child,
                                                            loadingProgress) {
                                                          if (loadingProgress ==
                                                              null) {
                                                            return child;
                                                          } else {
                                                            return const Center(
                                                              child:
                                                                  CircularProgressIndicator(
                                                                color:
                                                                    Colors.blue,
                                                              ),
                                                            );
                                                          }
                                                        },
                                                        errorBuilder:
                                                            (BuildContext
                                                                    context,
                                                                Object
                                                                    exception,
                                                                StackTrace?
                                                                    stackTrace) {
                                                          return const Text(
                                                            'Image failed to load, this post may have been deleted.',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.red,
                                                            ),
                                                          );
                                                        },
                                                      )),
                                                Text(
                                                  notification
                                                      .friendlyTimestamp,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey
                                                        .withOpacity(0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            onTap: () => notification.tap(),
                                          ),
                                        ),
                                      );
                                    },
                                  ));
                      },
                    ),
                  ),
          ),
          const ShoutOutSmall(),
        ],
      ),
    );
  }
}
