/*
  LocalNotificationService.dart - Mobil platformlarda yerel bildirimler için servis sınıfı
  - Sadece Android ve iOS'ta çalışır, web ve masaüstünde devre dışı bırakılır
  - Doğum günü, özel gün ve duyuru bildirimleri için hazır fonksiyonlar içerir
  - Her platformda çalışacak şekilde SnackBar desteği sağlar
*/
/*
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Sadece mobil platformlarda çalış
    if (!Platform.isAndroid && !Platform.isIOS) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings: settings);
    _isInitialized = true;

    print("✅ Bildirim servisi başlatıldı");
  }

  // 🔥 BASİT BİLDİRİM GÖSTER
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();
    if (!Platform.isAndroid && !Platform.isIOS) return;

    const androidDetails = AndroidNotificationDetails(
      'sport_channel',
      'Spor Uygulaması',
      channelDescription: 'Spor uygulaması bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
    );
    print("📱 Bildirim gönderildi: $title");
  }

  // 🔥 DOĞUM GÜNÜ BİLDİRİMİ
  Future<void> showBirthdayNotification(String studentName) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: "🎂 Doğum Günü!",
      body: "$studentName bugün doğum gününü kutluyor! Onu tebrik edelim.",
    );
  }

  // 🔥 ÖZEL GÜN BİLDİRİMİ
  Future<void> showSpecialDayNotification(
    String eventName,
    String message,
  ) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: "📅 $eventName",
      body: message,
    );
  }

  // 🔥 YENİ DUYURU BİLDİRİMİ
  Future<void> showAnnouncementNotification(
    String title,
    String message,
  ) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: "📢 Yeni Duyuru: $title",
      body: message.length > 100 ? message.substring(0, 100) + "..." : message,
    );
  }

  // 🔥 SNAcKBAR (HER PLATFORMDA ÇALIŞIR)
  void showSnackBar({
    required BuildContext context,
    required String title,
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
*/
