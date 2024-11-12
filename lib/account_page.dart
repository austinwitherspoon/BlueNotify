import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings.dart';
import 'package:blue_notify/bluesky.dart';
import 'dart:developer' as developer;

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
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

class _AccountPageState extends State<AccountPage> {
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _formError = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Account"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                "Please enter your bluesky handle! (e.g. alice.bsky.social).\n"
                "We use this to grab a list of people you're following.",
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your username';
                  }
                  return null;
                },
              ),
              if (_formError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _formError,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: checkAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('Add Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void checkAccount() async {
    if (_formKey.currentState!.validate()) {
      var username = _usernameController.text;
      if (!username.contains(".")) {
        username += ".bsky.social";
        _usernameController.text = username;
      }

      final account = AccountReference(username, "");

      try {
        showLoadingDialog(context);
        var con = await BlueskyService.getPublicConnection();
        try {
          var profile = await con.getProfile(username);
          account.did = profile.did;
        } catch (e) {
          developer.log("Invalid account!: $e", name: "AccountPage");
          setState(() {
            _formError = "Could not find account";
          });
          Navigator.pop(context);
          return;
        }
      } catch (e) {
        developer.log("Failed to connect to bluesky: $e", name: "AccountPage");
        setState(() {
          _formError = "Could not connect to bluesky: " + e.toString();
        });
        Navigator.pop(context);
        return;
      }

      final settings = Provider.of<Settings>(context, listen: false);
      settings.addAccount(account);
      Navigator.pop(context);
      Navigator.pop(context);
    }
  }

  // void login() async {
  //   if (_formKey.currentState!.validate()) {
  //     var username = _usernameController.text;
  //     if (!username.contains(".")) {
  //       username += ".bsky.social";
  //       _usernameController.text = username;
  //     }

  //     final password = _passwordController.text;
  //     final account = LoggedInAccount(username, password, "");

  //     try {
  //       showAlertDialog(context);
  //       await LoggedInBlueskyService.login(account);
  //     } catch (e) {
  //       developer.log("Failed to login: $e", name: "AccountPage");
  //       setState(() {
  //         _formError = e.toString();
  //       });
  //       Navigator.pop(context);
  //       return;
  //     }

  //     final settings = Provider.of<Settings>(context, listen: false);
  //     settings.addAccount(account);
  //     Navigator.pop(context);
  //     Navigator.pop(context);
  //   }
  // }
}
