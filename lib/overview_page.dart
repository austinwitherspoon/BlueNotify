import 'package:blue_notify/logs.dart';
import 'package:blue_notify/notification.dart';
import 'package:blue_notify/shoutout.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => reloadNotifications());
  }

  void reloadNotifications({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        loading = true;
      });
    }
    var notifications = await ServerNotification.getAllNotifications();
    setState(() {
      notificationHistory = notifications;
      loading = false;
    });
  }

  void removeNotification(ServerNotification notification) {
    setState(() {
      notificationHistory.remove(notification);
    });
    notification.delete().then((_) {
      reloadNotifications(showLoading: false);
    });
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
                onPressed: () async {
                  await ServerNotification.clearNotifications();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All notifications cleared')),
                  );
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
                        if (notificationHistory.isEmpty) {
                          return const Center(
                            child: Text("No notifications available."),
                          );
                        }
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
                            child: ListView.builder(
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
                                                  notification.image!),
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
