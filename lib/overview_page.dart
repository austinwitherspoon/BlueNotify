import 'package:flutter/material.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Overview"),
      ),
      body: const Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          children: <Widget>[
            Card(
              child: ListTile(
                leading: Icon(Icons.notifications_sharp),
                title: Text('Notification 1'),
                subtitle: Text('This is a notification'),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.notifications_sharp),
                title: Text('Notification 2'),
                subtitle: Text('This is a notification'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
