import 'package:blue_notify/account_page.dart';
import 'package:blue_notify/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Consumer<Settings>(builder: (context, settings, child) {
        return ListView(
          children: <Widget>[
            ListTile(
              title: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
                onPressed: () async {
                  showLoadingDialog(context);
                  await settings.forceResync();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Resync completed')),
                  );
                },
                child: const Text("Force Resync"),
              ),
            ),
            ListTile(
              title: ElevatedButton(
                child: const Text("Remove All Notification Settings"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Confirm Removal"),
                        content: const Text(
                            "Are you sure you want to remove all notification settings? This action cannot be undone."),
                        actions: <Widget>[
                          TextButton(
                            child: const Text("Cancel"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            child: const Text("Remove"),
                            onPressed: () async {
                              await settings.removeAllNotificationSettings();
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'All notification settings removed')),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            const ListTile(
              title: Text("Accounts"),
            ),
            if (settings.accounts.isEmpty)
              const ListTile(
                title: Text("No active accounts."),
              )
            else
              ...settings.accounts.map((account) {
                return ListTile(
                  title: Text(account.login),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text("Confirm Removal"),
                            content: const Text(
                                "Are you sure you want to remove this account and all notifications associated with it?"),
                            actions: <Widget>[
                              TextButton(
                                child: const Text("Cancel"),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              TextButton(
                                child: const Text("Remove"),
                                onPressed: () {
                                  settings.removeAccount(account.did);
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              }).toList(),
            ListTile(
              title: ElevatedButton(
                child: const Text("Add an Account"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AccountPage()),
                  );
                },
              ),
            ),
          ],
        );
      }),
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
