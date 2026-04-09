import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // id
    'MY FOREGROUND SERVICE', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'AWESOME SERVICE',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Keep track of shown notifications to avoid spamming
  final Set<String> _notifiedRequests = {};

  // Background Location Updater
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'location': {
            'lat': position.latitude,
            'lng': position.longitude,
          },
          'lastUpdate': FieldValue.serverTimestamp()
        });

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Node Locator Active",
          content: "Location secured... (${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)})",
        );
      }
      } catch (e) {
        print("Error getting location: $e");
      }
    }
  });

  // Urgent Emergency Protocol Listener
  Timer.periodic(const Duration(seconds: 15), (timer) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('requests')
            .where('status', isEqualTo: 'pending')
            .get();

        for (var doc in querySnapshot.docs) {
          if (!_notifiedRequests.contains(doc.id)) {
            _notifiedRequests.add(doc.id);
            
            final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
                FlutterLocalNotificationsPlugin();

            const AndroidNotificationDetails androidPlatformChannelSpecifics =
                AndroidNotificationDetails(
              'urgent_requests',
              'Urgent Lifesaving Requests',
              channelDescription: 'Overriding alerts for immediate donor requests',
              importance: Importance.max,
              priority: Priority.high,
              fullScreenIntent: true,
              enableVibration: true,
              color: Color(0xFFE11D48),
              playSound: true,
              visibility: NotificationVisibility.public,
            );

            const NotificationDetails platformChannelSpecifics =
                NotificationDetails(android: androidPlatformChannelSpecifics);

            await flutterLocalNotificationsPlugin.show(
              doc.id.hashCode,
              'URGENT: BLOOD MATCH NEEDED',
              doc.data()['message'] ?? 'A nearby hospital requires your blood type urgently!',
              platformChannelSpecifics,
            );
          }
        }
      } catch (e) {
        print("Error fetching requests: $e");
      }
    }
  });
}
