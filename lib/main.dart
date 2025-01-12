import 'package:blue_notify/notification.dart';
import 'package:blue_notify/notification_page.dart';
import 'package:blue_notify/settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'overview_page.dart';
import 'settings_page.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:sentry_flutter/sentry_flutter.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await settings.init();

  developer.log("Handling a background message");
  await catalogNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await settings.init();
  await FirebaseMessaging.instance.setAutoInitEnabled(true);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://1c06795ba1343fab680c51fb8e1a8b6d@o565526.ingest.us.sentry.io/4508434436718592';
      options.tracesSampleRate = 0.2;
      options.profilesSampleRate = 0.1;
    },
    appRunner: () => runApp(Application()),
  );
}

class Application extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _Application();
}

class _Application extends State<Application> with WidgetsBindingObserver {
  Key key = UniqueKey();
  bool closed = false;

  Future<void> setupInteractedMessage() async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) async {
    developer.log('Tapped a message!');
    final notification = messageToNotification(message);
    if (notification == null) {
      return;
    }
    await notification.tap();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Run code required to handle interacted messages in an async function
    // as initState() must not be async
    setupInteractedMessage();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log('Got a message whilst in the foreground!');
      if (message.notification != null) {
        catalogNotification(message);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (closed) {
        closed = false;
        developer.log('App resumed, reloading settings');
        await settings.reload();
        setState(() {
          key = UniqueKey();
        });
      }
    } else if (state == AppLifecycleState.paused) {
      developer.log('App paused.');
      closed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    const flutterBlue = Color.fromARGB(255, 32, 139, 254);

    final lightModeScheme = ColorScheme.light(
      primary: flutterBlue,
      onPrimary: Colors.white,
      secondary: Color.fromARGB(255, 240, 240, 240),
      onSecondary: Colors.black,
      surface: const Color.fromARGB(255, 255, 255, 255),
    );

    final darkModeScheme = ColorScheme.dark(
      primary: flutterBlue,
      onPrimary: Colors.white,
      secondary: Color.fromARGB(255, 30, 41, 54),
      onSecondary: Colors.white,
      surface: const Color.fromARGB(255, 22, 30, 39),
      outlineVariant: Color.fromARGB(255, 30, 41, 54),
    );

    final app = MaterialApp(
      title: 'BlueNotify - Bluesky Notifications',
      key: key,
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
    bool isIOS = false;
    try {
      if (Platform.isIOS) {
        isIOS = true;
      }
    } catch (e) {}

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        indicatorColor: Theme.of(context).colorScheme.secondary,
        selectedIndex: currentPageIndex,
        destinations: <Widget>[
          if (!isIOS)
            const NavigationDestination(
              selectedIcon: Icon(Icons.home),
              icon: Icon(Icons.home),
              label: 'Overview',
            ),
          const NavigationDestination(
            icon: Icon(Icons.notification_add),
            label: 'Edit Notifications',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      body: <Widget>[
        if (!isIOS) OverviewPage(),
        NotificationPage(),
        SettingsPage(),
      ][currentPageIndex],
    );
  }
}
