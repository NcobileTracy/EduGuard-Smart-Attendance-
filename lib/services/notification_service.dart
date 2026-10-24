import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Listen to messages while app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
      }
    });
  }

  static Future<void> subscribeToModule(String moduleName) async {
    // Sanitize module name for topic (no spaces, etc.)
    String topic = _sanitizeTopic(moduleName);
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  static Future<void> unsubscribeFromModule(String moduleName) async {
    String topic = _sanitizeTopic(moduleName);
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }

  static String _sanitizeTopic(String moduleName) {
    return moduleName.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]+'), '_');
  }

  static Future<void> subscribeToAll(List<String> modules) async {
    for (var module in modules) {
      await subscribeToModule(module);
    }
  }

  // Note: Sending notifications directly from the client is not recommended for production.
  // In a real-world EduGuard system, this would be handled by a Firebase Cloud Function 
  // triggered by a new session document in Firestore.
  static Future<void> sendSessionNotification({
    required String moduleName,
    required String sessionId,
  }) async {
    try {
      // For the purpose of this project, we'll use a Firestore-triggered approach 
      // by writing to a 'notifications' collection that a Cloud Function would listen to.
      // Alternatively, we can mock the "trigger" here.
      await FirebaseFirestore.instance.collection('notifications').add({
        'topic': _sanitizeTopic(moduleName),
        'title': 'New Attendance Session!',
        'body': 'Attendance for $moduleName is now open. Scan the QR code to mark your presence.',
        'data': {
          'moduleName': moduleName,
          'sessionId': sessionId,
          'type': 'attendance_session',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Notification trigger created for $moduleName');
    } catch (e) {
      debugPrint('Error triggering notification: $e');
    }
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}
