import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/internet/internet_check.dart';
import 'package:EVOM_SPOR/internet/internt_close.dart';
import 'package:EVOM_SPOR/internet/network_aware_wrapper.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase paketleri
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Sayfalar
import 'package:EVOM_SPOR/unifiedLoginPage.dart';

// ============================================================
// GLOBAL TANIMLAR
// ============================================================

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const String GITHUB_USERNAME = "Ahmetoguzz7";
const String GITHUB_REPO = "EVOM_SPOR";
const String _baseUrl =
    "https://script.google.com/macros/s/AKfycbyPokHSOEp08uz2SgbQ6z7LFwZ2P6mMb77XmQZAzZNYsRSxnpKohgkP3uPmAALk96RhMg/exec";

const String backgroundUpdateTask = "updateCheckTask";
const String backgroundNotificationTask = "notificationCheckTask";
const String backgroundAttendanceSyncTask = "attendanceSyncTask";
// ============================================================
// 🔥 FIREBASE ARKA PLAN HANDLER
// ============================================================

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (message.notification != null) {
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: message.notification?.title ?? 'Bildirim',
      body: message.notification?.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'app_notifications',
          'Uygulama Bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

// ============================================================
// BACKGROUND TASK CALLBACK
// ============================================================

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == backgroundUpdateTask) {
      await checkForUpdateBackground();
    } else if (taskName == backgroundNotificationTask) {
      await checkForNewNotificationsBackground();
    } else if (taskName == backgroundAttendanceSyncTask) {
      // YENİ
      await syncAttendancesInBackground();
    }
    return Future.value(true);
  });
}

// ============================================================
// MAIN - İNTERNET KONTROLLÜ
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Türkçe locale
  try {
    await initializeDateFormatting('tr_TR', null);
  } catch (e) {
    Intl.defaultLocale = 'tr_TR';
  }

  // Önce internet kontrolü yap
  final hasInternet = await _checkInternetOnStart();

  // UI başlat
  runApp(MyApp(initialHasInternet: hasInternet));

  // Arka plan işlemleri (UI bloklanmasın)
  unawaited(_initializeAppInBackground());
}

// 🔥 BAŞLANGIÇTA İNTERNET KONTROLÜ
Future<bool> _checkInternetOnStart() async {
  try {
    final results = await Connectivity().checkConnectivity();
    final hasInternet = results != ConnectivityResult.none;

    if (hasInternet) {
      // Gerçek internet kontrolü için küçük bir ping at
      try {
        final response = await http
            .get(Uri.parse("$_baseUrl?sheet=users&limit=1"))
            .timeout(const Duration(seconds: 5));
        return response.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
    return false;
  } catch (e) {
    return false;
  }
}

Future<void> syncAttendancesInBackground() async {
  try {
    // Servisi başlat ve kuyruğu işle
    final service = OfflineAttendanceService();
    await service.init();
    await service.processQueueNow();
  } catch (e) {
    // Sessiz geç
  }
}

// Arka planda başlatılacak tüm işlemler
Future<void> _initializeAppInBackground() async {
  // Internet checker dinleyicisi
  final internetChecker = InternetChecker();
  internetChecker.startListening();

  // Firebase başlat
  await Firebase.initializeApp();

  // Arka plan handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // İzinler
  unawaited(requestPermissions());

  // Bildirim servisi
  unawaited(initNotifications());

  // Firebase topic
  _subscribeToTopicWithTimeout();

  // Token işlemleri
  _setupFirebaseTokenHandling();

  // Arka plan görevleri
  unawaited(initBackgroundTask());

  // Güncelleme kontrolü
  _scheduleUpdateCheck();

  if (Platform.isIOS) {
    _startIOSPeriodicCheck();
  }
}

// ============================================================
// TOPIC SUBSCRIBE
// ============================================================

void _subscribeToTopicWithTimeout() {
  Future.delayed(Duration.zero, () {
    FirebaseMessaging.instance
        .subscribeToTopic("all_users")
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint("⚠️ Topic subscribe timeout - skipping");
            return;
          },
        )
        .catchError((e) {
          debugPrint("⚠️ Topic subscribe error: $e");
        });
  });
}

// ============================================================
// FIREBASE TOKEN HANDLING
// ============================================================

void _setupFirebaseTokenHandling() async {
  Future.delayed(const Duration(milliseconds: 500), () async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _saveTokenToServer(token);
      }
    } catch (e) {
      debugPrint("⚠️ Token alınamadı: $e");
    }
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    _saveTokenToServer(newToken);
  });
}

// ============================================================
// FCM TOKEN KAYDET
// ============================================================
Future<void> _saveTokenToServer(String token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('logged_user');
    if (userJson == null) return;

    final userMap = json.decode(userJson) as Map<String, dynamic>;
    final userId = userMap['app']?.toString();
    if (userId == null) return;

    await http
        .post(
          Uri.parse(_baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'action': 'updateFcmToken',
            'user_id': userId,
            'fcm_token': token,
          }),
        )
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    // Sessizce başarısız ol
  }
}

// ============================================================
// GÜNCELLEME KONTROL
// ============================================================

