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
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:intl/intl.dart'; // 🔥 BUNU EKLE!!!
import 'dart:convert';
import 'dart:async';

// 👇 GLOBAL NAVIGATOR KEY
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 👇 GITHUB BİLGİLERİN
const String GITHUB_USERNAME = "Ahmetoguzz7";
const String GITHUB_REPO = "EVOM_SPOR";

// 👇 BİLDİRİM SERVİSİ
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 👇 BACKGROUND TASK İSMİ
const String backgroundUpdateTask = "updateCheckTask";

// 👇 BACKGROUND TASK CALLBACK
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    print("🔄 Arka plan görevi çalışıyor: $taskName");

    if (taskName == backgroundUpdateTask) {
      await checkForUpdateBackground();
    }

    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('tr_TR', null);
    print("✅ Türkçe locale başlatıldı");
  } catch (e) {
    print("⚠️ Locale hatası: $e, alternatif kullanılıyor");
    Intl.defaultLocale = 'tr_TR';
  }
  // 📱 İzinleri iste
  await requestPermissions();

  // 🔔 Bildirim servisini başlat
  await initNotifications();

  // ⏰ Arka plan görevini başlat
  await initBackgroundTask();

  // 🚀 Uygulamayı başlat
  runApp(const MyApp());

  // 🔍 Açılışta güncelleme kontrolü
  Future.delayed(const Duration(seconds: 3), () {
    checkForUpdateWithNotification();
  });
}

// ==================== İZİN YÖNETİMİ ====================

Future<void> requestPermissions() async {
  print("🔐 İzinler isteniyor...");

  try {
    // Android 13+ için bildirim izni
    final notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        print("✅ Bildirim izni verildi");
      } else {
        print("❌ Bildirim izni reddedildi");
      }
    }

    // Android 12+ için tam alarm izni
    final alarmStatus = await Permission.scheduleExactAlarm.status;
    if (alarmStatus.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    print("✅ Tüm izinler kontrol edildi");
  } catch (e) {
    print("⚠️ İzin hatası: $e");
  }
}

// ==================== BİLDİRİM SERVİSİ ====================

Future<void> initNotifications() async {
  try {
    // Android için kanal ayarları
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.id == 0 && response.payload != null) {
          downloadAndInstallApk(response.payload!);
        }
      },
    );

    // Bildirim kanalı oluştur
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'update_channel',
      'Güncelleme Bildirimleri',
      description: 'Uygulama güncellemeleri için bildirimler',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    print("✅ Bildirim servisi başlatıldı");
  } catch (e) {
    print("❌ Bildirim başlatma hatası: $e");
  }
}

Future<void> showUpdateNotification({
  required String title,
  required String body,
  required String downloadUrl,
}) async {
  try {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'update_channel',
          'Güncelleme Bildirimleri',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
          autoCancel: false,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: downloadUrl,
    );
  } catch (e) {
    print("❌ Bildirim gösterme hatası: $e");
  }
}

Future<void> showSimpleNotification(String title, String body) async {
  try {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'update_channel',
          'Güncelleme Bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id: 1,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  } catch (e) {
    print("❌ Basit bildirim hatası: $e");
  }
}

// ==================== ARKA PLAN GÖREVİ ====================

Future<void> initBackgroundTask() async {
  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    // Her 12 saatte bir arka planda güncelleme kontrolü
    await Workmanager().registerPeriodicTask(
      "updateCheckPeriodic",
      backgroundUpdateTask,
      frequency: const Duration(hours: 12),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );

    print("✅ Arka plan görevi başlatıldı (12 saatte bir)");
  } catch (e) {
    print("⚠️ Arka plan görevi hatası: $e");
  }
}

Future<void> checkForUpdateBackground() async {
  print("🔄 Arka plan güncelleme kontrolü başladı");

  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity == ConnectivityResult.none) {
    print("⚠️ Arka planda: İnternet yok");
    return;
  }

  final current = await getCurrentVersion();
  final latestData = await getLatestReleaseFromGitHub();

  if (latestData != null && isNewerVersion(current, latestData['version'])) {
    print("🎉 Arka planda YENİ SÜRÜM bulundu!");

    await showUpdateNotification(
      title: "🎉 Yeni Güncelleme Mevcut!",
      body:
          "v${latestData['version']} sürümü yayınlandı. Dokunun ve güncelleyin!",
      downloadUrl: latestData['downloadUrl'],
    );
  } else {
    print("✅ Arka planda: Uygulama güncel");
  }
}

