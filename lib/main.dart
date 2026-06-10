import 'package:EVOM_SPOR/hive_fast_data.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;

// 🔥 SADECE EKLENEN FIREBASE PAKETLERİ
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ============================================================
// GLOBAL TANIMLAR
// ============================================================

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const String GITHUB_USERNAME = "Ahmetoguzz7";
const String GITHUB_REPO = "EVOM_SPOR";

// Google Apps Script URL (Aynen duruyor)
const String _baseUrl =
    "https://script.google.com/macros/s/AKfycbywI2z_lyAX8sYZFxF9Zre-NkzKhHFWYCJykFHZeN_WW4Y4Q27ko3V44S4CZuEC2dW7/exec";

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Workmanager task isimleri (Aynen duruyor)
const String backgroundUpdateTask = "updateCheckTask";
const String backgroundNotificationTask = "notificationCheckTask";

// 🔥 FIREBASE ARKA PLAN BİLDİRİM DİNLEYİCİSİ (Uygulama kapalıyken tetiklenir)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔥 Arka planda Firebase bildirimi alındı: ${message.messageId}");
}

// ============================================================
// BACKGROUND TASK CALLBACK (Android WorkManager - Aynen Duruyor)
// ============================================================

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    print("🔄 Arka plan görevi: $taskName");

    try {
      if (taskName == backgroundUpdateTask) {
        await checkForUpdateBackground();
      } else if (taskName == backgroundNotificationTask) {
        await checkForNewNotificationsBackground();
      }
    } catch (e) {
      print("❌ Arka plan görevi hatası: $e");
    }

    return Future.value(true);
  });
}

// ============================================================
// MAIN
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 SADECE FIREBASE BAŞLATMA ADIMLARI EKLENDİ
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Ön planda bildirimleri yakalamak için dinleyici
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
        "🔔 Uygulama açıkken Firebase bildirimi geldi: ${message.notification?.title}",
      );
      if (message.notification != null) {
        showAppNotification(
          id: message.hashCode,
          title: message.notification!.title ?? 'Bildirim',
          body: message.notification!.body ?? '',
        );
      }
    });

    // Bildirime tıklanıp uygulama açıldığında tetiklenir
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      navigatorKey.currentState?.pushNamed('/notifications');
    });

    // Her ihtimale karşı genel duyurular için konuya abone yapalım
    await FirebaseMessaging.instance.subscribeToTopic("all_users");

    print("🔥 Firebase altyapısı başarıyla eklendi");
  } catch (e) {
    print("❌ Firebase başlatılamadı: $e");
  }

  // Türkçe locale (Aynen duruyor)
  try {
    await initializeDateFormatting('tr_TR', null);
    print("✅ Türkçe locale başlatıldı");
  } catch (e) {
    Intl.defaultLocale = 'tr_TR';
  }

  // İzinler (Aynen duruyor)
  await requestPermissions();

  // Bildirim servisi (Aynen duruyor)
  await initNotifications();

  // Arka plan görevleri (Aynen duruyor)
  await initBackgroundTask();

  runApp(const MyApp());

  // Açılışta güncelleme kontrolü (Aynen duruyor)
  Future.delayed(const Duration(seconds: 3), () {
    checkForUpdateWithNotification();
  });

  // iOS için periyodik kontrol (Aynen duruyor)
  if (Platform.isIOS) {
    _startIOSPeriodicCheck();
  }
}

// ============================================================
// iOS PERİYODİK KONTROL (Aynen duruyor)
// ============================================================

Timer? _iosPeriodicTimer;

void _startIOSPeriodicCheck() {
  _iosPeriodicTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
    print("🍎 iOS periyodik kontrol çalıştı");
    await checkForNewNotificationsBackground();
  });
  print("✅ iOS periyodik kontrol başlatıldı (5 dakikada bir)");
}

// ============================================================
// İZİN YÖNETİMİ (Aynen duruyor)
// ============================================================

Future<void> requestPermissions() async {
  print("🔐 İzinler isteniyor...");

  try {
    final notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied) {
      final status = await Permission.notification.request();
      print(
        status.isGranted
            ? "✅ Bildirim izni verildi"
            : "❌ Bildirim izni reddedildi",
      );
    }

    if (Platform.isAndroid) {
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      if (alarmStatus.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }
  } catch (e) {
    print("⚠️ İzin hatası: $e");
  }
}

// ============================================================
// BİLDİRİM SERVİSİ (Aynen duruyor)
// ============================================================

