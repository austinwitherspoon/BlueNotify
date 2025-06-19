import 'dart:convert';
import 'dart:io';

import 'package:blue_notify/account_page.dart';
import 'package:blue_notify/logs.dart';
import 'package:blue_notify/notification.dart';
import 'package:blue_notify/settings.dart';
import 'package:blue_notify/shoutout.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    var mq = MediaQuery.of(context);

    var showShoutOut = mq.size.height > 650 && mq.textScaler.scale(10) < 20;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Consumer<Settings>(builder: (context, settings, child) {
        return Column(children: [
          Expanded(
            child: ListView(
              children: <Widget>[
                ListTile(
                  title: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                    ),
                    onPressed: () async {
                      showLoadingDialog(context);
                      await checkNotificationPermission();
                      await settings.forceResync();
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Resync completed')),
                      );
                    },
                    child: const Text(
                      "Force Resync",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                ListTile(
                  title: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                    ),
                    onPressed: () async {
                      String? reason = await showDialog<String>(
                        context: context,
                        builder: (BuildContext context) {
                          var currentInput = '';
                          return AlertDialog(
                            title: const Text("Send Error Report to Developer"),
                            content: TextField(
                              onChanged: (value) {
                                currentInput = value;
                              },
                              decoration: const InputDecoration(
                                  hintText: "What went wrong in the app?"),
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: const Text("Cancel"),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              TextButton(
                                child: const Text("Send"),
                                onPressed: () {
                                  Navigator.of(context).pop(currentInput);
                                },
                              ),
                            ],
                          );
                        },
                      );
                      if (reason != null && reason.isNotEmpty) {
                        Logs.info(text: 'User feedback: $reason');
                        var success = await Logs.sendLogs();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(success
                                  ? 'Error report sent successfully.'
                                  : 'Failed to send error report! Please try again later.')),
                        );
                      }
                    },
                    child: const Text("Send Error Report to Developer",
                        textAlign: TextAlign.center),
                  ),
                ),
                ListTile(
                  title: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
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
                                  await settings
                                      .removeAllNotificationSettings();
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
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
                    child: const Text(
                      "Remove All Notification Settings",
                      textAlign: TextAlign.center,
                    ),
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
                  }),
                ListTile(
                  title: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AccountPage()),
                      );
                    },
                    child: const Text("Add an Account"),
                  ),
                ),
                const Divider(),
                ListTile(
                  title: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                    ),
                    onPressed: () async {
                      try {
                        showLoadingDialog(context);
                        final json_string = settings.backupSettingsToJson();
                        String? savePath = await FilePicker.platform.saveFile(
                          dialogTitle:
                              'Select location to save settings backup',
                          fileName: 'blue_notify_settings.json',
                          bytes: utf8.encode(json_string),
                        );
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Settings backed up successfully.')),
                        );
                      } catch (e) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Backup failed: $e')),
                        );
                      }
                    },
                    child: const Text(
                      "Backup Settings",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                ListTile(
                  title: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                    ),
                    onPressed: () async {
                      FilePickerResult? result =
                          await FilePicker.platform.pickFiles(
                        dialogTitle: 'Select settings backup file to restore',
                        type: FileType.custom,
                        allowedExtensions: ['json'],
                        withData: true,
                      );
                      if (result == null) return;
                      try {
                        String jsonString =
                            utf8.decode(result.files.single.bytes!);
                        showLoadingDialog(context);
                        await settings.restoreSettingsFromJson(jsonString);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Settings restored successfully.')),
                        );
                      } catch (e) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Restore failed: $e')),
                        );
                      }
                    },
                    child: const Text(
                      "Restore Settings",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showShoutOut) const ShoutOut(),
        ]);
      }),
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
