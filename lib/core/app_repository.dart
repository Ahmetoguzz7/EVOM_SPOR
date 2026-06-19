import 'dart:async';
import 'package:EVOM_SPOR/local/background_sync_service.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';
import 'package:flutter/widgets.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

/// 🔥 UYGULAMANIN HAFIZA ODASI (RAM)
/// Tüm veriler burada tutulur. Sayfalar asla internete doğrudan gitmez.
class AppRepository {
  static final AppRepository _instance = AppRepository._internal();
  factory AppRepository() => _instance;
  AppRepository._internal();

  // ============================================================
  // 🧠 RAM'DE TUTULAN VERİLER
  // ============================================================
  List<Users> allUsers = [];
  List<Group> allGroups = [];
  List<GroupStudent> allGroupStudents = [];
  List<Payment> allPayments = [];
  List<Attendance> allAttendances = [];
  List<Branches> allBranches = [];
  List<Sports> allSports = [];
  List<Coach> allCoaches = [];
  List<Notifications> allNotifications = [];

  // İlişkisel haritalar (performans için)
  late Map<String, List<GroupStudent>> _groupStudentsByGroupId;
  late Map<String, List<GroupStudent>> _groupStudentsByStudentId;
  late Map<String, List<Payment>> _paymentsByStudentId;
  late Map<String, List<Attendance>> _attendancesByStudentId;
  late Map<String, List<Attendance>> _attendancesByGroupId;
  late Map<String, Users> _usersById;
  late Map<String, Group> _groupsById;
  late Map<String, Branches> _branchesById;
  late Map<String, Sports> _sportsById;
  late Map<String, Notifications> _notificationsById;

  bool get isLoaded => _isLoaded;
  bool _isLoaded = false;

  // 🔥 YENİ: Lokal cache'den mi geldi?
  bool get isFromCache => _isFromCache;
  bool _isFromCache = false;

  // Arka plan yükleme durumu
  bool _isBackgroundLoading = false;
  final List<VoidCallback> _onPhotoLoadCallbacks = [];

  // 🔥 Veri güncelleme stream'i
  final StreamController<bool> _dataUpdateController =
      StreamController<bool>.broadcast();
  Stream<bool> get onDataUpdated => _dataUpdateController.stream;

  // 🔥 YENİ: LocalStorage ve BackgroundSync servisleri
  late final LocalStorageService _localStorage;
  late final BackgroundSyncService _syncService;