Future<void> initNotifications() async {
  try {
    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: initAndroid,
      iOS: initIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'open_notifications') {
          navigatorKey.currentState?.pushNamed('/notifications');
        } else if (response.payload != null &&
            response.payload!.startsWith('http')) {
          downloadAndInstallApk(response.payload!);
        }
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'update_channel',
          'Güncelleme Bildirimleri',
          description: 'Uygulama güncellemeleri',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'app_notifications',
          'Uygulama Bildirimleri',
          description: 'Duyurular, ödemeler, yoklama bildirimleri',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );
    }

    print("✅ Bildirim servisi başlatıldı");
  } catch (e) {
    print("❌ Bildirim başlatma hatası: $e");
  }
}

// Güncelleme bildirimi (Aynen duruyor)
Future<void> showUpdateNotification({
  required String title,
  required String body,
  required String downloadUrl,
}) async {
  try {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'update_channel',
      'Güncelleme Bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
      autoCancel: false,
    );

    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: android,
        iOS: ios,
      ),
      payload: downloadUrl,
    );
  } catch (e) {
    print("❌ Güncelleme bildirimi hatası: $e");
  }
}

// Uygulama içi bildirim (Aynen duruyor)
Future<void> showAppNotification({
  required int id,
  required String title,
  required String body,
  String payload = 'open_notifications',
}) async {
  try {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'app_notifications',
      'Uygulama Bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
      autoCancel: true,
    );

    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );

    print("✅ Bildirim gösterildi: $title");
  } catch (e) {
    print("❌ Bildirim hatası: $e");
  }
}

Future<void> showSimpleNotification(String title, String body) async {
  await showAppNotification(id: 99, title: title, body: body);
}

// ============================================================
// YENİ BİLDİRİM KONTROLÜ (Google Sheets Polling - Aynen Duruyor)
// ============================================================

Future<void> checkForNewNotificationsBackground() async {
  print("🔔 Yeni bildirim kontrolü başladı...");

  try {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('logged_user');
    if (userJson == null) {
      print("⚠️ Kullanıcı giriş yapmamış, atlandı");
      return;
    }

    final userMap = json.decode(userJson) as Map<String, dynamic>;
    final userId = userMap['app']?.toString();
    if (userId == null || userId.isEmpty) return;

    final lastCheckStr = prefs.getString('last_notification_check');
    final lastCheck = lastCheckStr != null
        ? DateTime.tryParse(lastCheckStr) ??
              DateTime.now().subtract(const Duration(hours: 1))
        : DateTime.now().subtract(const Duration(hours: 1));

    final response = await http
        .get(Uri.parse("$_baseUrl?sheet=notifications"))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return;

    final decoded = json.decode(response.body);
    if (decoded['success'] != true) return;

    final List<dynamic> allNotifications = decoded['data'] ?? [];
    final String userIdStr = userId.trim();

    final newNotifications = allNotifications.where((item) {
      final recipientId = item['recipient_id']?.toString().trim() ?? '';
      final isRead = item['is_read']?.toString().toUpperCase() ?? 'FALSE';
      final sentAtStr = item['sent_at']?.toString() ?? '';

      final isForUser = recipientId == 'all' || recipientId == userIdStr;
      if (!isForUser) return false;
      if (isRead == 'TRUE') return false;

      final sentAt = _parseDateTime(sentAtStr);
      return sentAt.isAfter(lastCheck);
    }).toList();

    print("📊 Yeni bildirim sayısı: ${newNotifications.length}");

    if (newNotifications.isNotEmpty) {
      if (newNotifications.length == 1) {
        final notif = newNotifications.first;
        await showAppNotification(
          id: 10,
          title: notif['title']?.toString() ?? 'Yeni Bildirim',
          body: notif['message']?.toString() ?? '',
        );
      } else {
        await showAppNotification(
          id: 10,
          title: '${newNotifications.length} Yeni Bildirim',
          body: 'Okumadığınız bildirimleriniz var.',
        );
      }
    }

    await prefs.setString(
      'last_notification_check',
      DateTime.now().toIso8601String(),
    );
  } catch (e) {
    print("❌ Bildirim kontrolü hatası: $e");
  }
}

DateTime _parseDateTime(String dateTimeStr) {
  try {
    if (dateTimeStr.contains('T')) return DateTime.parse(dateTimeStr);
    if (dateTimeStr.contains(' ')) {
      return DateTime.parse(dateTimeStr.replaceAll(' ', 'T'));
    }
    return DateTime(2000);
  } catch (_) {
    return DateTime(2000);
  }
}

// ============================================================
// ARKA PLAN GÖREVİ BAŞLATMA (Workmanager - Aynen Duruyor)
// ============================================================

