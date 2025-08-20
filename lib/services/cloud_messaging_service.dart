import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class CloudMessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AuthService _authService = AuthService();

  /// เริ่ม FCM
  Future<void> initFCM() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // ดึง token ของ device และบันทึก
    String? token = await _messaging.getToken();
    await _saveTokenToFirestore(token);

    // listener ขณะ foreground (optional)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Notification received: ${message.notification?.title}');
    });
  }

  /// Getter เพื่อให้หน้าฝั่ง Admin ใช้งาน onMessage ได้
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  /// บันทึก FCM token ของผู้ใช้ลง Firestore
  Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;
    final userId = _authService.getCurrentUserId();
    if (userId != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmToken': token,
      });
    }
  }
}