// ==================== GÜNCELLEME KONTROLÜ ====================

Future<String> getCurrentVersion() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    print("📱 Mevcut sürüm: ${packageInfo.version}");
    return packageInfo.version;
  } catch (e) {
    print("❌ Sürüm okuma hatası: $e");
    return "1.0.0";
  }
}

Future<Map<String, dynamic>?> getLatestReleaseFromGitHub() async {
  try {
    final url = Uri.parse(
      "https://api.github.com/repos/$GITHUB_USERNAME/$GITHUB_REPO/releases/latest",
    );
    print("🌐 GitHub kontrolü yapılıyor: $url");

    final response = await http.get(
      url,
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );

    print("📡 GitHub response: ${response.statusCode}");

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final assets = data['assets'] as List;
      print("📦 GitHub'dan gelen sürüm: ${data['tag_name']}");

      final apkAsset = assets.firstWhere(
        (asset) => asset['name'].toString().endsWith('.apk'),
        orElse: () => null,
      );

      if (apkAsset != null) {
        String version = data['tag_name'].toString().replaceAll(
          RegExp(r'[^0-9.]'),
          '',
        );
        print("✅ Yeni sürüm bulundu: $version");

        return {
          'version': version,
          'downloadUrl': apkAsset['browser_download_url'],
          'releaseNotes': data['body'] ?? 'Yeni sürüm mevcut.',
        };
      } else {
        print("⚠️ APK dosyası bulunamadı");
      }
    } else {
      print("❌ GitHub'dan veri alınamadı: ${response.statusCode}");
    }
  } catch (e) {
    print("❌ Güncelleme kontrolü hatası: $e");
  }
  return null;
}

bool isNewerVersion(String current, String latest) {
  List<int> parse(String v) {
    return v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  final v1 = parse(current);
  final v2 = parse(latest);

  print("🔍 Sürüm karşılaştırması: $current vs $latest");

  for (var i = 0; i < v2.length; i++) {
    int v1Part = i < v1.length ? v1[i] : 0;
    if (v2[i] > v1Part) return true;
    if (v2[i] < v1Part) return false;
  }
  return false;
}

Future<void> checkForUpdateWithNotification() async {
  print("🔍 Güncelleme kontrolü başlatıldı...");

  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity == ConnectivityResult.none) {
    print("⚠️ İnternet yok, güncelleme kontrolü atlandı");
    await showSimpleNotification(
      "Bağlantı Hatası",
      "İnternet bağlantınız yok, güncelleme kontrol edilemedi",
    );
    return;
  }

  final current = await getCurrentVersion();
  final latestData = await getLatestReleaseFromGitHub();

  if (latestData != null && isNewerVersion(current, latestData['version'])) {
    print("🔄 Yeni sürüm mevcut! v$current -> v${latestData['version']}");

    // Bildirim göster
    String releaseNotes = latestData['releaseNotes'];
    String shortNotes = releaseNotes.length > 50
        ? "${releaseNotes.substring(0, 50)}..."
        : releaseNotes;

    await showUpdateNotification(
      title: "🎉 Yeni Sürüm Mevcut!",
      body: "v${latestData['version']}: $shortNotes",
      downloadUrl: latestData['downloadUrl'],
    );

    // Dialog göster (uygulama açıksa)
    final context = navigatorKey.currentContext;
    if (context != null) {
      showUpdateDialog(context, latestData);
    }
  } else {
    print("✅ Uygulama güncel (v$current)");
  }
}

void showUpdateDialog(BuildContext context, Map<String, dynamic> release) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
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
          child: const Text("Sonra", style: TextStyle(fontSize: 14)),
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
  print("📥 APK indirme başlatılıyor: $url");

  final Uri uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      print("✅ İndirme sayfası açıldı");

      await showSimpleNotification(
        "İndirme Başladı",
        "APK dosyası indiriliyor, kurulum için dosyaya dokunun",
      );
    } else {
      throw 'Link açılamadı';
    }
  } catch (e) {
    print("❌ İndirme hatası: $e");
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(
        navigatorKey.currentContext!,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }
}

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
