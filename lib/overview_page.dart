import 'package:blue_notify/logs.dart';
import 'package:blue_notify/notification.dart';
import 'package:blue_notify/shoutout.dart';
import 'package:f_logs/f_logs.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings.dart';

List<ServerNotification>? notificationCache;
DateTime? lastNotificationCacheTime;
const notificationCacheTimeout = Duration(minutes: 1);

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  List<ServerNotification> notificationHistory = [];
  bool loading = true;

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
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  void reloadNotifications({bool showLoading = true}) async {
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
      if (context.mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
      return;
    }
    setState(() {
      notificationHistory = notifications;
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
      reloadNotifications(showLoading: false);
    }, onError: (error) {
      Logs.error(text: 'Error deleting notification: $error');
      setState(() {
        notificationHistory.insert(index, notification);
      });
      if (context.mounted) {
        // ignore: use_build_context_synchronously
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
      if (context.mounted) {
        // ignore: use_build_context_synchronously
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Overview"),
        actions: [
          Consumer<Settings>(
            builder: (context, settings, child) {
              return IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  clearNotifications();
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
                                final notification = notificationHistory[index];
                                return Dismissible(
                                  key: Key(notification.id.toString()),
                                  onDismissed: (direction) {
                                    removeNotification(notification);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Notification dismissed')),
                                    );
                                  },
                                  background: Container(color: Colors.red),
                                  child: Card(
                                    child: ListTile(
                                      leading: Container(
                                          padding:
                                              const EdgeInsets.only(top: 8.0),
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
                                          if (notification.image != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 8.0),
                                              child: Image.network(
                                                        notification.image!,
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
                                                      )
                                            ),
                                          Text(
                                            notification.friendlyTimestamp,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Colors.grey.withOpacity(0.6),
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
          const ShoutoutSmall(),
        ],
      ),
    );
  }
}