  // 🔥 YENİ: Retry mekanizması
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // ============================================================
  // 🚀 BAŞLATMA (YENİ)
  // ============================================================
  // 🔥 Mükerrer init çağrılarını engellemek için bayrak ekle
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) {
      print("⚠️ AppRepository zaten başlatılmış. Init adımları atlanıyor.");
      return;
    }
    _localStorage = LocalStorageService();
    _syncService = BackgroundSyncService();
    await _localStorage.init();
    _initializeEmptyMaps();
    await _loadFromLocalCache();

    _syncService.setOnDataUpdatedCallback((
      users,
      groups,
      groupStudents,
      payments,
      attendances,
      coaches,
      notifications,
    ) async {
      allUsers = users;
      allGroups = groups;
      allGroupStudents = groupStudents;
      allPayments = payments;
      allAttendances = attendances;
      allCoaches = coaches;
      allNotifications = notifications;

      _buildMaps();

      if (!_dataUpdateController.isClosed) {
        _dataUpdateController.add(true);
      }

      print("✅ Arka plan sync ile RAM güncellendi!");
    });

    _syncService.startPeriodicSync();
    _isInitialized = true; // Başlatıldı olarak işaretle kanka
    print("✅ AppRepository başarıyla başlatıldı (Hive + Sync aktif)");
  }

  // ✅ YENİ METOD
  void _initializeEmptyMaps() {
    _groupStudentsByGroupId = {};
    _groupStudentsByStudentId = {};
    _paymentsByStudentId = {};
    _attendancesByStudentId = {};
    _attendancesByGroupId = {};
    _usersById = {};
    _groupsById = {};
    _branchesById = {};
    _sportsById = {};
    _notificationsById = {};
  }

  // ============================================================
  // 🔥 YENİ: Retry ile veri çekme
  // ============================================================
  Future<List<T>> _fetchWithRetry<T>(
    Future<List<T>> Function() fetchFunction,
    String dataName,
  ) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        print("📥 $dataName çekiliyor (deneme $attempt/$_maxRetries)...");
        final data = await fetchFunction().timeout(const Duration(seconds: 15));
        if (data.isNotEmpty) {
          print("✅ $dataName başarıyla çekildi: ${data.length} kayıt");
          return data;
        } else {
          print("⚠️ $dataName boş geldi, tekrar deneniyor...");
        }
      } catch (e) {
        print("❌ $dataName hatası (deneme $attempt): $e");
      }

      if (attempt < _maxRetries) {
        await Future.delayed(_retryDelay);
      }
    }

    print("❌ $dataName $_maxRetries denemeden sonra yüklenemedi!");
    return [];
  }

  // ============================================================
  // 🔥 YENİ: Lokal cache'e kaydet
  // ============================================================
  Future<void> _saveToLocalCache() async {
    try {
      await _localStorage.saveAllData(
        users: allUsers,
        groups: allGroups,
        groupStudents: allGroupStudents,
        payments: allPayments,
        attendances: allAttendances,
        coaches: allCoaches,
        notifications: allNotifications,
      );
      print("💾 Veriler lokal cache'e kaydedildi");
    } catch (e) {
      print("⚠️ Lokal cache kaydetme hatası: $e");
    }
  }

  // 🔥 YENİ: Lokal cache'den yükle
  Future<bool> _loadFromLocalCache() async {
    try {
      if (_localStorage.hasCachedData()) {
        allUsers = _localStorage.getUsers();
        allGroups = _localStorage.getGroups();
        allGroupStudents = _localStorage.getGroupStudents();
        allPayments = _localStorage.getPayments();
        allAttendances = _localStorage.getAttendances();
        allCoaches = _localStorage.getCoaches();
        allNotifications = _localStorage.getNotifications();

        allBranches = [];
        allSports = [];

        _buildMaps();
        print(
          "✅ Lokal cache'den yüklendi: ${allUsers.length} kullanıcı, ${allGroups.length} grup",
        );
        return true;
      } else {
        print("⚠️ Lokal cache boş, veri yok");
        _initializeEmptyData();
        _buildMaps();
        _isLoaded = true;
        return false;
      }
    } catch (e) {
      print("❌ Lokal cache okuma hatası: $e");
      _initializeEmptyData();
      _buildMaps();
      _isLoaded = true;
      return false;
    }
  }

  // ============================================================
  // 🚀 KRİTİK VERİLERİ YÜKLE (Hive destekli - DEĞİŞTİ)
  // ============================================================
  Future<void> loadCriticalData({
    Function(double progress)? onProgress,
    Function(String message)? onMessage,
  }) async {
    if (_isLoaded) {
      onProgress?.call(1.0);
      return;
    }

    try {
      // 🔥 1. Önce Hive cache'den dene (çok hızlı)
      onMessage?.call("Önbellekten yükleniyor...");
      onProgress?.call(0.1);

      final cached = await _loadFromLocalCache();

      if (cached) {
        _isLoaded = true;
        _isFromCache = true;
        onProgress?.call(0.8);
        onMessage?.call("Veriler hazır!");

        // 🔥 Arka planda güncelle (UI bloklanmaz)
        _backgroundRefreshAllData();

        onProgress?.call(1.0);
        return;
      }

      // 🔥 2. Cache yoksa Internet'ten çek
      onMessage?.call("Veri bağlantısı kuruluyor...");
      onProgress?.call(0.05);

      onMessage?.call("Kullanıcı bilgileri alınıyor...");
      allUsers = await _fetchWithRetry(
        () => GoogleSheetService.getUsersCached(forceRefresh: true),
        "Kullanıcılar",
      );
      onProgress?.call(0.15);

      onMessage?.call("Grup bilgileri hazırlanıyor...");
      allGroups = await _fetchWithRetry(
        () => GoogleSheetService.getGroupsCached(forceRefresh: true),
        "Gruplar",
      );
      onProgress?.call(0.30);

      onMessage?.call("Öğrenci grup ilişkileri işleniyor...");
      allGroupStudents = await _fetchWithRetry(
        () => GoogleSheetService.getGroupStudentsCached(forceRefresh: true),
        "İlişkiler",
      );
      onProgress?.call(0.45);

      onMessage?.call("...");
      allPayments = await _fetchWithRetry(
        () => GoogleSheetService.getPaymentsCached(forceRefresh: true),
        "Ödemeler",
      );
      onProgress?.call(0.55);

      onMessage?.call("Yoklama kayıtları alınıyor...");
      allAttendances = await _fetchWithRetry(
        () => GoogleSheetService.getAttendancesCached(forceRefresh: true),
        "Yoklamalar",
      );
      onProgress?.call(0.65);

      onMessage?.call("Şube ve spor bilgileri yükleniyor...");
      final results = await Future.wait([
        _fetchWithRetry(
          () => GoogleSheetService.getBranchesCached(forceRefresh: true),
          "Şubeler",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getSportsCached(forceRefresh: true),
          "Sporlar",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getCoachesCached(forceRefresh: true),
          "Koçlar",
        ),
      ]);
      allBranches = results[0] as List<Branches>;
      allSports = results[1] as List<Sports>;
      allCoaches = results[2] as List<Coach>;
      onProgress?.call(0.85);

      onMessage?.call("Bildirimler yükleniyor...");
      allNotifications = await _fetchWithRetry(
        () => GoogleSheetService.getNotifications(
          userId: "all",
          forceRefresh: true,
        ),
        "Bildirimler",
      );
      onProgress?.call(0.90);

      onMessage?.call("Veriler düzenleniyor...");
      _buildMaps();
      onProgress?.call(0.95);

      // 🔥 Lokal cache'e kaydet
      await _saveToLocalCache();

      _isLoaded = true;
      _isFromCache = false;
      onProgress?.call(1.0);
      onMessage?.call("Veriler hazır!");

      print(
        "✅ AppRepository: ${allUsers.length} kullanıcı, ${allGroups.length} grup, ${allNotifications.length} bildirim yüklendi",
      );
    } catch (e) {
      print("❌ AppRepository yükleme hatası: $e");
      _initializeEmptyData();
      rethrow;
    }
  }

  // 🔥 Boş verilerle başlatma metodu
  void _initializeEmptyData() {
    allUsers = [];
    allGroups = [];
    allGroupStudents = [];
    allPayments = [];
    allAttendances = [];
    allBranches = [];
    allSports = [];
    allCoaches = [];
    allNotifications = [];
    _buildMaps();
  }

  // ============================================================
  // 🔥 ROLE ÖZEL VERİ YÜKLEME (Hive destekli - AYNI KALDI, sadece cache eklendi)
  // ============================================================

  Future<void> loadStudentData(
    String userId, {
    Function(double progress)? onProgress,
    Function(String message)? onMessage,
  }) async {
    if (_isLoaded) {
      onProgress?.call(1.0);
      return;
    }

    try {
      // 🔥 Önce cache'den dene
      if (await _loadFromLocalCache()) {
        _isLoaded = true;
        _isFromCache = true;
        onProgress?.call(1.0);
        onMessage?.call("Hoş geldiniz!");
        _backgroundRefreshAllData();
        return;
      }

      onMessage?.call("Öğrenci bilgileri yükleniyor...");

      final results = await Future.wait([
        _fetchWithRetry(
          () => GoogleSheetService.getUsersCached(forceRefresh: true),
          "Kullanıcılar",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getGroupsCached(forceRefresh: true),
          "Gruplar",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getGroupStudentsCached(forceRefresh: true),
          "İlişkiler",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getPaymentsCached(forceRefresh: true),
          "Ödemeler",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getAttendancesCached(forceRefresh: true),
          "Yoklamalar",
        ),
      ]);

      allUsers = results[0] as List<Users>;
      allGroups = results[1] as List<Group>;
      allGroupStudents = results[2] as List<GroupStudent>;
      allPayments = results[3] as List<Payment>;
      allAttendances = results[4] as List<Attendance>;
      onProgress?.call(0.7);

      onMessage?.call("Şube ve spor bilgileri yükleniyor...");
      final secondary = await Future.wait([
        _fetchWithRetry(
          () => GoogleSheetService.getBranchesCached(forceRefresh: true),
          "Şubeler",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getSportsCached(forceRefresh: true),
          "Sporlar",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getCoachesCached(forceRefresh: true),
          "Koçlar",
        ),
      ]);
      allBranches = secondary[0] as List<Branches>;
      allSports = secondary[1] as List<Sports>;
      allCoaches = secondary[2] as List<Coach>;
      onProgress?.call(0.9);

      allNotifications = [];
      _notificationsById = {};

      _loadNotificationsInBackground();

      _buildMaps();

      await _saveToLocalCache();

      _isLoaded = true;
      _isFromCache = false;
      onProgress?.call(1.0);
      onMessage?.call("Hoş geldiniz!");

      print("✅ Öğrenci verileri yüklendi: ${allUsers.length} kullanıcı");
    } catch (e) {
      print("❌ loadStudentData hatası: $e");
      _initializeEmptyData();
      rethrow;
    }
  }

  Future<void> loadCoachData(
    String userId, {
    Function(double progress)? onProgress,
    Function(String message)? onMessage,
  }) async {
    if (_isLoaded) {
      onProgress?.call(1.0);
      return;
    }

    try {
      if (await _loadFromLocalCache()) {
        _isLoaded = true;
        _isFromCache = true;
        onProgress?.call(1.0);
        onMessage?.call("Antrenör paneline hoş geldiniz!");
        _backgroundRefreshAllData();
        return;
      }

      onMessage?.call("Antrenör bilgileri yükleniyor...");

      final results = await Future.wait([
        _fetchWithRetry(
          () => GoogleSheetService.getUsersCached(forceRefresh: true),
          "Kullanıcılar",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getGroupsCached(forceRefresh: true),
          "Gruplar",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getGroupStudentsCached(forceRefresh: true),
          "İlişkiler",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getCoachesCached(forceRefresh: true),
          "Koçlar",
        ),
      ]);

      allUsers = results[0] as List<Users>;
      allGroups = results[1] as List<Group>;
      allGroupStudents = results[2] as List<GroupStudent>;
      allCoaches = results[3] as List<Coach>;
      onProgress?.call(0.6);

      onMessage?.call("Ödeme ve yoklama bilgileri yükleniyor...");
      final secondary = await Future.wait([
        _fetchWithRetry(
          () => GoogleSheetService.getPaymentsCached(forceRefresh: true),
          "Ödemeler",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getAttendancesCached(forceRefresh: true),
          "Yoklamalar",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getBranchesCached(forceRefresh: true),
          "Şubeler",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getSportsCached(forceRefresh: true),
          "Sporlar",
        ),
      ]);
      allPayments = secondary[0] as List<Payment>;
      allAttendances = secondary[1] as List<Attendance>;
      allBranches = secondary[2] as List<Branches>;
      allSports = secondary[3] as List<Sports>;
      onProgress?.call(0.9);

      allNotifications = [];
      _notificationsById = {};

      _loadNotificationsInBackground();

      _buildMaps();

      await _saveToLocalCache();

      _isLoaded = true;
      _isFromCache = false;
      onProgress?.call(1.0);
      onMessage?.call("Antrenör paneline hoş geldiniz!");

      print("✅ Antrenör verileri yüklendi: ${allGroups.length} grup");
    } catch (e) {
      print("❌ loadCoachData hatası: $e");
      _initializeEmptyData();
      rethrow;
    }
  }

  Future<void> loadParentData(
    String userId, {
    Function(double progress)? onProgress,
    Function(String message)? onMessage,
  }) async {
    if (_isLoaded) {
      onProgress?.call(1.0);
      return;
    }

    try {
      if (await _loadFromLocalCache()) {
        _isLoaded = true;
        _isFromCache = true;
        onProgress?.call(1.0);
        onMessage?.call("Veli paneline hoş geldiniz!");
        _backgroundRefreshAllData();
        return;
      }

      onMessage?.call("Veli bilgileri yükleniyor...");

      final results = await Future.wait([
        _fetchWithRetry(
          () => GoogleSheetService.getUsersCached(forceRefresh: true),
          "Kullanıcılar",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getGroupsCached(forceRefresh: true),
          "Gruplar",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getGroupStudentsCached(forceRefresh: true),
          "İlişkiler",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getPaymentsCached(forceRefresh: true),
          "Ödemeler",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getAttendancesCached(forceRefresh: true),
          "Yoklamalar",
        ),
      ]);

      allUsers = results[0] as List<Users>;
      allGroups = results[1] as List<Group>;
      allGroupStudents = results[2] as List<GroupStudent>;
      allPayments = results[3] as List<Payment>;
      allAttendances = results[4] as List<Attendance>;
      onProgress?.call(0.8);

      final secondary = await Future.wait([
        _fetchWithRetry(
          () => GoogleSheetService.getBranchesCached(forceRefresh: true),
          "Şubeler",
        ),
        _fetchWithRetry(
          () => GoogleSheetService.getSportsCached(forceRefresh: true),
          "Sporlar",
        ),
      ]);
      allBranches = secondary[0] as List<Branches>;
      allSports = secondary[1] as List<Sports>;
      allCoaches = [];
      onProgress?.call(0.9);

      allNotifications = [];
      _notificationsById = {};

      _loadNotificationsInBackground();

      _buildMaps();

      await _saveToLocalCache();

      _isLoaded = true;
      _isFromCache = false;
      onProgress?.call(1.0);
      onMessage?.call("Veli paneline hoş geldiniz!");

      print("✅ Veli verileri yüklendi");
    } catch (e) {
      print("❌ loadParentData hatası: $e");
      _initializeEmptyData();
      rethrow;
    }
  }

  Future<void> loadFullData({
    Function(double progress)? onProgress,
    Function(String message)? onMessage,
  }) async {
    await loadCriticalData(onProgress: onProgress, onMessage: onMessage);
  }

  // 🔥 Arka planda bildirimleri yükle
  void _loadNotificationsInBackground() {
    Future.microtask(() async {
      try {
        allNotifications = await GoogleSheetService.getNotifications(
          userId: "all",
          forceRefresh: false,
        );
        _notificationsById = {};
        for (var n in allNotifications) {
          _notificationsById[n.notifications_id] = n;
        }
        print("✅ Bildirimler arka planda yüklendi: ${allNotifications.length}");
      } catch (e) {
        print("⚠️ Bildirim yükleme hatası: $e");
        allNotifications = [];
      }
    });
  }

  // 🔥 Arka planda tüm verileri güncelle (Hive'a da kaydet)
  void _backgroundRefreshAllData() async {
    Future.microtask(() async {
      print("🔄 Arka planda veriler güncelleniyor...");
      try {
        final results = await Future.wait([
          GoogleSheetService.getUsersCached(forceRefresh: true),
          GoogleSheetService.getGroupsCached(forceRefresh: true),
          GoogleSheetService.getGroupStudentsCached(forceRefresh: true),
          GoogleSheetService.getPaymentsCached(forceRefresh: true),
          GoogleSheetService.getAttendancesCached(forceRefresh: true),
          GoogleSheetService.getNotifications(
            userId: "all",
            forceRefresh: true,
          ),
        ]);

        allUsers = results[0] as List<Users>;
        allGroups = results[1] as List<Group>;
        allGroupStudents = results[2] as List<GroupStudent>;
        allPayments = results[3] as List<Payment>;
        allAttendances = results[4] as List<Attendance>;
        allNotifications = results[5] as List<Notifications>;

        _buildMaps();

        // 🔥 Güncellenen verileri Hive'a kaydet
        await _saveToLocalCache();

        if (!_dataUpdateController.isClosed) {
          _dataUpdateController.add(true);
        }

        print("✅ Arka plan güncelleme tamamlandı ve cache'e kaydedildi");
      } catch (e) {
        print("⚠️ Arka plan güncelleme hatası: $e");
      }
    });
  }

  // ============================================================
  // 🚀 TÜM VERİLERİ YÜKLE (Eski metod - aynı kaldı)
  // ============================================================
  Future<void> loadAllData({bool forceRefresh = false}) async {
    if (_isLoaded && !forceRefresh) return;

    print("📦 AppRepository: Tüm veriler yükleniyor...");

    final results = await Future.wait([
      _fetchWithRetry(
        () => GoogleSheetService.getUsersCached(forceRefresh: forceRefresh),
        "Kullanıcılar",
      ),
      _fetchWithRetry(
        () => GoogleSheetService.getGroupsCached(forceRefresh: forceRefresh),
        "Gruplar",
      ),
      _fetchWithRetry(
        () => GoogleSheetService.getGroupStudentsCached(
          forceRefresh: forceRefresh,
        ),
        "İlişkiler",
      ),
      _fetchWithRetry(
        () => GoogleSheetService.getPaymentsCached(forceRefresh: forceRefresh),
        "Ödemeler",
      ),
      _fetchWithRetry(
        () =>
            GoogleSheetService.getAttendancesCached(forceRefresh: forceRefresh),
        "Yoklamalar",
      ),
      _fetchWithRetry(
        () => GoogleSheetService.getBranchesCached(forceRefresh: forceRefresh),
        "Şubeler",
      ),
      _fetchWithRetry(
        () => GoogleSheetService.getSportsCached(forceRefresh: forceRefresh),
        "Sporlar",
      ),
      _fetchWithRetry(
        () => GoogleSheetService.getCoachesCached(forceRefresh: forceRefresh),
        "Koçlar",
      ),
      _fetchWithRetry(
        () => GoogleSheetService.getNotifications(
          userId: "all",
          forceRefresh: forceRefresh,
        ),
        "Bildirimler",
      ),
    ]);

    allUsers = results[0] as List<Users>;
    allGroups = results[1] as List<Group>;
    allGroupStudents = results[2] as List<GroupStudent>;
    allPayments = results[3] as List<Payment>;
    allAttendances = results[4] as List<Attendance>;
    allBranches = results[5] as List<Branches>;
    allSports = results[6] as List<Sports>;
    allCoaches = results[7] as List<Coach>;
    allNotifications = results[8] as List<Notifications>;

    _buildMaps();

    await _saveToLocalCache();

    _isLoaded = true;
    print(
      "✅ AppRepository: ${allUsers.length} kullanıcı, ${allGroups.length} grup, ${allNotifications.length} bildirim yüklendi",
    );
  }

  // ============================================================
  // 🔗 İLİŞKİSEL HARİTALAR (AYNI)
  // ============================================================
  void _buildMaps() {
    _groupStudentsByGroupId = {};
    _groupStudentsByStudentId = {};
    _paymentsByStudentId = {};
    _attendancesByStudentId = {};
    _attendancesByGroupId = {};
    _usersById = {};
    _groupsById = {};
    _branchesById = {};
    _sportsById = {};
    _notificationsById = {};

    for (var gs in allGroupStudents) {
      _groupStudentsByGroupId.putIfAbsent(gs.groups_id, () => []).add(gs);
      _groupStudentsByStudentId.putIfAbsent(gs.student_id, () => []).add(gs);
    }

    for (var p in allPayments) {
      _paymentsByStudentId.putIfAbsent(p.student_id, () => []).add(p);
    }

    for (var a in allAttendances) {
      _attendancesByStudentId.putIfAbsent(a.student_id, () => []).add(a);
      _attendancesByGroupId.putIfAbsent(a.groups_id, () => []).add(a);
    }

    for (var u in allUsers) {
      _usersById[u.app] = u;
    }

    for (var g in allGroups) {
      _groupsById[g.groups_id] = g;
    }

    for (var b in allBranches) {
      _branchesById[b.branches_id] = b;
    }

    for (var s in allSports) {
      _sportsById[s.sports_id] = s;
    }

    for (var n in allNotifications) {
      _notificationsById[n.notifications_id] = n;
    }
  }

  // ============================================================
  // 🖼️ FOTOĞRAFLARI ARKA PLANDA YÜKLE (AYNI)
  // ============================================================
  Future<void> preloadProfilePhotosAsync(
    BuildContext context, {
    Function(int loaded, int total)? onProgress,
  }) async {
    if (_isBackgroundLoading) return;
    _isBackgroundLoading = true;

    Future.microtask(() async {
      final usersWithPhotos = allUsers
          .where((u) => u.profile_photo_url.isNotEmpty)
          .toList();
      final total = usersWithPhotos.length;
      int loaded = 0;

      print("🖼️ ${total} profil fotoğrafı arka planda yükleniyor...");

      for (var user in usersWithPhotos) {
        try {
          await precacheImage(NetworkImage(user.profile_photo_url), context);
          loaded++;
          onProgress?.call(loaded, total);
          if (loaded % 10 == 0) print("🖼️ Fotoğraf yükleme: $loaded/$total");
        } catch (e) {}
      }

      print("✅ Tüm profil fotoğrafları arka planda yüklendi ($loaded/$total)");
      _isBackgroundLoading = false;
      for (var callback in _onPhotoLoadCallbacks) {
        callback();
      }
      _onPhotoLoadCallbacks.clear();
    });
  }

  void onPhotoLoadComplete(VoidCallback callback) {
    if (!_isBackgroundLoading) {
      callback();
    } else {
      _onPhotoLoadCallbacks.add(callback);
    }
  }

  Future<void> preloadSinglePhoto(
    String? imageUrl,
    BuildContext context,
  ) async {
    if (imageUrl == null || imageUrl.isEmpty) return;
    try {
      await precacheImage(NetworkImage(imageUrl), context);
    } catch (e) {}
  }

  // ============================================================
  // 📥 RAM'DEN ANINDA VERİ ÇEKME METODLARI (TAMAMI AYNI - DEĞİŞMEDİ)
  // ============================================================

  List<Users> getStudentsOnly() {
    return allUsers.where((u) => u.role.toLowerCase() == 'student').toList();
  }

  List<Users> getCoachesOnly() {
    return allUsers.where((u) => u.role.toLowerCase() == 'coach').toList();
  }

  List<Users> getParentsOnly() {
    return allUsers.where((u) => u.role.toLowerCase() == 'parent').toList();
  }

  Users? getUserById(String userId) {
    return _usersById[userId];
  }

  List<Group> getActiveGroups() {
    return allGroups.where((g) => g.is_active.toUpperCase() == "TRUE").toList();
  }

  List<Group> getAllGroups() {
    return List.from(allGroups);
  }

  List<Group> getGroupsByBranch(String branchId) {
    return allGroups.where((g) => g.branches_id == branchId).toList();
  }

  List<Group> getGroupsByCoach(String coachId) {
    return allGroups.where((g) => g.coach_id == coachId).toList();
  }

  Group? getGroupById(String groupId) {
    return _groupsById[groupId];
  }

  List<GroupStudent> getGroupStudentsByGroupId(String groupId) {
    return _groupStudentsByGroupId[groupId] ?? [];
  }

  List<GroupStudent> getGroupStudentsByStudentId(String studentId) {
    return _groupStudentsByStudentId[studentId] ?? [];
  }

  List<Group> getGroupsByStudentId(String studentId) {
    final groupIds = getGroupStudentsByStudentId(studentId)
        .where((gs) => gs.is_active.toString().toUpperCase() == "TRUE")
        .map((gs) => gs.groups_id)
        .toSet();
    return allGroups.where((g) => groupIds.contains(g.groups_id)).toList();
  }

  List<Payment> getPaymentsByStudentId(String studentId) {
    return _paymentsByStudentId[studentId] ?? [];
  }

  double getStudentBalance(String studentId) {
    final payments = getPaymentsByStudentId(studentId);
    double totalPaid = 0.0;
    for (var p in payments) {
      if (p.status.toLowerCase() == 'paid') {
        totalPaid += double.tryParse(p.amount) ?? 0;
      }
    }
    return totalPaid;
  }

  List<Attendance> getAttendancesByStudentId(String studentId) {
    return _attendancesByStudentId[studentId] ?? [];
  }

  Coach? getCoachByStudentId(String studentId) {
    final groups = getGroupsByStudentId(studentId);
    if (groups.isEmpty) return null;
    final coachId = groups.first.coach_id;
    if (coachId.isEmpty) return null;
    return getCoachById(coachId);
  }

  Users? getStudentCoach(String studentId) {
    final coach = getCoachByStudentId(studentId);
    if (coach == null) return null;
    return getUserById(coach.user_id);
  }

  List<Group> getTodaysGroupsForStudent(String studentId) {
    final myGroups = getGroupsByStudentId(studentId);
    final todayName = _getTodayNameTurkish();
    final todaysGroups = myGroups
        .where((group) => group.schedule.contains(todayName))
        .toList();
    todaysGroups.sort((a, b) {
      final aTime = _extractStartTime(a, todayName);
      final bTime = _extractStartTime(b, todayName);
      return _timeToMinutes(aTime).compareTo(_timeToMinutes(bTime));
    });
    return todaysGroups;
  }

  Users? getParentByStudentId(
    String studentId,
    List<ParentStudent> parentStudents,
  ) {
    final link = parentStudents.firstWhere(
      (ps) => ps.student_id == studentId,
      orElse: () =>
          ParentStudent(parent_student_id: "", parent_id: "", student_id: ""),
    );
    if (link.parent_id.isEmpty) return null;
    return getUserById(link.parent_id);
  }

  List<Users> getChildrenByParentId(
    String parentId,
    List<ParentStudent> parentStudents,
  ) {
    final childIds = parentStudents
        .where((ps) => ps.parent_id == parentId)
        .map((ps) => ps.student_id)
        .toList();
    return allUsers.where((u) => childIds.contains(u.app)).toList();
  }

  // ============================================================
  // 🔥🔥🔥 ANTRENÖRE ÖZEL METODLAR (DÜZELTİLDİ - YARDIMCI ANTRENÖR DESTEĞİ) 🔥🔥🔥
  // ============================================================
  List<Group> getGroupsByCoachId(String coachId) {
    if (coachId.isEmpty) {
      print("❌ getGroupsByCoachId hata: coachId parametresi boş string geldi!");
      return [];
    }

    print("🔍 getGroupsByCoachId çağrıldı - coachId: $coachId");

    // 1. Önce bu ID ile eşleşen coach kaydını bul
    Coach? currentCoach;
    try {
      currentCoach = allCoaches.firstWhere(
        (c) => c.user_id == coachId || c.coach_id == coachId,
      );
      print(
        "📋 Koç kaydı bulundu: coach_id=${currentCoach.coach_id}, user_id=${currentCoach.user_id}, supervisor=${currentCoach.supervisor_coach_id}",
      );
    } catch (_) {
      print(
        "⚠️ coaches tablosunda bu ID ile eşleşen kayıt bulunamadı: $coachId",
      );
      return [];
    }

    // 2. Eğer bu coach'un supervisor_coach_id'si BOŞ ise, bu bir YARDIMCI ANTRENÖR
    // Ve başka bir hocanın supervisor listesinde olabilir
    if (currentCoach.supervisor_coach_id.isEmpty) {
      print(
        "🔍 Bu coach'un supervisor_coach_id'si BOŞ, yardımcı antrenör olabilir.",
      );

      // Tüm coach'ları tara, supervisor_coach_id içinde bu user_id var mı?
      String masterCoachId = "";
      String masterUserId = "";

      for (var coach in allCoaches) {
        if (coach.supervisor_coach_id.isNotEmpty) {
          // supervisor_coach_id'yi parse et (virgül veya nokta ile ayrılmış olabilir)
          List<String> supervisorIds = [];
          if (coach.supervisor_coach_id.contains(',')) {
            supervisorIds = coach.supervisor_coach_id
                .split(',')
                .map((s) => s.trim())
                .toList();
          } else if (coach.supervisor_coach_id.contains('.')) {
            supervisorIds = coach.supervisor_coach_id
                .split('.')
                .map((s) => s.trim())
                .toList();
          } else {
            supervisorIds = [coach.supervisor_coach_id.trim()];
          }

          // Bu coach'un supervisor listesinde aranan ID var mı?
          if (supervisorIds.contains(currentCoach.user_id)) {
            masterCoachId = coach.coach_id;
            masterUserId = coach.user_id;
            print(
              "✅ Yardımcı antrenör bulundu! Üst hoca: coach_id=$masterCoachId, user_id=$masterUserId",
            );
            break;
          }
        }
      }

      // Üst hoca bulunduysa, onun gruplarını döndür
      if (masterCoachId.isNotEmpty) {
        final groups = allGroups
            .where((g) => g.coach_id == masterCoachId)
            .toList();
        print(
          "📚 Yardımcı için üst hocanın (Celal) grupları: ${groups.length} grup",
        );
        return groups;
      }

      // Üst hoca bulunamadıysa, kendi gruplarını dene (boş olabilir)
      print("⚠️ Üst hoca bulunamadı, kendi grupları deneniyor...");
    }

    // 3. Normal ana koç ise sadece kendi gruplarını getir
    final groups = allGroups.where((g) => g.coach_id == coachId).toList();
    print("📚 Normal coach için gruplar: ${groups.length} grup");
    return groups;
  }

  List<Users> getStudentsByCoachId(String coachId) {
    print("🔍 getStudentsByCoachId çağrıldı - coachId: $coachId");

    final myGroupIds = getGroupsByCoachId(
      coachId,
    ).map((g) => g.groups_id).toSet();
    print("📚 Bulunan grup ID'leri: ${myGroupIds.join(', ')}");

    final studentIds = allGroupStudents
        .where(
          (gs) =>
              myGroupIds.contains(gs.groups_id) &&
              gs.is_active.toString().toUpperCase() == "TRUE",
        )
        .map((gs) => gs.student_id)
        .toSet();

    final students = allUsers.where((u) => studentIds.contains(u.app)).toList();
    print("👥 Bulunan öğrenci sayısı: ${students.length}");
    return students;
  }

  List<Notifications> getNotificationsForCoach(
    String coachId, {
    int? lastNDays,
  }) {
    print("🔍 getNotificationsForCoach çağrıldı - coachId: $coachId");

    final myGroupIds = getGroupsByCoachId(
      coachId,
    ).map((g) => g.groups_id).toSet();
    print("📚 Grup ID'leri: ${myGroupIds.join(', ')}");

    var filtered = allNotifications.where((n) {
      final recipientId = n.recipient_id?.toString() ?? "";

      // Genel duyuru
      if (recipientId == "all" || recipientId == "Tümü" || recipientId == "ALL")
        return true;

      // Gruba özel duyuru
      if (recipientId.isNotEmpty && myGroupIds.contains(recipientId))
        return true;

      // groups_id ile kontrol
      if (n.groups_id.isNotEmpty && myGroupIds.contains(n.groups_id))
        return true;

      return false;
    }).toList();

    if (lastNDays != null) {
      final cutoffDate = DateTime.now().subtract(Duration(days: lastNDays));
      filtered = filtered.where((n) {
        try {
          return DateTime.parse(n.sent_at).isAfter(cutoffDate);
        } catch (_) {
          return false;
        }
      }).toList();
    }

    filtered.sort((a, b) {
      try {
        return DateTime.parse(b.sent_at).compareTo(DateTime.parse(a.sent_at));
      } catch (_) {
        return 0;
      }
    });

    print("📨 Bulunan bildirim sayısı: ${filtered.length}");
    return filtered;
  }

  List<Group> getTodaysGroupsForCoach(String coachId) {
    print("🔍 getTodaysGroupsForCoach çağrıldı - coachId: $coachId");

    final myGroups = getGroupsByCoachId(coachId);
    final todayName = _getTodayNameTurkish();

    print("📅 Bugün: $todayName, Toplam grup: ${myGroups.length}");

    final todaysGroups = myGroups
        .where((group) => group.schedule.contains(todayName))
        .toList();

    todaysGroups.sort((a, b) {
      final aTime = _extractStartTime(a, todayName);
      final bTime = _extractStartTime(b, todayName);
      return _timeToMinutes(aTime).compareTo(_timeToMinutes(bTime));
    });

    print("📅 Bugünkü gruplar: ${todaysGroups.length}");
    for (var g in todaysGroups) {
      print("   - ${g.name} (${_extractStartTime(g, todayName)})");
    }
    return todaysGroups;
  }

  Users? getCoachUser(String coachId) {
    final coach = getCoachById(coachId);
    if (coach == null) return null;
    return getUserById(coach.user_id);
  }

  // ----- YOKLAMA -----
  List<Attendance> getAttendancesByGroupId(String groupId) {
    return _attendancesByGroupId[groupId] ?? [];
  }

  // ----- DİĞER -----
  List<Payment> getAllPayments() {
    return List.from(allPayments);
  }

  Coach? getCoachById(String coachId) {
    try {
      return allCoaches.firstWhere((c) => c.coach_id == coachId);
    } catch (e) {
      return null;
    }
  }

  Branches? getBranchById(String branchId) {
    return _branchesById[branchId];
  }

  Sports? getSportById(String sportId) {
    return _sportsById[sportId];
  }

  Notifications? getNotificationById(String notificationId) {
    return _notificationsById[notificationId];
  }

  List<Notifications> getNotificationsByRecipient(String recipientId) {
    return allNotifications.where((n) {
      final rId = n.recipient_id?.toString() ?? "";
      return rId == recipientId ||
          rId == "all" ||
          rId == "ALL" ||
          rId == "Tümü";
    }).toList();
  }

  int getTotalStudentCount() => getStudentsOnly().length;
  int getTotalGroupCount() => allGroups.length;
  int getTotalPaymentCount() => allPayments.length;
  int getTotalNotificationCount() => allNotifications.length;

  double getTotalRevenue() {
    double total = 0;
    for (var p in allPayments) {
      if (p.status.toLowerCase() == 'paid') {
        total += double.tryParse(p.amount) ?? 0;
      }
    }
    return total;
  }

  double getRevenueByMonth(int year, int month) {
    double total = 0;
    for (var p in allPayments) {
      if (p.status.toLowerCase() != 'paid') continue;
      try {
        final date = DateTime.parse(p.paid_date.split('T')[0]);
        if (date.year == year && date.month == month) {
          total += double.tryParse(p.amount) ?? 0;
        }
      } catch (_) {}
    }
    return total;
  }

  List<Users> searchStudents(String query) {
    if (query.isEmpty) return getStudentsOnly();
    final lowerQuery = query.toLowerCase();
    return getStudentsOnly().where((student) {
      return student.first_name.toLowerCase().contains(lowerQuery) ||
          student.last_name.toLowerCase().contains(lowerQuery) ||
          "${student.first_name} ${student.last_name}".toLowerCase().contains(
            lowerQuery,
          ) ||
          student.email.toLowerCase().contains(lowerQuery) ||
          student.phone.contains(query);
    }).toList();
  }

  List<Group> searchGroups(String query) {
    if (query.isEmpty) return allGroups;
    final lowerQuery = query.toLowerCase();
    return allGroups
        .where((group) => group.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  List<Notifications> searchNotifications(String query) {
    if (query.isEmpty) return allNotifications;
    final lowerQuery = query.toLowerCase();
    return allNotifications.where((n) {
      return n.title.toLowerCase().contains(lowerQuery) ||
          n.message.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  String _getTodayNameTurkish() {
    const days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    final now = DateTime.now();
    return days[now.weekday - 1];
  }

  String _extractStartTime(Group group, String dayName) {
    final pattern = RegExp('$dayName:(\\d{2}:\\d{2})-(\\d{2}:\\d{2})');
    final match = pattern.firstMatch(group.schedule);
    return match?.group(1) ?? "23:59";
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length == 2) {
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }
    return 0;
  }

  // ============================================================
  // 🔄 CACHE YÖNETİMİ (GÜNCELLENDİ - Hive desteği eklendi)
  // ============================================================

  Future<void> refreshAllData() async {
    _isLoaded = false;
    GoogleSheetService.invalidateAllCache();
    await _localStorage.clearAll();
    await loadAllData(forceRefresh: true);
  }

  Future<void> refreshTable(String tableName) async {
    GoogleSheetService.invalidateCache(tableName);
    await _localStorage.clearTable(tableName);
    _isLoaded = false;
    await loadAllData(forceRefresh: true);
  }

  Future<void> refreshSingleTable(String tableName) async {
    GoogleSheetService.invalidateCache(tableName);
    switch (tableName) {
      case 'users':
        allUsers = await _fetchWithRetry(
          () => GoogleSheetService.getUsersCached(forceRefresh: true),
          "Kullanıcılar",
        );
        await _localStorage.saveUsers(allUsers);
        break;
      case 'groups':
        allGroups = await _fetchWithRetry(
          () => GoogleSheetService.getGroupsCached(forceRefresh: true),
          "Gruplar",
        );
        await _localStorage.saveGroups(allGroups);
        break;
      case 'payments':
        allPayments = await _fetchWithRetry(
          () => GoogleSheetService.getPaymentsCached(forceRefresh: true),
          "Ödemeler",
        );
        await _localStorage.savePayments(allPayments);
        break;
      case 'attendances':
        allAttendances = await _fetchWithRetry(
          () => GoogleSheetService.getAttendancesCached(forceRefresh: true),
          "Yoklamalar",
        );
        await _localStorage.saveAttendances(allAttendances);
        break;
      case 'notifications':
        allNotifications = await _fetchWithRetry(
          () => GoogleSheetService.getNotifications(
            userId: "all",
            forceRefresh: true,
          ),
          "Bildirimler",
        );
        await _localStorage.saveNotifications(allNotifications);
        break;
    }
    _buildMaps();
  }

  void clearCache() {
    _groupStudentsByGroupId.clear();
    _groupStudentsByStudentId.clear();
    _paymentsByStudentId.clear();
    _attendancesByStudentId.clear();
    _attendancesByGroupId.clear();
    _usersById.clear();
    _groupsById.clear();
    _branchesById.clear();
    _sportsById.clear();
    _notificationsById.clear();
  }

  void reset() {
    _isLoaded = false;
    _isBackgroundLoading = false;
    clearCache();
  }

  void dispose() {
    _dataUpdateController.close();
    _syncService.dispose();
  }

  // ============================================================
  // 🔥 OFFLINE SYNC İÇİN PUBLIC METODLAR (EKLE)
  // ============================================================

  /// OfflineSyncManager için map'leri yeniden oluştur (public versiyon)
  void rebuildMaps() {
    _buildMaps();
  }

  /// Tüm verileri güncelle (toplu güncelleme için)
  void updateAllData({
    required List<Users> users,
    required List<Group> groups,
    required List<GroupStudent> groupStudents,
    required List<Payment> payments,
    required List<Attendance> attendances,
    required List<Coach> coaches,
    required List<Notifications> notifications,
  }) {
    allUsers = users;
    allGroups = groups;
    allGroupStudents = groupStudents;
    allPayments = payments;
    allAttendances = attendances;
    allCoaches = coaches;
    allNotifications = notifications;
    _buildMaps();
    _isLoaded = true;
  }

  /// Tüm verileri getir (toplu okuma için)
  Map<String, dynamic> getAllData() {
    return {
      'users': allUsers,
      'groups': allGroups,
      'groupStudents': allGroupStudents,
      'payments': allPayments,
      'attendances': allAttendances,
      'coaches': allCoaches,
      'notifications': allNotifications,
    };
  }
}