void _scheduleUpdateCheck() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(seconds: 2), () {
      checkForUpdateWithNotification();
    });
  });
}

// ============================================================
// iOS PERİYODİK KONTROL
// ============================================================

Timer? _iosPeriodicTimer;

void _startIOSPeriodicCheck() {
  _iosPeriodicTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
    await checkForNewNotificationsBackground();
  });
}

// ============================================================
// İZİN YÖNETİMİ
// ============================================================

Future<void> requestPermissions() async {
  try {
    final notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied) {
      await Permission.notification.request();
    }

    if (Platform.isAndroid) {
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      if (alarmStatus.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }
  } catch (e) {
    // Sessiz geç
  }
}

// ============================================================
// BİLDİRİM SERVİSİ
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
        ),
      );

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'app_notifications',
          'Uygulama Bildirimleri',
          description: 'Duyurular, ödemeler, yoklama bildirimleri',
          importance: Importance.high,
        ),
      );
    }
  } catch (e) {
    // Sessiz geç
  }
}

// ============================================================
// GÜNCELLEME KONTROL FONKSİYONLARI
// ============================================================

Future<void> checkForUpdateBackground() async {
  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity == ConnectivityResult.none) return;

  final current = await getCurrentVersion();
  final latestData = await getLatestReleaseFromGitHub();

  if (latestData != null && isNewerVersion(current, latestData['version'])) {
    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: "🎉 Yeni Güncelleme Mevcut!",
      body:
          "v${latestData['version']} sürümü yayınlandı. Dokunun ve güncelleyin!",
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'update_channel',
          'Güncelleme Bildirimleri',
          importance: Importance.max,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: latestData['downloadUrl'],
    );
  }
}

Future<void> checkForNewNotificationsBackground() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('logged_user');
    if (userJson == null) return;

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
        .timeout(const Duration(seconds: 10));
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
    // Sessiz geç
  }
}

DateTime _parseDateTime(String dateTimeStr) {
  try {
    if (dateTimeStr.contains('T')) return DateTime.parse(dateTimeStr);
    if (dateTimeStr.contains(' '))
      return DateTime.parse(dateTimeStr.replaceAll(' ', 'T'));
    return DateTime(2000);
  } catch (_) {
    return DateTime(2000);
  }
}

Future<void> checkForUpdateWithNotification() async {
  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity == ConnectivityResult.none) return;

  final current = await getCurrentVersion();
  final latestData = await getLatestReleaseFromGitHub();

  if (latestData != null && isNewerVersion(current, latestData['version'])) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ForceUpdateScreen(updateData: latestData),
      ),
      (route) => false,
    );
  }
}

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
  } catch (e) {
    // Sessiz geç
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
    // Sessiz geç
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

Future<void> downloadAndInstallApk(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    // Sessiz geç
  }
}

Future<void> initBackgroundTask() async {
  if (!Platform.isAndroid) return;

  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    // Mevcut task'ler...
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

    // 🆕 YOKLAMA SENKRONİZASYONU (15 dakikada bir)
    await Workmanager().registerPeriodicTask(
      "attendanceSyncPeriodic",
      backgroundAttendanceSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (e) {
    // Sessiz geç
  }
}

// ============================================================
// FORCE UPDATE SCREEN
// ============================================================

class ForceUpdateScreen extends StatelessWidget {
  final Map<String, dynamic> updateData;
  const ForceUpdateScreen({super.key, required this.updateData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade600, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_alt,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Yeni Güncelleme Mevcut!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "v${updateData['version']} sürümü yayınlandı.",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  updateData['releaseNotes'] ??
                      'Yeni özellikler ve hata düzeltmeleri',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final url = updateData['downloadUrl'];
                    if (url != null) await downloadAndInstallApk(url);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Güncelle",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MY APP - İNTERNET KONTROLLÜ
// ============================================================

class MyApp extends StatefulWidget {
  final bool initialHasInternet;
  const MyApp({super.key, required this.initialHasInternet});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _hasInternet;
  late InternetChecker _internetChecker;

  @override
  void initState() {
    super.initState();
    _hasInternet = widget.initialHasInternet;
    _internetChecker = InternetChecker();
    _internetChecker.startListening();

    // İnternet durumu değişikliklerini dinle
    _internetChecker.onInternetGained(() {
      if (mounted) {
        setState(() {
          _hasInternet = true;
        });
        // İnternet geldiğinde otomatik yenile
        _onInternetGained();
      }
    });

    _internetChecker.onInternetLost(() {
      if (mounted) {
        setState(() {
          _hasInternet = false;
        });
      }
    });
  }

  void _onInternetGained() {
    // İnternet geldiğinde yapılacak işlemler
    print("🌐 İnternet bağlantısı sağlandı, otomatik yenileme yapılıyor...");
  }

  void _onRetry() {
    setState(() {
      _hasInternet = true;
    });
  }

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
      home: const NetworkAwareWrapper(child: UnifiedLoginPage()),
      routes: {'/notifications': (context) => const NotificationsPage()},
    );
  }
}

// ============================================================
// NOTIFICATIONS PAGE
// ============================================================

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bildirimler")),
      body: const Center(child: Text("Bildirim listesi")),
    );
  }
}
