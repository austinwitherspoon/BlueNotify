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

showAlertDialog(BuildContext context) {
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
  final _passwordController = TextEditingController();
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
                "Please enter your Bluesky username and an 'App Password'. "
                "Please don't use your actual password! Go into Bluesky -> Settings -> Advanced -> App Passwords "
                "and create a new app password for this app.",
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
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'App Password',
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your app password';
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
                onPressed: login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void login() async {
    if (_formKey.currentState!.validate()) {
      var username = _usernameController.text;
      if (!username.contains(".")) {
        username += ".bsky.social";
        _usernameController.text = username;
      }

      final password = _passwordController.text;
      final account = Account(username, password, "");

      try {
        showAlertDialog(context);
        await LoggedInBlueskyService.login(account);
      } catch (e) {
        developer.log("Failed to login: $e", name: "AccountPage");
        setState(() {
          _formError = e.toString();
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
}
