import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Overview"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Consumer<Settings>(
          builder: (context, settings, child) {
            final notificationHistory = settings.notificationHistory;
            if (notificationHistory.isEmpty) {
              return const Center(
                child: Text("No notifications available."),
              );
            }
            return ListView.builder(
              itemCount: notificationHistory.length,
              itemBuilder: (context, index) {
                final notification = notificationHistory[index];
                return Dismissible(
                  key: Key(notification.timestamp),
                  onDismissed: (direction) {
                    settings.removeNotification(notification);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Notification dismissed')),
                    );
                  },
                  background: Container(color: Colors.red),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.notifications_sharp),
                      title: Text(notification.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification.subtitle),
                          Text(
                            notification.timestamp,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      onTap: () => notification.tap(),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
