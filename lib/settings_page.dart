import 'package:blue_notify/account_page.dart';
import 'package:blue_notify/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              title: const Text("Notifications Enabled"),
              trailing: Switch(
                value: settings.enabled,
                onChanged: (value) {
                  settings.enabled = value;
                },
              ),
            ),
            ListTile(
                title: const Text("Sync Frequency (minutes)"),
                trailing: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2,
                    child: TextFormField(
                        controller: TextEditingController(
                            text: settings.syncFrequency.toString()),
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (value) {
                          try {
                            int.parse(value);
                          } catch (e) {
                            return;
                          }
                          settings.syncFrequency = int.parse(value);
                        }))),
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
