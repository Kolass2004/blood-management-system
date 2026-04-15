import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Call this from login/main to persist the UID for the background isolate.
Future<void> saveUidForBackgroundService(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('bg_user_uid', uid);
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Create BOTH notification channels
  const AndroidNotificationChannel foregroundChannel = AndroidNotificationChannel(
    'my_foreground',
    'MY FOREGROUND SERVICE',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
    'urgent_requests',
    'Urgent Lifesaving Requests',
    description: 'Overriding alerts for immediate donor requests',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  
  await androidPlugin?.createNotificationChannel(foregroundChannel);
  await androidPlugin?.createNotificationChannel(urgentChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Blood Donor Node Active',
      initialNotificationContent: 'Initializing location service...',
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

  // Initialize notifications plugin in background isolate
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

  // Re-create urgent channel in background isolate
  const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
    'urgent_requests',
    'Urgent Lifesaving Requests',
    description: 'Overriding alerts for immediate donor requests',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(urgentChannel);

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

  // Get UID — try FirebaseAuth first, fallback to SharedPreferences
  String? uid;
  
  Future<String?> getUid() async {
    // Try Firebase Auth first
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return user.uid;
    // Fallback: read from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bg_user_uid');
  }

  // Keep track of shown notifications
  final Set<String> notifiedRequests = {};

  // Background Location Updater — every 30 seconds
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    uid = await getUid();
    if (uid != null) {
      try {
        Position position = await Geolocator.getCurrentPosition();
        
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'location': {
            'lat': position.latitude,
            'lng': position.longitude,
          },
          'lastUpdate': FieldValue.serverTimestamp()
        });

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Blood Donor Node Active",
            content: "Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}",
          );
        }
      } catch (e) {
        _log("Error getting location: $e");
      }
    } else {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Blood Donor Node",
          content: "Waiting for authentication...",
        );
      }
    }
  });

  // Urgent Emergency Protocol Listener — every 10 seconds
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    uid = await getUid();
    if (uid == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('requests')
          .where('status', isEqualTo: 'pending')
          .get();

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Blood Donor Node Active",
          content: "Monitoring ${querySnapshot.docs.length} request(s)...",
        );
      }

      for (var doc in querySnapshot.docs) {
        if (!notifiedRequests.contains(doc.id)) {
          notifiedRequests.add(doc.id);
          
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
            category: AndroidNotificationCategory.alarm,
            ongoing: true,
            autoCancel: false,
          );

          const NotificationDetails platformChannelSpecifics =
              NotificationDetails(android: androidPlatformChannelSpecifics);

          await flutterLocalNotificationsPlugin.show(
            id: doc.id.hashCode,
            title: '🩸 URGENT: BLOOD MATCH NEEDED',
            body: doc.data()['message'] ?? 'A nearby hospital requires your blood type urgently!',
            notificationDetails: platformChannelSpecifics,
          );

          _log("NOTIFICATION SHOWN for request: ${doc.id}");
        }
      }
    } catch (e) {
      _log("Error fetching requests: $e");
    }
  });
}

void _log(String message) {
  // ignore: avoid_print
  print("[BloodDonorService] $message");
}