Future<void> initBackgroundTask() async {
  if (!Platform.isAndroid) return;

  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    await Workmanager().registerPeriodicTask(
      "updateCheckPeriodic",
      backgroundUpdateTask,
      frequency: const Duration(hours: 12),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );

    await Workmanager().registerPeriodicTask(
      "notificationCheckPeriodic",
      backgroundNotificationTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );

    print("✅ Android arka plan görevleri başlatıldı");
  } catch (e) {
    print("⚠️ Arka plan görevi hatası: $e");
  }
}

// ============================================================
// GÜNCELLEME KONTROLÜ (GitHub - Aynen Duruyor)
// ============================================================

Future<void> checkForUpdateBackground() async {
  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity == ConnectivityResult.none) return;

  final current = await getCurrentVersion();
  final latestData = await getLatestReleaseFromGitHub();

  if (latestData != null && isNewerVersion(current, latestData['version'])) {
    await showUpdateNotification(
      title: "🎉 Yeni Güncelleme Mevcut!",
      body:
          "v${latestData['version']} sürümü yayınlandı. Dokunun ve güncelleyin!",
      downloadUrl: latestData['downloadUrl'],
    );
  }
}

Future<String> getCurrentVersion() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  } catch (_) {
    return "1.0.0";
  }
}

Future<Map<String, dynamic>?> getLatestReleaseFromGitHub() async {
  try {
    final url = Uri.parse(
      "https://api.github.com/repos/$GITHUB_USERNAME/$GITHUB_REPO/releases/latest",
    );

    final response = await http
        .get(url, headers: {'Accept': 'application/vnd.github.v3+json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final assets = data['assets'] as List;

      final apkAsset = assets.firstWhere(
        (asset) => asset['name'].toString().endsWith('.apk'),
        orElse: () => null,
      );

      if (apkAsset != null) {
        String version = data['tag_name'].toString().replaceAll(
          RegExp(r'[^0-9.]'),
          '',
        );

        return {
          'version': version,
          'downloadUrl': apkAsset['browser_download_url'],
          'releaseNotes': data['body'] ?? 'Yeni sürüm mevcut.',
        };
      }
    }
  } catch (e) {
    print("❌ GitHub kontrolü hatası: $e");
  }
  return null;
}

bool isNewerVersion(String current, String latest) {
  List<int> parse(String v) =>
      v.split('.').map((e) => int.tryParse(e) ?? 0).toList();

  final v1 = parse(current);
  final v2 = parse(latest);

  for (var i = 0; i < v2.length; i++) {
    int v1Part = i < v1.length ? v1[i] : 0;
    if (v2[i] > v1Part) return true;
    if (v2[i] < v1Part) return false;
  }
  return false;
}

Future<void> checkForUpdateWithNotification() async {
  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity == ConnectivityResult.none) return;

  final current = await getCurrentVersion();
  final latestData = await getLatestReleaseFromGitHub();

  if (latestData != null && isNewerVersion(current, latestData['version'])) {
    String releaseNotes = latestData['releaseNotes'];
    String shortNotes = releaseNotes.length > 50
        ? "${releaseNotes.substring(0, 50)}..."
        : releaseNotes;

    await showUpdateNotification(
      title: "🎉 Zorunlu Güncelleme Mevcut!",
      body: "v${latestData['version']}: $shortNotes",
      downloadUrl: latestData['downloadUrl'],
    );

    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ForceUpdateScreen(updateData: latestData),
        ),
        (route) => false,
      );
    }
  }
}

void showUpdateDialog(BuildContext context, Map<String, dynamic> release) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.system_update, color: Colors.indigo),
          SizedBox(width: 10),
          Text("Yeni Sürüm Mevcut! 🚀"),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "Sürüm: v${release['version']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            "✨ Yenilikler:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              release['releaseNotes'],
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Sonra"),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            downloadAndInstallApk(release['downloadUrl']);
          },
          icon: const Icon(Icons.download),
          label: const Text("Hemen Güncelle"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}

Future<void> downloadAndInstallApk(String url) async {
  final Uri uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await showSimpleNotification(
        "İndirme Başladı",
        "APK dosyası indiriliyor, kurulum için dosyaya dokunun",
      );
    }
  } catch (e) {
    print("❌ İndirme hatası: $e");
  }
}

// ============================================================
// APP (Aynen duruyor)
// ============================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'EVOM SPOR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const UnifiedLoginPage(),
    );
  }
}

// Zorunlu Güncelleme Ekranı (Hata vermemesi için bırakıldı)
class ForceUpdateScreen extends StatelessWidget {
  final Map<String, dynamic> updateData;
  const ForceUpdateScreen({super.key, required this.updateData});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text("Lütfen güncelleyin v${updateData['version']}")),
    );
  }
}
