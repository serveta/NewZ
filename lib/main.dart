import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart'
    as permissionHandler;
import 'splashScreen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Request permission for Android 13 and above
  if (Platform.isAndroid &&
      (await permissionHandler.Permission.notification.status).isDenied) {
    await permissionHandler.Permission.notification.request();
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  // Provide a specific channel ID, name, and description for clarity
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await showWelcomeNotification();

  runApp(const MyApp());
}

Future<void> showWelcomeNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'welcome_channel',
    'Welcome Channel',
    channelDescription: 'Displays a welcome notification on startup',
    importance: Importance.max,
    priority: Priority.high,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    0,
    'Welcome to NewZ',
    'Stay updated with the latest news!',
    platformChannelSpecifics,
    payload: 'welcome_payload',
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const SplashScreen(),
    );
  }
}
