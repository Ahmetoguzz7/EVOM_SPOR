import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/local/local_db.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

// =========================================================================
// 🔥 CACHE MEKANİZMASI
// =========================================================================

class _CacheItem {
  final dynamic data;
  final DateTime expiry;
  _CacheItem({required this.data, required this.expiry});
  bool get isExpired => DateTime.now().isAfter(expiry);
}

class DataCache {
  static final DataCache _instance = DataCache._internal();
  factory DataCache() => _instance;
  DataCache._internal();

  final Map<String, _CacheItem> _cache = {};
  final Map<String, Future> _pendingFetches = {};

  // Cache süreleri (saniye)
  static const int CACHE_LONG = 3600; // 1 saat (şubeler, sporlar)
  static const int CACHE_MEDIUM = 300; // 5 dakika (gruplar, öğrenciler)
  static const int CACHE_SHORT = 60; // 1 dakika (yoklamalar, ödemeler)
  static const int CACHE_VERY_SHORT = 30; // 30 saniye (bildirimler)

  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    int ttlSeconds = CACHE_MEDIUM,
    bool forceRefresh = false,
  }) async {
    // Force refresh varsa cache'i temizle
    if (forceRefresh) {
      _cache.remove(key);
    }

    // Cache'de varsa döndür
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      print("📦 CACHE HIT: $key");
      return cached.data as T;
    }

    print("🌐 CACHE MISS: $key - Veri çekiliyor...");

    // Aynı anda birden fazla istek varsa bekle
    if (_pendingFetches.containsKey(key)) {
      print("⏳ BEKLE: $key - Zaten yükleniyor");
      return _pendingFetches[key] as Future<T>;
    }

    // Yeni fetch başlat
    final future = fetcher()
        .then((value) {
          _cache[key] = _CacheItem(
            data: value,
            expiry: DateTime.now().add(Duration(seconds: ttlSeconds)),
          );
          _pendingFetches.remove(key);
          print("✅ CACHE SET: $key (${ttlSeconds}s)");
          return value;
        })
        .catchError((e) {
          _pendingFetches.remove(key);
          throw e;
        });

    _pendingFetches[key] = future;
    return future;
  }

  void invalidate(String key) {
    _cache.remove(key);
    // print("🗑️ CACHE INVALIDATE: $key");
  }

  void invalidateAll() {
    _cache.clear();
    // print("🗑️ CACHE CLEARED: Tüm cache temizlendi");
  }

  // Tablo bazlı cache temizleme
  void invalidateTable(String tableName) {
    invalidate('table_$tableName');
  }

  // Belli bir süre cache'de kalan verileri temizle
  void invalidateExpired() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    _cache.forEach((key, item) {
      if (item.isExpired) {
        keysToRemove.add(key);
      }
    });
    for (var key in keysToRemove) {
      _cache.remove(key);
    }
    if (keysToRemove.isNotEmpty) {
      // print("🗑️ Expired cache temizlendi: ${keysToRemove.length} adet");
    }
  }
}

class GoogleSheetService {
  static final DataCache _cache = DataCache();

  static const String _baseUrl =
      "https://script.google.com/macros/s/AKfycbxhKZEJa39pwINsbZt0xcpFOgKXLGvZDOvPDmgdzb1xHkaC0sgWtx8QltplpCa-jp3V/exec";

