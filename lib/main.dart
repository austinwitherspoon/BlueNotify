import 'package:blue_notify/notification_page.dart';
import 'package:blue_notify/settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'overview_page.dart';
import 'settings_page.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await settings.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseMessaging.instance.setAutoInitEnabled(true);
  final notificationSettings =
      await FirebaseMessaging.instance.requestPermission(provisional: true);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final fcmToken = await FirebaseMessaging.instance.getToken();
  print('FCM Token: $fcmToken');
  runApp(Application());
}

class Application extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _Application();
}

class _Application extends State<Application> {
  Future<void> setupInteractedMessage() async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) async {
    final url = message.data['url'] ?? null;
    if (url != null) {
      print('Opening URL: $url');
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri)) {
        print('Could not launch $uri');
        return;
      }
    }
  }

  void initState() {
    super.initState();
    // Run code required to handle interacted messages in an async function
    // as initState() must not be async
    setupInteractedMessage();
  }
  @override
  Widget build(BuildContext context) {
    const flutterBlue = Color.fromARGB(255, 32, 139, 254);
    const secondary = Color.fromARGB(255, 30, 41, 54);

    final lightModeScheme = ColorScheme.light(
      primary: flutterBlue,
      onPrimary: Colors.white,
      secondary: Color.fromARGB(255, 200, 200, 200),
      onSecondary: Colors.black,
      surface: const Color.fromARGB(255, 22, 30, 39),
    );

    final darkModeScheme = ColorScheme.dark(
      primary: flutterBlue,
      onPrimary: Colors.white,
      secondary: Color.fromARGB(255, 30, 41, 54),
      onSecondary: Colors.white,
      surface: const Color.fromARGB(255, 22, 30, 39),
    );

    final app = MaterialApp(
      title: 'BlueNotify - Bluesky Notifications',
      theme: ThemeData(
        colorScheme: lightModeScheme,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: darkModeScheme,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const Navigation(),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => settings),
      ],
      child: app,
    );
  }
}

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        indicatorColor: Theme.of(context).colorScheme.secondary,
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.notification_add),
            label: 'Edit Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      body: <Widget>[
        /// Home page
        OverviewPage(),

        /// Notifications page
        NotificationPage(),

        /// Settings page
        SettingsPage(),
      ][currentPageIndex],
    );
  }
}
