import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_file.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';

// 👇 GLOBAL NAVIGATOR KEY
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 👇 GITHUB BİLGİLERİN
const String GITHUB_USERNAME = "Ahmetoguzz7";
const String GITHUB_REPO = "Spor_Application_Work";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 SADECE UYGULAMAYI BAŞLAT - offline servisleri KALDIR!
  runApp(const MyApp());

  // Güncelleme kontrolü (arka planda)
  Future.delayed(const Duration(seconds: 3), () {
    print("🔍 Güncelleme kontrolü başlatılıyor...");
    checkForUpdate();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: ' EVOM SPOR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const UnifiedLoginPage(),
    );
  }
}

// ==================== GÜNCELLEME FONKSİYONLARI ====================

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

Future<void> checkForUpdate({bool showIfNoUpdate = false}) async {
  print("🔍 Güncelleme kontrolü başlatıldı...");

  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity == ConnectivityResult.none) {
    print("⚠️ İnternet yok, güncelleme kontrolü atlandı");
    if (showIfNoUpdate) {
      _showSnackBar("⚠️ İnternet bağlantısı yok, güncelleme kontrol edilemedi");
    }
    return;
  }

  final current = await getCurrentVersion();
  final latestData = await getLatestReleaseFromGitHub();

  if (latestData != null && isNewerVersion(current, latestData['version'])) {
    print("🔄 Yeni sürüm mevcut! v$current -> v${latestData['version']}");
    final context = navigatorKey.currentContext;
    if (context != null) {
      showUpdateDialog(context, latestData);
    } else {
      print("⚠️ Context bulunamadı, dialog gösterilemiyor");
    }
  } else {
    if (showIfNoUpdate) {
      _showSnackBar("✅ Uygulama güncel (v$current)");
    }
    print("✅ Uygulama güncel.");
  }
}

void _showSnackBar(String message) {
  final context = navigatorKey.currentContext;
  if (context != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }
}

void showUpdateDialog(BuildContext context, Map<String, dynamic> release) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Yeni Sürüm Mevcut! 🚀"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Sürüm: v${release['version']}"),
          const SizedBox(height: 10),
          const Text(
            "Yenilikler:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(release['releaseNotes']),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Sonra"),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            downloadAndInstallApk(release['downloadUrl']);
          },
          child: const Text("Güncelle"),
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