  // =========================================================================
  // 🔥 MERKEZİ POST FONKSİYONU (302 YÖNLENDİRMESİNİ OTOMATİK ÇÖZER)
  // =========================================================================
  static Future<http.Response?> _postRequest(
    Map<String, dynamic> bodyData,
  ) async {
    print("📡 POST isteği: ${bodyData['action']}");

    try {
      var response = await http.post(
        Uri.parse(_baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(bodyData),
      );

      print("📡 Response status: ${response.statusCode}");
      print("📡 Response body: ${response.body}");

      if (response.statusCode == 302) {
        String? redirectUrl = response.headers['location'];
        print("📡 302 Redirect: $redirectUrl");

        if (redirectUrl == null && response.body.contains('HREF="')) {
          final start = response.body.indexOf('HREF="') + 6;
          final end = response.body.indexOf('"', start);
          redirectUrl = response.body
              .substring(start, end)
              .replaceAll('&amp;', '&');
        }

        if (redirectUrl != null) {
          response = await http.get(Uri.parse(redirectUrl));
          print("📡 Redirect response status: ${response.statusCode}");
        }
      }

      return response;
    } catch (e) {
      print("❌ POST İstek Hatası: $e");
      return null;
    }
  }

  // =========================================================================
  // ✅ CACHE'Lİ FETCH TABLE
  // =========================================================================

  static Future<List<dynamic>> fetchTableCached(
    String sheetName, {
    bool forceRefresh = false,
    int? ttlSeconds,
  }) async {
    // Her tablo için farklı cache süresi
    int ttl;
    switch (sheetName) {
      case 'branches':
      case 'sports':
        ttl = DataCache.CACHE_LONG; // 1 saat
        break;
      case 'groups':
      case 'users':
      case 'coaches':
      case 'group_students':
        ttl = DataCache.CACHE_MEDIUM; // 5 dakika
        break;
      case 'attendances':
      case 'payments':
        ttl = DataCache.CACHE_SHORT; // 1 dakika
        break;
      case 'notifications':
        ttl = DataCache.CACHE_VERY_SHORT; // 30 saniye
        break;
      default:
        ttl = DataCache.CACHE_MEDIUM;
    }

    if (ttlSeconds != null) ttl = ttlSeconds;

    return _cache.getOrFetch(
      'table_$sheetName',
      () => fetchTable(sheetName),
      ttlSeconds: ttl,
      forceRefresh: forceRefresh,
    );
  }

  // =========================================================================
  // ✅ TEMEL OKUMA FONKSİYONU (GET) - ORJİNAL (DEĞİŞMEDİ)
  // =========================================================================
  static Future<List<dynamic>> fetchTable(String sheetName) async {
    try {
      final response = await http.get(Uri.parse("$_baseUrl?sheet=$sheetName"));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded is Map && decoded.containsKey('success')) {
          if (decoded['success'] == true && decoded['data'] is List) {
            return decoded['data'] as List<dynamic>;
          } else {
            // print("fetchTable - API Hatası: ${decoded['error']}");
            return [];
          }
        } else if (decoded is List) {
          return decoded;
        }
      }
      return [];
    } catch (e) {
      // print("fetchTable - Bağlantı Hatası: $e");
      return [];
    }
  }

  // =========================================================================
  // ✅ CACHE YÖNETİM METODLARI
  // =========================================================================

  static void invalidateCache(String tableName) {
    _cache.invalidateTable(tableName);
  }

  static void invalidateAllCache() {
    _cache.invalidateAll();
  }

  static void invalidateExpiredCache() {
    _cache.invalidateExpired();
  }

  // =========================================================================
  // ✅ CACHE'Lİ GET METODLARI (KULLANILACAK OLANLAR)
  // =========================================================================

  static Future<List<Users>> getUsersCached({bool forceRefresh = false}) async {
    final rawData = await fetchTableCached('users', forceRefresh: forceRefresh);
    return rawData.map((item) => Users.fromJson(item)).toList();
  }

  static Future<List<Group>> getGroupsCached({
    bool forceRefresh = false,
  }) async {
    final rawData = await fetchTableCached(
      'groups',
      forceRefresh: forceRefresh,
    );
    return rawData.map((item) => Group.fromJson(item)).toList();
  }

  static Future<List<GroupStudent>> getGroupStudentsCached({
    bool forceRefresh = false,
  }) async {
    final rawData = await fetchTableCached(
      'group_students',
      forceRefresh: forceRefresh,
    );
    return rawData.map((item) => GroupStudent.fromJson(item)).toList();
  }

  static Future<List<Payment>> getPaymentsCached({
    bool forceRefresh = false,
  }) async {
    final rawData = await fetchTableCached(
      'payments',
      forceRefresh: forceRefresh,
    );
    return rawData.map((item) => Payment.fromJson(item)).toList();
  }

  static Future<List<Attendance>> getAttendancesCached({
    bool forceRefresh = false,
  }) async {
    final rawData = await fetchTableCached(
      'attendances',
      forceRefresh: forceRefresh,
    );
    return rawData.map((item) => Attendance.fromJson(item)).toList();
  }

  static Future<List<Branches>> getBranchesCached({
    bool forceRefresh = false,
  }) async {
    final rawData = await fetchTableCached(
      'branches',
      forceRefresh: forceRefresh,
    );
    return rawData.map((item) => Branches.fromJson(item)).toList();
  }

  static Future<List<Sports>> getSportsCached({
    bool forceRefresh = false,
  }) async {
    final rawData = await fetchTableCached(
      'sports',
      forceRefresh: forceRefresh,
    );
    return rawData.map((item) => Sports.fromJson(item)).toList();
  }

  static Future<List<Coach>> getCoachesCached({
    bool forceRefresh = false,
  }) async {
    final rawData = await fetchTableCached(
      'coaches',
      forceRefresh: forceRefresh,
    );
    return rawData.map((item) => Coach.fromJson(item)).toList();
  }

  static Future<List<Users>> getStudentsOnlyCached({
    bool forceRefresh = false,
  }) async {
    final allUsers = await getUsersCached(forceRefresh: forceRefresh);
    return allUsers.where((u) => u.role.toLowerCase() == 'student').toList();
  }

  static Future<List<Users>> getCoachesOnlyCached({
    bool forceRefresh = false,
  }) async {
    final allUsers = await getUsersCached(forceRefresh: forceRefresh);
    return allUsers.where((u) => u.role.toLowerCase() == 'coach').toList();
  }

  static Future<List<Users>> getParentsOnlyCached({
    bool forceRefresh = false,
  }) async {
    final allUsers = await getUsersCached(forceRefresh: forceRefresh);
    return allUsers.where((u) => u.role.toLowerCase() == 'parent').toList();
  }

  // =========================================================================
  // ✅ ORİJİNAL GET METODLARI (GERİYE DÖNÜK UYUMLULUK İÇİN)
  // Bunlar cache KULLANMAZ, doğrudan API'ye gider
  // =========================================================================

  static Future<List<Users>> getUsers() async {
    final rawData = await fetchTable("users");
    return rawData.map((item) => Users.fromJson(item)).toList();
  }

  static Future<List<Group>> getGroups() async {
    final rawData = await fetchTable("groups");
    return rawData.map((item) => Group.fromJson(item)).toList();
  }

  static Future<List<GroupStudent>> getGroupStudents() async {
    final rawData = await fetchTable("group_students");
    return rawData.map((item) => GroupStudent.fromJson(item)).toList();
  }

  static Future<List<Payment>> getPayments() async {
    final rawData = await fetchTable("payments");
    return rawData.map((item) => Payment.fromJson(item)).toList();
  }

  static Future<List<Attendance>> getAttendances() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?sheet=attendances'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);

        if (decoded['success'] == true) {
          final List<dynamic> data = decoded['data'];
          final List<Attendance> attendances = data.map((item) {
            String statusValue = item['status']?.toString() ?? "FALSE";
            bool isTrue = statusValue.toUpperCase() == "TRUE";

            return Attendance(
              attendances_id: item['attendances_id']?.toString() ?? '',
              groups_id: item['groups_id']?.toString() ?? '',
              student_id: item['student_id']?.toString() ?? '',
              taken_by: item['taken_by']?.toString() ?? '',
              attendance_date: item['attendance_date']?.toString() ?? '',
              status: isTrue ? "TRUE" : "FALSE",
              note: item['note']?.toString() ?? '',
            );
          }).toList();

          return attendances;
        }
      }
      return [];
    } catch (e) {
      // print("❌ getAttendances hatası: $e");
      return [];
    }
  }

  static Future<List<Branches>> getBranches() async {
    final rawData = await fetchTable("branches");
    return rawData.map((item) => Branches.fromJson(item)).toList();
  }

  static Future<List<Sports>> getSports() async {
    final rawData = await fetchTable("sports");
    return rawData.map((item) => Sports.fromJson(item)).toList();
  }

  static Future<List<Coach>> getCoaches() async {
    final rawData = await fetchTable("coaches");

    final coaches = <Coach>[];
    for (var item in rawData) {
      final Map<String, dynamic> cleanItem = {};
      item.forEach((key, value) {
        String cleanKey = key.toString().trim();
        cleanItem[cleanKey] = value;
      });

      final coach = Coach.fromJson(cleanItem);
      if (coach.coach_id.isNotEmpty) {
        coaches.add(coach);
      }
    }

    return coaches;
  }

  static Future<List<Users>> getStudents() async {
    final rawData = await fetchTable("users");
    return rawData.map((item) => Users.fromJson(item)).toList();
  }

  static Future<List<Users>> getStudentsForCoach(String coachBranchId) async {
    final allStudents = await getStudents();
    return allStudents.where((s) => s.branches_id == coachBranchId).toList();
  }

  static Future<List<Users>> getStudentsOnly() async {
    final allUsers = await getUsers();
    return allUsers.where((u) => u.role.toLowerCase() == 'student').toList();
  }

  static Future<List<Users>> getParentsOnly() async {
    final allUsers = await getUsers();
    return allUsers.where((u) => u.role.toLowerCase() == 'parent').toList();
  }

  static Future<List<Users>> getCoachesOnly() async {
    final allUsers = await getUsers();
    return allUsers.where((u) => u.role.toLowerCase() == 'coach').toList();
  }

  // =========================================================================
  // ✅ BİLDİRİM İŞLEMLERİ
  // =========================================================================

  static Future<List<Notifications>> getNotifications({required userId}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?sheet=notifications'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);

        if (decoded['success'] == true) {
          final List<dynamic> data = decoded['data'];
          final List<Notifications> notifications = data.map((item) {
            return Notifications(
              notifications_id: item['notifications_id']?.toString() ?? '',
              sender_id: item['sender_id']?.toString() ?? '',
              recipient_id: item['recipient_id']?.toString() ?? '',
              title: item['title']?.toString() ?? '',
              message: item['message']?.toString() ?? '',
              type: item['type']?.toString() ?? 'announcement',
              is_read: item['is_read']?.toString() ?? 'FALSE',
              sent_at: item['sent_at']?.toString() ?? '',
              groups_id: item['groups_id']?.toString() ?? '',
            );
          }).toList();

          return notifications;
        }
      }
      return [];
    } catch (e) {
      // print("❌ getNotifications hatası: $e");
      return [];
    }
  }

  /*
  static Future<List<Map<String, dynamic>>> getNotificationsForUser(
    String userId,
  ) async {
    try {
      // 🔥 FORCE REFRESH ile cache'i atla
      final rawData = await fetchTableCached(
        'notifications',
        forceRefresh: true,
      );
      if (rawData.isEmpty) return [];

      print("========== DUYURU FİLTRELEME ==========");
      print("👤 Kullanıcı ID: '$userId' (${userId.runtimeType})");

      // 🔥 KULLANICI BİLGİLERİ
      final allUsers = await getUsersCached(forceRefresh: true);
      final currentUser = allUsers.firstWhere(
        (u) => u.app.toString() == userId.toString(),
        orElse: () => Users(
          app: "",
          first_name: "",
          last_name: "",
          email: "",
          phone: "",
          password_hash: "",
          role: "",
          profile_photo_url: "",
          amount: "",
          b_date: "",
          created_at: "",
          last_login: "",
          is_active: "",
          branches_id: "",
        ),
      );

      print("👤 Kullanıcı Rolü: ${currentUser.role}");

      bool isAdmin =
          currentUser.role.toLowerCase() == 'admin' ||
          currentUser.role.toLowerCase() == 'yönetici';

      // 🔥 KULLANICININ GRUPLARI
      List<String> userGroups = [];

      if (currentUser.role.toLowerCase() == 'student' ||
          currentUser.role.toLowerCase() == 'öğrenci') {
        final groupRelations = await getGroupStudentsCached(forceRefresh: true);
        userGroups = groupRelations
            .where(
              (rel) =>
                  rel.student_id == userId &&
                  rel.is_active.toString().toUpperCase() == "TRUE",
            )
            .map((rel) => rel.groups_id.toString())
            .toList();
      } else if (currentUser.role.toLowerCase() == 'coach' ||
          currentUser.role.toLowerCase() == 'antrenör') {
        final coaches = await getCoachesCached(forceRefresh: true);
        final currentCoach = coaches.firstWhere(
          (c) => c.user_id == userId,
          orElse: () => Coach(
            coach_id: "",
            user_id: "",
            branches_id: "",
            sports_id: "",
            bio: "",
            certificate_info: "",
            monthly_salary: "",
            hired_at: "",
          ),
        );
        if (currentCoach.coach_id.isNotEmpty) {
          final groups = await getGroupsByCoachCached(
            currentCoach.coach_id,
            forceRefresh: true,
          );
          userGroups = groups.map((g) => g.groups_id.toString()).toList();
        }
      }

      print("📚 Kullanıcı grupları: $userGroups");

      List<Map<String, dynamic>> notifications = [];

      for (var item in rawData) {
        Map<String, dynamic> notif = Map<String, dynamic>.from(item);
        String recipientId = notif['recipient_id']?.toString() ?? '';
        String groupsId = notif['groups_id']?.toString() ?? '';
        String title = notif['title']?.toString() ?? '';

        bool shouldAdd = false;
        String reason = "";

        // 🔥 KRİTİK: recipient_id ve userId'i AYNI TİPE çevir
        String userIdStr = userId.toString();
        String recipientIdStr = recipientId.toString();

        print(
          "🔍 Kontrol: userId='$userIdStr' vs recipientId='$recipientIdStr'",
        );

        // 1. Herkese açık
        if (recipientIdStr == 'all' || recipientIdStr == 'Tümü') {
          shouldAdd = true;
          reason = "Herkese açık";
        }
        // 2. Admin
        else if (isAdmin) {
          shouldAdd = true;
          reason = "Admin yetkisi";
        }
        // 3. 🔥🔥🔥 DİREKT KULLANICIYA (EN ÖNEMLİ)
        else if (recipientIdStr == userIdStr) {
          shouldAdd = true;
          reason = "✅ DİREKT KULLANICIYA GÖNDERİLMİŞ!";
        }
        // 4. Gruba
        else if (userGroups.contains(recipientIdStr)) {
          shouldAdd = true;
          reason = "Gruba özel";
        }
        // 5. groups_id ile
        else if (groupsId.isNotEmpty && userGroups.contains(groupsId)) {
          shouldAdd = true;
          reason = "Gruba özel (groups_id)";
        }

        print("Duyuru: $title -> recipient_id: '$recipientIdStr'");

        if (shouldAdd) {
          print("  ✅ $reason");
          notifications.add(notif);
        } else {
          print("  ❌ Eşleşmedi");
        }
      }

      notifications.sort((a, b) {
        DateTime dateA = _parseDateTime(a['sent_at']?.toString() ?? '');
        DateTime dateB = _parseDateTime(b['sent_at']?.toString() ?? '');
        return dateB.compareTo(dateA);
      });

      print("📊 Filtrelenmiş duyuru sayısı: ${notifications.length}");
      return notifications;
    } catch (e) {
      print("Bildirimler alınamadı: $e");
      return [];
    }
  }
*/
  static Future<List<Map<String, dynamic>>> getNotificationsForUser(
    String userId,
  ) async {
    try {
      final rawData = await fetchTableCached(
        'notifications',
        forceRefresh: true,
      );
      if (rawData.isEmpty) return [];

      print("========== GET NOTIFICATIONS (BASİT) ==========");
      print("Kullanıcı ID: '$userId'");

      final String userIdStr = userId.toString().trim();

      List<Map<String, dynamic>> notifications = [];

      for (var item in rawData) {
        String recipientId = item['recipient_id']?.toString().trim() ?? '';
        String title = item['title']?.toString() ?? '';

        // 🔥 SADECE İKİ KURAL
        if (recipientId == 'all' || recipientId == userIdStr) {
          print("✅ EKLENDI: $title (recipient_id: $recipientId)");
          notifications.add(Map<String, dynamic>.from(item));
        } else {
          print(
            "❌ EKLENMEDI: $title (recipient_id: $recipientId != $userIdStr)",
          );
        }
      }

      notifications.sort((a, b) {
        DateTime dateA = _parseDateTime(a['sent_at']?.toString() ?? '');
        DateTime dateB = _parseDateTime(b['sent_at']?.toString() ?? '');
        return dateB.compareTo(dateA);
      });

      print("📊 Filtrelenmiş duyuru sayısı: ${notifications.length}");
      return notifications;
    } catch (e) {
      print("Bildirimler alınamadı: $e");
      return [];
    }
  }

  static Future<void> markNotificationAsRead(
    String notificationId,
    String userId,
  ) async {
    try {
      print("📢 Bildirim okunuyor - ID: $notificationId");

      final response = await _postRequest({
        "action": "updateNotification",
        "notifications_id": notificationId,
        "is_read": "TRUE",
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          print("✅ Bildirim okundu olarak işaretlendi: $notificationId");
          invalidateCache('notifications');
        } else {
          print("❌ Bildirim güncellenemedi: ${decoded['error']}");
        }
      } else {
        print("❌ HTTP Hatası: ${response?.statusCode}");
      }
    } catch (e) {
      print("Okundu işaretlenemedi: $e");
    }
  }

  static Future<int> getUnreadNotificationCount(String userId) async {
    final notifications = await getNotificationsForUser(userId);
    final unreadCount = notifications.where((n) {
      String isRead = n['is_read']?.toString().toUpperCase() ?? '';
      return isRead != 'TRUE';
    }).length;

    print("📊 Okunmamış bildirim sayısı: $unreadCount");
    return unreadCount;
  }

  /*
  static Future<bool> addNotification(
    Map<String, dynamic> notificationData,
  ) async {
    // print("📢 addNotification çağrıldı");
    // print("   title: ${notificationData['title']}");
    // print("   recipient_id: ${notificationData['recipient_id']}");

    final response = await _postRequest({
      "action": "insert",
      "table": "notifications",
      "data": notificationData,
    });

    if (response != null && response.statusCode == 200) {
      try {
        final decoded = jsonDecode(response.body);
        final success = decoded['success'] == true;
        if (success) {
          // print("✅ Bildirim başarıyla eklendi");
          invalidateCache('notifications');
        } else {
          //  print("❌ Bildirim eklenemedi: ${decoded['error']}");
        }
        return success;
      } catch (e) {
        // print("❌ JSON parse hatası: $e");
        return false;
      }
    }
    return false;
  }
*/
  static Future<bool> addNotification(
    Map<String, dynamic> notificationData,
  ) async {
    print("📢 addNotification çağrıldı");
    print("   title: ${notificationData['title']}");
    print("   recipient_id: ${notificationData['recipient_id']}");
    print("   groups_id: ${notificationData['groups_id']}");

    // 🔥 groups_id'yi STRING olarak kaydet
    if (notificationData['groups_id'] != null) {
      notificationData['groups_id'] = notificationData['groups_id'].toString();
    }

    final response = await _postRequest({
      "action": "insert",
      "table": "notifications",
      "data": notificationData,
    });

    if (response != null && response.statusCode == 200) {
      try {
        final decoded = jsonDecode(response.body);
        final success = decoded['success'] == true;
        if (success) {
          print("✅ Bildirim başarıyla eklendi");
          invalidateCache('notifications');
        } else {
          print("❌ Bildirim eklenemedi: ${decoded['error']}");
        }
        return success;
      } catch (e) {
        print("❌ JSON parse hatası: $e");
        return false;
      }
    }
    return false;
  }

  static DateTime _parseDateTime(String dateTimeStr) {
    try {
      if (dateTimeStr.contains('T')) {
        return DateTime.parse(dateTimeStr);
      } else if (dateTimeStr.contains(' ')) {
        return DateTime.parse(dateTimeStr.replaceAll(' ', 'T'));
      }
      return DateTime(2000);
    } catch (e) {
      return DateTime(2000);
    }
  }

  // =========================================================================
  // ✅ SMS İLE KOD GÖNDERME
  // =========================================================================

  static Future<bool> send2FACode(String phoneNumber, String code) async {
    try {
      final response = await _postRequest({
        "action": "send2FACode",
        "phone": phoneNumber,
        "code": code,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      // print("SMS gönderme hatası: $e");
      return false;
    }
  }
  /*
  static Future<void> updateLastLogin(String userId) async {
    try {
      final users = await getUsersCached();
      final user = users.firstWhere((u) => u.app == userId);

      final response = await _postRequest({
        "action": "insert",
        "table": "users",
        "data": {
          "app": user.app,
          "first_name": user.first_name,
          "last_name": user.last_name,
          "email": user.email,
          "phone": user.phone,
          "password_hash": user.password_hash,
          "role": user.role,
          "profile_photo_url": user.profile_photo_url,
          "branches_id": user.branches_id,
          "amount": user.amount,
          "b_date": user.b_date,
          "created_at": user.created_at,
          "last_login": DateTime.now().toIso8601String(),
          "is_active": user.is_active,
        },
      });

      if (response != null && response.statusCode == 200) {
        // print("✅ Son giriş güncellendi: $userId");
        invalidateCache('users');
      }
    } catch (e) {
      // print("Güncelleme hatası: $e");
    }
  }
*/
  // fetch_data_page.dart içindeki updateLastLogin fonksiyonunu BUNUNLA DEĞİŞTİR

  static Future<void> updateLastLogin(String userId) async {
    try {
      // 🔥 SADECE last_login sütununu güncelle
      final response = await _postRequest({
        "action": "updateLastLogin", // Yeni action
        "user_id": userId,
        "last_login": DateTime.now().toIso8601String(),
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          print("✅ Son giriş güncellendi: $userId");
          // users cache'ini temizle
          invalidateCache('users');
        } else {
          print("❌ Son giriş güncellenemedi: ${decoded['error']}");
        }
      } else {
        print("❌ HTTP Hatası: ${response?.statusCode}");
      }
    } catch (e) {
      print("Güncelleme hatası: $e");
    }
  }
  // =========================================================================
  // ✅ FOTOĞRAF YÜKLEME
  // =========================================================================

  // =========================================================================
  // ✅ KULLANICI İŞLEMLERİ (LOGIN, REGISTER, UPDATE)
  // =========================================================================

  static Future<Users?> login(String email, String password) async {
    print("========== LOGIN TEST ==========");
    print("Email: $email");
    print("Password: $password");

    final response = await _postRequest({
      "action": "login",
      "email": email,
      "password": password,
    });

    print("Response status: ${response?.statusCode}");
    print("Response body: ${response?.body}");

    if (response != null && response.statusCode == 200) {
      try {
        final decoded = json.decode(response.body);
        print("Decoded: $decoded");

        if (decoded['success'] == true) {
          Map<String, dynamic>? userMap;

          if (decoded['data'] != null && decoded['data']['user'] != null) {
            userMap = Map<String, dynamic>.from(decoded['data']['user']);
            print("✅ userMap data.user'dan alındı");
          } else if (decoded['user'] != null) {
            userMap = Map<String, dynamic>.from(decoded['user']);
            print("✅ userMap user'dan alındı");
          }

          if (userMap != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('logged_user', jsonEncode(userMap));

            print("✅ Login başarılı! Kullanıcı: ${userMap['email']}");
            return Users.fromJson(userMap);
          } else {
            print("❌ userMap oluşturulamadı");
          }
        } else {
          print("❌ Login başarısız: ${decoded['error']}");
        }
      } catch (e) {
        print("❌ JSON parse hatası: $e");
      }
    } else {
      print("❌ HTTP hatası: ${response?.statusCode}");
    }

    return null;
  }

  static Future<Users?> loginRequest(String email, String password) async {
    return await login(email, password);
  }

  static Future<bool> registerUser(Users newUser) async {
    final response = await _postRequest({
      "action": "insert",
      "table": "users",
      "data": newUser.toJson(),
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('users');
      }
      return success;
    }
    return false;
  }

  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    final response = await _postRequest({"action": "updateUser", "data": data});

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('users');
      }
      return success;
    }
    return false;
  }

  static Future<Users?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString('logged_user');

    if (userJson != null) {
      final Map<String, dynamic> userMap = json.decode(userJson);
      // print("✅ Kayıtlı kullanıcı bulundu: ${userMap['email']}");
      return Users.fromJson(userMap);
    }

    // print("❌ Kayıtlı kullanıcı yok");
    return null;
  }

  static Future<bool> deactivateUser(String userId) async {
    final response = await _postRequest({
      "action": "deactivateUser",
      "user_id": userId,
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('users');
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ BRANCH İŞLEMLERİ
  // =========================================================================

  static Future<Branches?> getBranchById(String branchId) async {
    final allBranches = await getBranchesCached();
    try {
      return allBranches.firstWhere((b) => b.branches_id == branchId);
    } catch (e) {
      return null;
    }
  }

  // =========================================================================
  // ✅ SPORTS İŞLEMLERİ
  // =========================================================================

  static Future<Sports?> getSportById(String sportId) async {
    final allSports = await getSportsCached();
    try {
      return allSports.firstWhere((s) => s.sports_id == sportId);
    } catch (e) {
      return null;
    }
  }

  // =========================================================================
  // ✅ GRUP İŞLEMLERİ (CACHE'Lİ VERSİYONLAR)
  // =========================================================================

  static Future<List<Group>> getGroupsByCoachCached(
    String coachId, {
    bool forceRefresh = false,
  }) async {
    final allGroups = await getGroupsCached(forceRefresh: forceRefresh);
    return allGroups.where((g) => g.coach_id == coachId).toList();
  }

  static Future<List<Group>> getGroupsByBranchCached(
    String branchId, {
    bool forceRefresh = false,
  }) async {
    final allGroups = await getGroupsCached(forceRefresh: forceRefresh);
    return allGroups.where((g) => g.branches_id == branchId).toList();
  }

  static Future<Group?> getGroupByIdCached(
    String groupId, {
    bool forceRefresh = false,
  }) async {
    final allGroups = await getGroupsCached(forceRefresh: forceRefresh);
    try {
      return allGroups.firstWhere((g) => g.groups_id == groupId);
    } catch (e) {
      return null;
    }
  }

  static Future<List<GroupStudent>> getGroupStudentsByGroupIdCached(
    String groupId, {
    bool forceRefresh = false,
  }) async {
    final all = await getGroupStudentsCached(forceRefresh: forceRefresh);
    return all.where((gs) => gs.groups_id == groupId).toList();
  }

  static Future<List<Group>> getGroupsByCoachIdCached(
    String coachId, {
    bool forceRefresh = false,
  }) async {
    final allGroups = await getGroupsCached(forceRefresh: forceRefresh);
    return allGroups.where((g) => g.coach_id == coachId).toList();
  }

  static Future<List<Group>> getGroupsByStudentIdCached(
    String studentId, {
    bool forceRefresh = false,
  }) async {
    final allGroupRelations = await getGroupStudentsCached(
      forceRefresh: forceRefresh,
    );
    final allGroups = await getGroupsCached(forceRefresh: forceRefresh);

    final studentGroupIds = allGroupRelations
        .where((rel) => rel.student_id == studentId && rel.is_active == "TRUE")
        .map((rel) => rel.groups_id)
        .toList();

    return allGroups
        .where((g) => studentGroupIds.contains(g.groups_id))
        .toList();
  }

  // =========================================================================
  // ✅ GRUP İŞLEMLERİ (ORİJİNAL - CACHE'SİZ)
  // =========================================================================

  static Future<List<Group>> getGroupsByCoach(String coachId) async {
    final allGroups = await getGroups();
    return allGroups.where((g) => g.coach_id == coachId).toList();
  }

  static Future<List<Group>> getGroupsByBranch(String branchId) async {
    final allGroups = await getGroups();
    return allGroups.where((g) => g.branches_id == branchId).toList();
  }

  static Future<Group?> getGroupById(String groupId) async {
    final allGroups = await getGroups();
    try {
      return allGroups.firstWhere((g) => g.groups_id == groupId);
    } catch (e) {
      return null;
    }
  }

  static Future<List<GroupStudent>> getGroupStudentsByGroupId(
    String groupId,
  ) async {
    final all = await getGroupStudents();
    return all.where((gs) => gs.groups_id == groupId).toList();
  }

  static Future<List<Group>> getGroupsByCoachId(String coachId) async {
    final allGroups = await getGroups();
    return allGroups.where((g) => g.coach_id == coachId).toList();
  }

  static Future<List<Group>> getGroupsByStudentId(String studentId) async {
    final allGroupRelations = await getGroupStudents();
    final allGroups = await getGroups();

    final studentGroupIds = allGroupRelations
        .where((rel) => rel.student_id == studentId && rel.is_active == "TRUE")
        .map((rel) => rel.groups_id)
        .toList();

    return allGroups
        .where((g) => studentGroupIds.contains(g.groups_id))
        .toList();
  }

  static Future<Users?> getStudentCoach(String studentId) async {
    final studentGroups = await getGroupsByStudentId(studentId);
    if (studentGroups.isEmpty) return null;

    final coachId = studentGroups.first.coach_id;
    final coaches = await getCoachesOnly();
    try {
      final coachUser = coaches.firstWhere((c) => c.app == coachId);
      return coachUser;
    } catch (e) {
      // print("Öğrencinin antrenörü bulunamadı: $e");
      return null;
    }
  }

  static Future<bool> updateGroup(
    String groupId,
    Map<String, dynamic> updateData,
  ) async {
    final response = await _postRequest({
      "action": "updateGroup",
      "group_id": groupId,
      "data": updateData,
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('groups');
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ GRUP-ÖĞRENCİ İLİŞKİLERİ (CACHE'Lİ)
  // =========================================================================

  static Future<List<GroupStudent>> getGroupStudentsByStudentIdCached(
    String studentId, {
    bool forceRefresh = false,
  }) async {
    final all = await getGroupStudentsCached(forceRefresh: forceRefresh);
    return all.where((gs) => gs.student_id == studentId).toList();
  }

  static Future<List<Group>> getActiveGroupsByStudentIdCached(
    String studentId, {
    bool forceRefresh = false,
  }) async {
    final allGroupRelations = await getGroupStudentsByStudentIdCached(
      studentId,
      forceRefresh: forceRefresh,
    );
    final activeGroupIds = allGroupRelations
        .where((rel) => rel.is_active == "TRUE")
        .map((rel) => rel.groups_id)
        .toList();

    final allGroups = await getGroupsCached(forceRefresh: forceRefresh);
    return allGroups
        .where((g) => activeGroupIds.contains(g.groups_id))
        .toList();
  }

  // =========================================================================
  // ✅ GRUP-ÖĞRENCİ İLİŞKİLERİ (ORİJİNAL)
  // =========================================================================

  static Future<List<GroupStudent>> getGroupStudentsByStudentId(
    String studentId,
  ) async {
    final all = await getGroupStudents();
    return all.where((gs) => gs.student_id == studentId).toList();
  }

  static Future<List<Group>> getActiveGroupsByStudentId(
    String studentId,
  ) async {
    final allGroupRelations = await getGroupStudentsByStudentId(studentId);
    final activeGroupIds = allGroupRelations
        .where((rel) => rel.is_active == "TRUE")
        .map((rel) => rel.groups_id)
        .toList();

    final allGroups = await getGroups();
    return allGroups
        .where((g) => activeGroupIds.contains(g.groups_id))
        .toList();
  }

  static Future<bool> assignStudentToGroup(
    String studentId,
    String groupId,
  ) async {
    final response = await _postRequest({
      "action": "assignStudentToGroup",
      "student_id": studentId,
      "group_id": groupId,
      "is_active": "TRUE",
    });

    if (response != null && response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateCache('group_students');
        invalidateCache('groups');
      }
      return success;
    }
    return false;
  }

  static Future<bool> removeStudentFromGroup(
    String studentId,
    String groupId,
  ) async {
    final response = await _postRequest({
      "action": "removeStudentFromGroup",
      "student_id": studentId,
      "group_id": groupId,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateCache('group_students');
        invalidateCache('groups');
      }
      return success;
    }
    return false;
  }

  static Future<bool> assignCoachToGroup(String groupId, String coachId) async {
    final response = await _postRequest({
      "action": "assignCoachToGroup",
      "group_id": groupId,
      "coach_id": coachId,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateCache('groups');
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ COACH İŞLEMLERİ
  // =========================================================================

  static Future<bool> registerCoach(Coach newCoach) async {
    final coaches = await getCoachesCached();

    int nextId = 1;
    if (coaches.isNotEmpty) {
      final ids = coaches.map((c) => int.tryParse(c.coach_id) ?? 0).toList();
      nextId = ids.reduce((curr, next) => curr > next ? curr : next) + 1;
    }

    final updatedCoachData = newCoach.toJson();
    updatedCoachData['coach_id'] = nextId.toString();

    final success = await insertData("coaches", updatedCoachData);
    if (success) {
      invalidateCache('coaches');
    }
    return success;
  }

  static Future<bool> registerCoachWithAutoId(Coach newCoach) async {
    return await registerCoach(newCoach);
  }

  static Future<bool> addCoachWithAutoId(Map<String, dynamic> coachData) async {
    final allCoaches = await getCoachesCached();

    int nextId = 1;
    if (allCoaches.isNotEmpty) {
      final ids = allCoaches.map((c) => int.tryParse(c.coach_id) ?? 0).toList();
      nextId = ids.reduce((curr, next) => curr > next ? curr : next) + 1;
    }

    coachData['coach_id'] = nextId.toString();
    final success = await insertData("coaches", coachData);
    if (success) {
      invalidateCache('coaches');
    }
    return success;
  }

  // =========================================================================
  // ✅ YOKLAMA İŞLEMLERİ
  // =========================================================================

  static Future<List<Attendance>> getAttendancesByStudent(
    String studentId,
  ) async {
    final all = await getAttendancesCached();
    return all.where((a) => a.student_id == studentId).toList();
  }

  static Future<bool> saveAttendance(Attendance attendance) async {
    print(
      "💾 saveAttendance: Öğrenci=${attendance.student_id}, Tarih=${attendance.attendance_date}, Durum=${attendance.status}",
    );

    final response = await _postRequest({
      "action": "saveAttendance",
      "sheet": "attendances",
      "data": attendance.toJson(),
    });

    if (response != null && response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateCache('attendances');
      }
      return success;
    }
    //  print("   ❌ Hata: ${response?.statusCode}");
    return false;
  }

  static Future<List<Attendance>> getAttendancesForGroup(String groupId) async {
    final all = await getAttendancesCached();
    return all.where((a) => a.groups_id == groupId).toList();
  }

  static Future<List<Attendance>> getTodayAttendance(String groupId) async {
    final allAttendances = await getAttendancesForGroup(groupId);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return allAttendances
        .where((a) => a.attendance_date.contains(today))
        .toList();
  }

  static Future<bool> saveBulkAttendance(List<Attendance> attendances) async {
    bool allSuccess = true;
    for (var att in attendances) {
      final success = await saveAttendance(att);
      if (!success) allSuccess = false;
    }
    return allSuccess;
  }

  // =========================================================================
  // ✅ ÖDEME İŞLEMLERİ
  // =========================================================================

  static Future<List<Payment>> getPaymentsByStudent(String studentId) async {
    final allPayments = await getPaymentsCached();
    return allPayments.where((p) => p.student_id == studentId).toList();
  }

  static Future<bool> addPayment(Payment payment) async {
    final response = await _postRequest({
      "action": "insert",
      "table": "payments",
      "data": payment.toJson(),
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('payments');
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ ÖĞRENCİ NOTLARI İŞLEMLERİ
  // =========================================================================

  static Future<List<StudentNote>> getStudentNotes() async {
    final rawData = await fetchTable("student_notes");
    return rawData.map((item) => StudentNote.fromJson(item)).toList();
  }

  static Future<List<StudentNote>> getStudentNotesByStudent(
    String studentId,
  ) async {
    final all = await getStudentNotes();
    return all.where((n) => n.student_id == studentId).toList();
  }

  static Future<bool> addStudentNote(StudentNote note) async {
    final response = await _postRequest({
      "action": "insert",
      "table": "student_notes",
      "data": note.toJson(),
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('student_notes');
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ VELİ-ÖĞRENCİ İLİŞKİLERİ
  // =========================================================================

  static Future<List<ParentStudent>> getParentStudents() async {
    final rawData = await fetchTable("parent_student");
    return rawData.map((item) => ParentStudent.fromJson(item)).toList();
  }

  static Future<List<ParentStudent>> getStudentsByParent(
    String parentId,
  ) async {
    final all = await getParentStudents();
    return all.where((ps) => ps.parent_id == parentId).toList();
  }

  static Future<List<ParentStudent>> getParentsByStudent(
    String studentId,
  ) async {
    final all = await getParentStudents();
    return all.where((ps) => ps.student_id == studentId).toList();
  }

  static Future<bool> addParentStudent(
    String parentId,
    String studentId,
  ) async {
    final success = await insertData("parent_student", {
      "parent_id": parentId,
      "student_id": studentId,
    });
    if (success) {
      invalidateCache('parent_student');
    }
    return success;
  }

  // =========================================================================
  // ✅ GENEL VERİ EKLEME (CACHE'Lİ)
  // =========================================================================

  static Future<bool> insertData(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    final response = await _postRequest({
      "action": "insert",
      "table": tableName,
      "data": data,
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache(tableName);
      }
      return success;
    }
    return false;
  }

  // =========================================================================
  // ✅ MASTER KAYIT
  // =========================================================================

  static Future<bool> registerEverywhere(Map<String, dynamic> allInfo) async {
    print("========== REGISTER EVERYWHERE ==========");
    print("Gelen allInfo: ${jsonEncode(allInfo)}");

    final response = await _postRequest({
      "action": "registerEverywhere",
      "data": allInfo,
    });

    print("Response status: ${response?.statusCode}");
    if (response != null) {
      print("Response body: ${response.body}");
    }

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      print("Decoded: $decoded");
      final success = decoded['success'] == true;
      if (success) {
        invalidateAllCache();
      }
      return success;
    }
    print("❌ registerEverywhere BAŞARISIZ!");
    return false;
  }

  // =========================================================================
  // ✅ ÖDEME BİLDİRİMİ GÖNDER (KİŞİYE ÖZEL)
  // =========================================================================

  static Future<bool> sendPaymentReminderToStudent(
    String studentId,
    String studentName,
    double amount,
    String dueDate,
  ) async {
    final notifData = {
      "notifications_id": "NTF-${DateTime.now().millisecondsSinceEpoch}",
      "sender_id": "Admin",
      "recipient_id": studentId,
      "groups_id": "",
      "title": "💰 Ödeme Hatırlatması",
      "message":
          "Sayın $studentName, $dueDate tarihinde sona eren $amount TL aidat ödemeniz bulunmaktadır. Lütfen en kısa sürede ödemenizi gerçekleştiriniz.",
      "type": "payment_reminder",
      "is_read": "FALSE",
      "sent_at": DateTime.now().toIso8601String(),
    };

    return await addNotification(notifData);
  }

  static Future<int> sendPaymentRemindersToAllLateStudents() async {
    try {
      final allPayments = await getPaymentsCached();
      final allStudents = await getStudentsOnlyCached();
      final today = DateTime.now();

      final latePayments = allPayments.where((p) {
        final dueDate = DateTime.tryParse(p.due_date);
        final isLate = dueDate != null && dueDate.isBefore(today);
        final isNotPaid = p.status?.toLowerCase() != 'paid';
        return isLate && isNotPaid;
      }).toList();

      int sentCount = 0;

      for (var payment in latePayments) {
        final student = allStudents.firstWhere(
          (s) => s.app.toString() == payment.student_id,
          orElse: () => Users(
            app: "",
            branches_id: "",
            first_name: "Öğrenci",
            last_name: "",
            email: "",
            phone: "",
            password_hash: "",
            role: "",
            profile_photo_url: "",
            amount: "",
            b_date: "",
            created_at: "",
            last_login: "",
            is_active: "",
          ),
        );

        final success = await sendPaymentReminderToStudent(
          payment.student_id,
          "${student.first_name} ${student.last_name}",
          double.tryParse(payment.amount) ?? 0,
          payment.due_date,
        );

        if (success) sentCount++;
      }

      print("✅ Ödeme bildirimi gönderildi: $sentCount öğrenciye");
      return sentCount;
    } catch (e) {
      print("❌ Ödeme bildirimi gönderilemedi: $e");
      return 0;
    }
  }

  static Future<bool> sendAnnouncementToStudent(
    String studentId,
    String title,
    String message,
  ) async {
    final notifData = {
      "notifications_id": "NTF-${DateTime.now().millisecondsSinceEpoch}",
      "sender_id": "Admin",
      "recipient_id": studentId,
      "groups_id": "",
      "title": title,
      "message": message,
      "type": "announcement",
      "is_read": "FALSE",
      "sent_at": DateTime.now().toIso8601String(),
    };

    return await addNotification(notifData);
  }

  // =========================================================================
  // ✅ YARDIMCI METODLAR
  // =========================================================================

  Future<String> loadJsonAsset(String fileName) async {
    return await rootBundle.loadString('assets/data/$fileName.json');
  }
  // fetch_data_page.dart içine ekle (getUsersCached'in yanına)

  // fetch_data_page.dart içine ekle (getUsersCached'in yanına)

  static Future<Users?> getUserById(String userId) async {
    final allUsers = await getUsersCached();
    try {
      return allUsers.firstWhere((u) => u.app == userId);
    } catch (e) {
      return null;
    }
  }

  // 🔥 Kullanıcının FCM token'ını kaydet (e-tabloya)
  static Future<bool> saveUserToken(String userId, String token) async {
    try {
      final response = await _postRequest({
        "action": "saveUserToken",
        "user_id": userId,
        "fcm_token": token,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      print("Token kaydedilemedi: $e");
      return false;
    }
  }

  // 🔥 Kullanıcının token'ını al (e-tablodan)
  static Future<String?> getUserToken(String userId) async {
    try {
      final response = await _postRequest({
        "action": "getUserToken",
        "user_id": userId,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['token'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 🔥 Grubun tüm kullanıcılarının token'larını al
  static Future<List<String>> getGroupUserTokens(String groupId) async {
    try {
      final response = await _postRequest({
        "action": "getGroupUserTokens",
        "group_id": groupId,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return List<String>.from(decoded['tokens'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 🔥 PUSH NOTIFICATION GÖNDER
  static Future<bool> sendPushNotification(
    String title,
    String body,
    List<String> tokens, {
    Map<String, dynamic>? data,
  }) async {
    if (tokens.isEmpty) return false;

    try {
      final response = await _postRequest({
        "action": "sendPushNotifications",
        "tokens": tokens,
        "title": title,
        "body": body,
        "data": data ?? {},
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      print("Push notification gönderilemedi: $e");
      return false;
    }
  }
  // GoogleSheetService.dart'a ekle

  static Future<List<dynamic>> getDataWithOffline({
    required String sheetName,
    required String idField,
  }) async {
    final offlineData = await LocalDatabaseService().getAll(sheetName);

    if (offlineData.isNotEmpty) {
      return offlineData;
    }

    final freshData = await fetchTable(sheetName);
    for (var item in freshData) {
      final id =
          item[idField]?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      await LocalDatabaseService().insertOrUpdate(sheetName, id, item);
    }

    return freshData;
  }

  static Future<bool> saveDataWithOffline({
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    // Önce local'e kaydet
    final tempId =
        data['${tableName}_id'] ??
        DateTime.now().millisecondsSinceEpoch.toString();
    await LocalDatabaseService().insertOrUpdate(tableName, tempId, data);

    // Pending queue'ye ekle (arka planda senkronize edilecek)
    await LocalDatabaseService().addPendingOperation(
      operation: 'insert',
      tableName: tableName,
      data: data,
    );

    return true;
  }
  // GoogleSheetService.dart içine ekle

  static Future<bool> updateData(
    String tableName,
    Map<String, dynamic> data,
    Map<String, String?> updateData,
  ) async {
    final response = await _postRequest({
      "action": "update",
      "table": tableName,
      "data": data,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['success'] == true;
    }
    return false;
  }

  static Future<bool> deleteData(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    final response = await _postRequest({
      "action": "delete",
      "table": tableName,
      "data": data,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['success'] == true;
    }
    return false;
  }

  // GoogleSheetService.dart
  static Future<bool> updatePassword(
    String userId,
    String hashedPassword,
  ) async {
    final response = await _postRequest({
      "action": "updatePassword",
      "user_id": userId,
      "password_hash": hashedPassword,
    });

    if (response != null && response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final success = decoded['success'] == true;
      if (success) {
        invalidateCache('users');
      }
      return success;
    }
    return false;
  }

  /*
  static Future<String?> uploadImageToDrive(
    File imageFile,
    String fileName,
    String folderName,
  ) async {
    try {
      print("📸 Yükleniyor: $fileName -> $folderName");
      print("📸 Dosya boyutu: ${await imageFile.length()} bytes");

      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      print("📸 Base64 uzunluğu: ${base64Image.length}");

      final response = await _postRequest({
        "action": "uploadImage",
        "file_name": fileName,
        "file_data": base64Image,
        "folder": folderName,
      });

      print("📸 HTTP Status: ${response?.statusCode}");

      if (response != null) {
        print("📸 Response body: ${response.body}");
      }

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print("📸 Decoded: $decoded");

        if (decoded['success'] == true) {
          print("✅ Fotoğraf yüklendi: $fileName");
          return fileName;
        } else {
          print("❌ API hatası: ${decoded['error']}");
        }
      } else {
        print("❌ HTTP hatası: ${response?.statusCode}");
      }
      return null;
    } catch (e) {
      print("❌ Fotoğraf yükleme hatası: $e");
      return null;
    }
  }*/
  static Future<String?> uploadImageToDrive(
    File imageFile,
    String fileName,
    String folderName, {
    String? targetUserId, // YENİ: Hangi kullanıcıya ait
    String?
    targetField, // YENİ: Hangi alana yazılacak (örn: "profile_photo_url")
  }) async {
    try {
      print("📸 Yükleniyor: $fileName -> $folderName");

      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // 🔥 YENİ parametreleri ekle
      final requestBody = {
        "action": "uploadImage",
        "file_name": fileName,
        "file_data": base64Image,
        "folder": folderName,
      };

      // Hedef bilgisi varsa ekle
      if (targetUserId != null && targetField != null) {
        requestBody["targetUserId"] = targetUserId;
        requestBody["targetField"] = targetField;
      }

      final response = await _postRequest(requestBody);

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          print("✅ Fotoğraf yüklendi: $fileName");
          print("   URL: ${decoded['data']['url']}");

          // Kullanıcı cache'ini temizle (yeni fotoğraf görünsün)
          invalidateCache('users');

          return decoded['data']['url']; // URL'yi döndür
        } else {
          print("❌ API hatası: ${decoded['error']}");
        }
      }
      return null;
    } catch (e) {
      print("❌ Fotoğraf yükleme hatası: $e");
      return null;
    }
  }

  // Fotoğraf URL'ini al (dosya adı ile)
  static Future<String?> getImageUrlFromDrive(
    String fileName,
    String folderName,
  ) async {
    if (fileName.isEmpty) return null;

    try {
      final response = await _postRequest({
        "action": "getImageUrl",
        "file_name": fileName,
        "folder": folderName,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          return decoded['data']['url'];
        }
      }
      return null;
    } catch (e) {
      print("Resim URL alma hatası: $e");
      return null;
    }
  }

  static Future<bool> updateUser(Map<String, dynamic> userData) async {
    final response = await _postRequest({
      "action": "updateUser",
      "data": userData,
    });

    if (response != null && response.statusCode == 200) {
      final success = jsonDecode(response.body)['success'] == true;
      if (success) {
        invalidateCache('users');
      }
      return success;
    }
    return false;
  }

  // GoogleSheetService sınıfına EKLE
  static Future<bool> updateGroupStatus(
    String groupId,
    String newStatus,
  ) async {
    try {
      final response = await _postRequest({
        "action": "updateGroupStatus",
        "group_id": groupId,
        "is_active": newStatus,
      });

      if (response != null && response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final success = decoded['success'] == true;
        if (success) {
          invalidateCache('groups');
          print("✅ Grup durumu güncellendi: $groupId -> $newStatus");
        } else {
          print("❌ Grup durumu güncellenemedi: ${decoded['error']}");
        }
        return success;
      }
      return false;
    } catch (e) {
      print("❌ updateGroupStatus hatası: $e");
      return false;
    }
  }
}
