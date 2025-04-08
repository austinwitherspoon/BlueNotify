import 'package:blue_notify/logs.dart';
import 'package:blue_notify/notification.dart';
import 'package:blue_notify/notification_page.dart';
import 'package:blue_notify/settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'overview_page.dart';
import 'settings_page.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:io';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:receive_intent/receive_intent.dart';

const dsn = kDebugMode
    ? ''
    : 'https://476441eeec8d8ababd12e7e148193d62@sentry.austinwitherspoon.com/2';

const apiServer =
    kDebugMode ? 'http://10.0.2.2:8004' : 'https://api.bluenotify.app';

void configSentryUser() {
  var blueskyDid = settings.accounts.firstOrNull?.did;
  var blueskyHandle = settings.accounts.firstOrNull?.login;
  String? token = settings.lastToken;
  Sentry.addBreadcrumb(Breadcrumb(
      message: 'Configuring Sentry User: $blueskyDid $blueskyHandle $token'));
  Sentry.configureScope((scope) {
    scope.setUser(
        SentryUser(id: token, username: blueskyDid, name: blueskyHandle));
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await settings.init();
  await FirebaseMessaging.instance.setAutoInitEnabled(true);

  // manually extract the url as a backup in case firebase fails to load message
  String? knownTapUrl;
  bool isAndroid = false;
  try {
    if (Platform.isAndroid) {
      isAndroid = true;
    }
  } catch (e) {
    // ignore the error if we're not running on android
  }
  if (isAndroid) {
    // Try manually finding url from intent
    try {
      final intent = await ReceiveIntent.getInitialIntent();
      final url = intent?.extra?['url'];
      if (url != null) {
        Logs.info(text: 'Found url in intent: $url');
        knownTapUrl = url;
      }
    } catch (e) {
      Logs.error(text: 'Failed to get initial intent: $e');
    }
  }

  RemoteMessage? remoteMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (remoteMessage != null) {
    await handleMessageTap(remoteMessage, fallbackUrl: knownTapUrl);
  } else if (knownTapUrl != null) {
    await openUrl(knownTapUrl);
  }

  await SentryFlutter.init(
    (options) {
      options.debug = false;
      options.dsn = dsn;
      options.tracesSampleRate = 0.2;
      options.profilesSampleRate = 0.1;
      options.sampleRate = 1.0;
      options.experimental.replay.sessionSampleRate = 0.05;
      options.experimental.replay.onErrorSampleRate = 1.0;
      options.experimental.privacy.maskAllImages = false;
      options.experimental.privacy.maskAllText = false;
      options.experimental.privacy.maskAssetImages = false;
      options.attachScreenshot = true;
    },
    appRunner: () => runApp(const SentryWidget(child: Application())),
  );
}

Future<void> handleMessageTap(RemoteMessage message,
    {String? fallbackUrl}) async {
  try {
    try {
      configSentryUser();
    } catch (e) {
      Logs.error(text: 'Failed to configure sentry user: $e');
    }
    final rawNotification = message.notification?.toMap();
    Logs.info(text: 'Tapped a message! $rawNotification');
    String? url = urlFromPushNotification(message);
    if (url == null) {
      if (fallbackUrl != null) {
        Logs.warning(text: 'No notification available, using fallback url');
        url = fallbackUrl;
      }
    }
    if (url == null) {
      Logs.info(text: 'No url found in notification, returning.');
      return;
    }
    Logs.info(
        text:
            'Triggering tap response for notification: $rawNotification, url: $url');
    await openUrl(url);
  } catch (e, stackTrace) {
    Logs.error(
        text: 'Error handling tapped message: $e', stacktrace: stackTrace);
    await Sentry.captureException(
      'Error handling tapped message: $e',
      stackTrace: stackTrace,
    );
  }
}

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<StatefulWidget> createState() => _Application();
}

class _Application extends State<Application> with WidgetsBindingObserver {
  Key key = UniqueKey();
  bool closed = false;

  @override
  void initState() {
    super.initState();
    try {
      configSentryUser();
    } catch (e) {
      Logs.error(text: 'Failed to configure sentry user: $e');
    }
    WidgetsBinding.instance.addObserver(this);
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessageTap);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      Logs.info(text: 'Got a message whilst in the foreground!');
      callForReload();
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
        Logs.info(text: 'App resumed, reloading settings');
        await settings.reload();
        setState(() {
          key = UniqueKey();
        });
        callForReload();
      }
    } else if (state == AppLifecycleState.paused) {
      Logs.info(text: 'App paused.');
      closed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    const flutterBlue = Color.fromARGB(255, 32, 139, 254);

    const lightModeScheme = ColorScheme.light(
      primary: flutterBlue,
      onPrimary: Colors.white,
      secondary: Color.fromARGB(255, 240, 240, 240),
      onSecondary: Colors.black,
      surface: Color.fromARGB(255, 255, 255, 255),
    );

    const darkModeScheme = ColorScheme.dark(
      primary: flutterBlue,
      onPrimary: Colors.white,
      secondary: Color.fromARGB(255, 30, 41, 54),
      onSecondary: Colors.white,
      surface: Color.fromARGB(255, 22, 30, 39),
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
        const OverviewPage(),
        const NotificationPage(),
        SettingsPage(),
      ][currentPageIndex],
    );
  }
}
