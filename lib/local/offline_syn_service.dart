/*
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'package:EVOM_SPORrena/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/local/local_db.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final LocalDatabaseService _localDB = LocalDatabaseService();
  bool _isSyncing = false;

  // =========================================================================
  // VERİ ÇEKME (ÖNCE LOCAL, SONRA API)
  // =========================================================================

  Future<List<T>> getData<T>({
    required String tableName,
    required String apiEndpoint,
    required T Function(Map<String, dynamic>) fromJson,
    Duration cacheDuration = const Duration(minutes: 5),
    bool forceRefresh = false,
  }) async {
    // Force refresh varsa local'i temizle
    if (forceRefresh) {
      await _localDB.clearTable(tableName);
    }

    // 1. ÖNCE LOCAL'DEN AL
    final localData = await _localDB.getAll(tableName);

    // Cache süresi kontrolü
    if (!forceRefresh && localData.isNotEmpty) {
      print("📦 LOCAL'DEN GETİRİLDİ: $tableName (${localData.length} kayıt)");
      return localData.map((item) => fromJson(item)).toList();
    }

    // 2. LOCAL BOŞSA VEYA SÜRESİ GEÇTİYSE API'DEN ÇEK
    print("🌐 API'DEN ÇEKİLİYOR: $tableName");

    final networkData = await _fetchFromApi(apiEndpoint);

    // 3. LOCAL'E KAYDET
    for (var item in networkData) {
      final id = _getIdFromItem(tableName, item);
      await _localDB.insertOrUpdate(tableName, id, item);
    }

    await _localDB.addSyncLog(tableName, "success", networkData.length);

    return networkData.map((item) => fromJson(item)).toList();
  }

  String _getIdFromItem(String tableName, Map<String, dynamic> item) {
    switch (tableName) {
      case 'users':
        return item['app']?.toString() ?? '';
      case 'groups':
        return item['groups_id']?.toString() ?? '';
      case 'payments':
        return item['payments_id']?.toString() ?? '';
      case 'attendances':
        return item['attendances_id']?.toString() ?? '';
      case 'notifications':
        return item['notifications_id']?.toString() ?? '';
      case 'coaches':
        return item['coach_id']?.toString() ?? '';
      case 'branches':
        return item['branches_id']?.toString() ?? '';
      case 'sports':
        return item['sports_id']?.toString() ?? '';
      default:
        return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  Future<List<dynamic>> _fetchFromApi(String apiEndpoint) async {
    return await GoogleSheetService.fetchTable(apiEndpoint);
  }

  // =========================================================================
  // VERİ KAYDETME (PENDING QUEUE)
  // =========================================================================

  Future<bool> saveData({
    required String tableName,
    required Map<String, dynamic> data,
    required Future<bool> Function(Map<String, dynamic>) apiSaveFunction,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();

    // ÖNCE LOCAL'E KAYDET
    final tempId =
        data['${tableName}_id'] ??
        'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _localDB.insertOrUpdate(tableName, tempId.toString(), data);

    if (connectivity != ConnectivityResult.none) {
      // İNTERNET VAR: HEMEN API'YE GÖNDER
      final success = await apiSaveFunction(data);
      if (success) {
        print("✅ API'ye gönderildi: $tableName");
        return true;
      } else {
        // API HATASI: PENDING QUEUE'YE EKLE
        await _localDB.addPendingOperation(
          operation: 'insert',
          tableName: tableName,
          data: data,
        );
        print("⚠️ API hatası, pending queue'ye eklendi: $tableName");
        return true;
      }
    } else {
      // İNTERNET YOK: PENDING QUEUE'YE EKLE
      await _localDB.addPendingOperation(
        operation: 'insert',
        tableName: tableName,
        data: data,
      );
      print("📱 İnternet yok, pending queue'ye eklendi: $tableName");
      return true;
    }
  }

  // =========================================================================
  // SENKRONİZASYON
  // =========================================================================

  Future<void> syncPendingOperations() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        print("⚠️ İnternet yok, senkronizasyon bekletiliyor");
        _isSyncing = false;
        return;
      }

      final pendingOps = await _localDB.getPendingOperations();
      print("🔄 Senkronize edilecek: ${pendingOps.length} işlem");

      int successCount = 0;
      int failCount = 0;

      for (var op in pendingOps) {
        final data = jsonDecode(op['data'] as String);
        final success = await _executeOperation(
          op['operation'] as String,
          op['table_name'] as String,
          data,
        );

        if (success) {
          await _localDB.removePendingOperation(op['id'] as int);
          successCount++;
          print("✅ Senkronize edildi: ${op['table_name']}");
        } else {
          await _localDB.updatePendingRetryCount(op['id'] as int);

          final retryCount = (op['retry_count'] as int?) ?? 0;
          if (retryCount + 1 >= 3) {
            await _localDB.removePendingOperation(op['id'] as int);
            print(
              "❌ 3 deneme başarısız, işlem iptal edildi: ${op['table_name']}",
            );
          } else {
            failCount++;
            print(
              "❌ Senkronizasyon başarısız, tekrar denenicek: ${op['table_name']}",
            );
          }
        }
      }

      await _localDB.addSyncLog("pending_operations", "success", successCount);
      print(
        "🔄 Senkronizasyon tamamlandı: $successCount başarılı, $failCount başarısız",
      );
    } catch (e) {
      print("Senkronizasyon hatası: $e");
      await _localDB.addSyncLog("pending_operations", "error", 0);
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _executeOperation(
    String operation,
    String tableName,
    Map<String, dynamic> data,
  ) async {
    switch (operation) {
      case 'insert':
        return await GoogleSheetService.insertData(tableName, data);
      case 'update':
        return await GoogleSheetService.updateData(tableName, data);
      case 'delete':
        return await GoogleSheetService.deleteData(tableName, data);
      default:
        return false;
    }
  }

  // =========================================================================
  // PERİYODİK SENKRONİZASYON
  // =========================================================================

  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    Future.delayed(Duration.zero, () async {
      while (true) {
        await Future.delayed(interval);
        await syncPendingOperations();
      }
    });
  }

  // =========================================================================
  // ZORUNLU SENKRONİZASYON
  // =========================================================================

  Future<void> forceSync() async {
    print("🔄 Zorunlu senkronizasyon başlatılıyor...");
    await syncPendingOperations();
  }

  Future<void> refreshAllData() async {
    print("🔄 Tüm veriler yenileniyor...");
    final tables = [
      'users',
      'groups',
      'payments',
      'attendances',
      'notifications',
      'coaches',
      'branches',
      'sports',
    ];

    for (var table in tables) {
      await _localDB.clearTable(table);
      await _fetchFromApi(table);
    }

    print("✅ Tüm veriler yenilendi!");
  }

  // =========================================================================
  // DURUM KONTROLÜ
  // =========================================================================

  Future<bool> hasPendingOperations() async {
    final pending = await _localDB.getPendingOperations();
    return pending.isNotEmpty;
  }

  Future<int> getPendingOperationCount() async {
    final pending = await _localDB.getPendingOperations();
    return pending.length;
  }

  Future<Map<String, int>> getLocalDataStats() async {
    return await _localDB.getAllTableCounts();
  }
  // offline_sync_service.dart içine ekle:

  // SADECE LOCAL'DEN OKU - ASLA API'YE GİTMEZ! ⚡
  Future<List<T>> getLocalDataOnly<T>({
    required String tableName,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final localData = await _localDB.getAll(tableName);
    print("📦 LOCAL'DEN OKUNDU: $tableName (${localData.length} kayıt)");
    return localData.map((item) => fromJson(item['data'])).toList();
  }

  // BACKGROUND SYNC - UI'ı kitllemez
  Future<void> syncTableInBackground({
    required String tableName,
    required String apiEndpoint,
  }) async {
    try {
      print("🌐 BACKGROUND SYNC: $tableName");
      final networkData = await _fetchFromApi(apiEndpoint);

      for (var item in networkData) {
        final id = _getIdFromItem(tableName, item);
        await _localDB.insertOrUpdate(tableName, id, item);
      }

      await _localDB.addSyncLog(tableName, "success", networkData.length);
      print("✅ BACKGROUND SYNC TAMAMLANDI: $tableName");
    } catch (e) {
      print("❌ BACKGROUND SYNC HATASI: $tableName - $e");
    }
  }

  // TÜM TABLOLARI SYNC ET
  Future<void> syncAllTablesInBackground() async {
    print("🔄 TÜM TABLOLAR SYNC BAŞLADI");

    final tables = {
      'users': 'users',
      'groups': 'groups',
      'payments': 'payments',
      'attendances': 'attendances',
      'notifications': 'notifications',
      'coaches': 'coaches',
      'branches': 'branches',
      'sports': 'sports',
    };

    for (var entry in tables.entries) {
      await syncTableInBackground(
        tableName: entry.key,
        apiEndpoint: entry.value,
      );
      await Future.delayed(Duration(milliseconds: 500)); // Rate limiting
    }

    print("✅ TÜM TABLOLAR SYNC TAMAMLANDI");
  }
}
*/
// offline_sync_service.dart (GÜNCELLENMİŞ VERSİYON)

import 'package:EVOM_SPOR/local/local_db.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final LocalDatabaseService _localDB = LocalDatabaseService();
  bool _isSyncing = false;

  // =========================================================================
  // 🚀 ANA METOD: ÖNCE LOCAL'DEN OKU, SONRA BACKGROUND SYNC
  // =========================================================================

  Future<List<T>> getData<T>({
    required String tableName,
    required T Function(Map<String, dynamic>) fromJson,
    bool forceRefresh = false,
  }) async {
    // 1. FORCE REFRESH varsa local'i temizle
    if (forceRefresh) {
      await _localDB.clearTable(tableName);
    }

    // 2. ÖNCE LOCAL'DEN OKU (ÇOK HIZLI ⚡)
    final localData = await _localDB.getAll(tableName);

    if (localData.isNotEmpty && !forceRefresh) {
      print("📦 LOCAL'DEN OKUNDU: $tableName (${localData.length} kayıt)");

      // Arkada background'da güncelle (kullanıcı beklemez)
      _syncTableInBackground(tableName);

      return localData.map((item) => fromJson(item['data'])).toList();
    }

    // 3. LOCAL BOŞSA veya FORCE REFRESH varsa API'den çek
    print("🌐 API'DEN ÇEKİLİYOR: $tableName");

    List<dynamic> networkData;
    try {
      // GoogleSheetService'in mevcut cache'li metodunu kullan
      networkData = await GoogleSheetService.fetchTableCached(
        tableName,
        forceRefresh: true,
      );
    } catch (e) {
      // API hatası, local'de ne varsa onu döndür
      if (localData.isNotEmpty) {
        print("⚠️ API hatası, local veri döndürülüyor");
        return localData.map((item) => fromJson(item['data'])).toList();
      }
      rethrow;
    }

    // 4. Local'e kaydet
    for (var item in networkData) {
      final id = _getIdFromItem(tableName, item);
      await _localDB.insertOrUpdate(tableName, id, item);
    }

    await _localDB.addSyncLog(tableName, "success", networkData.length);

    return networkData.map((item) => fromJson(item)).toList();
  }

  // Background sync (UI blocklamaz)
  Future<void> _syncTableInBackground(String tableName) async {
    Future.microtask(() async {
      try {
        final networkData = await GoogleSheetService.fetchTableCached(
          tableName,
          forceRefresh: true,
        );

        for (var item in networkData) {
          final id = _getIdFromItem(tableName, item);
          await _localDB.insertOrUpdate(tableName, id, item);
        }

        print("🔄 BACKGROUND SYNC: $tableName (${networkData.length} kayıt)");
      } catch (e) {
        print("⚠️ Background sync hatası: $tableName - $e");
      }
    });
  }

  // Tüm tabloları background'da sync et
  Future<void> syncAllTablesInBackground() async {
    final tables = [
      'users',
      'groups',
      'payments',
      'attendances',
      'notifications',
      'coaches',
      'branches',
      'sports',
    ];

    for (var table in tables) {
      await _syncTableInBackground(table);
      await Future.delayed(Duration(milliseconds: 200));
    }
  }

  String _getIdFromItem(String tableName, Map<String, dynamic> item) {
    switch (tableName) {
      case 'users':
        return item['app']?.toString() ?? '';
      case 'groups':
        return item['groups_id']?.toString() ?? '';
      case 'payments':
        return item['payments_id']?.toString() ?? '';
      case 'attendances':
        return item['attendances_id']?.toString() ?? '';
      case 'notifications':
        return item['notifications_id']?.toString() ?? '';
      case 'coaches':
        return item['coach_id']?.toString() ?? '';
      case 'branches':
        return item['branches_id']?.toString() ?? '';
      case 'sports':
        return item['sports_id']?.toString() ?? '';
      default:
        return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  // Pending operation'ları sync et
  Future<void> syncPendingOperations() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        print("⚠️ İnternet yok, sync bekletiliyor");
        return;
      }

      final pendingOps = await _localDB.getPendingOperations();
      print("🔄 Sync edilecek: ${pendingOps.length} işlem");

      for (var op in pendingOps) {
        final data = jsonDecode(op['data'] as String);
        bool success = false;

        switch (op['operation'] as String) {
          case 'insert':
            success = await GoogleSheetService.insertData(
              op['table_name'] as String,
              data,
            );
            break;
          case 'update':
            success = await GoogleSheetService.updateData(
              op['table_name'] as String,
              data,
              data, // updateData parametresi eklenmeli
            );
            break;
          case 'delete':
            success = await GoogleSheetService.deleteData(
              op['table_name'] as String,
              data,
            );
            break;
        }

        if (success) {
          await _localDB.removePendingOperation(op['id'] as int);
          print("✅ Sync edildi: ${op['table_name']}");
        } else {
          await _localDB.updatePendingRetryCount(op['id'] as int);
          final retryCount = (op['retry_count'] as int?) ?? 0;
          if (retryCount + 1 >= 3) {
            await _localDB.removePendingOperation(op['id'] as int);
            print("❌ 3 deneme başarısız, işlem iptal edildi");
          }
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  void startPeriodicSync({Duration interval = const Duration(minutes: 30)}) {
    Future.delayed(Duration.zero, () async {
      while (true) {
        await Future.delayed(interval);
        await syncPendingOperations();
        await syncAllTablesInBackground();
      }
    });
  }

  Future<Map<String, int>> getLocalDataStats() async {
    return await _localDB.getAllTableCounts();
  }
  // offline_sync_service.dart - BU METODLARI EKLE

  // =========================================================================
  // 📝 VERİ KAYDETME (OFFLINE-FIRST)
  // =========================================================================

  Future<bool> saveData({
    required String tableName,
    required Map<String, dynamic> data,
    required Future<bool> Function(Map<String, dynamic>) apiSaveFunction,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();

    // 1. ÖNCE LOCAL'E KAYDET
    final tempId =
        data['${tableName}_id']?.toString() ??
        'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _localDB.insertOrUpdate(tableName, tempId, data);

    print("💾 Local'e kaydedildi: $tableName");

    // 2. İNTERNET VARSA HEMEN API'YE GÖNDER
    if (connectivity != ConnectivityResult.none) {
      try {
        final success = await apiSaveFunction(data);
        if (success) {
          // API başarılı, local'deki veriyi güncelle (ID varsa)
          print("✅ API'ye gönderildi: $tableName");
          return true;
        } else {
          // API hatası, pending queue'ye ekle
          await _localDB.addPendingOperation(
            operation: 'insert',
            tableName: tableName,
            data: data,
          );
          print("⚠️ API hatası, pending queue'ye eklendi: $tableName");
          return true; // Local'e kaydettiğimiz için true döndür
        }
      } catch (e) {
        // API'ye gönderilemedi, pending queue'ye ekle
        await _localDB.addPendingOperation(
          operation: 'insert',
          tableName: tableName,
          data: data,
        );
        print("⚠️ API hatası ($e), pending queue'ye eklendi: $tableName");
        return true;
      }
    } else {
      // 3. İNTERNET YOKSA PENDING QUEUE'YE EKLE
      await _localDB.addPendingOperation(
        operation: 'insert',
        tableName: tableName,
        data: data,
      );
      print("📱 İnternet yok, pending queue'ye eklendi: $tableName");
      return true;
    }
  }

  // UPDATE için (varsa)
  Future<bool> updateData({
    required String tableName,
    required String id,
    required Map<String, dynamic> data,
    required Future<bool> Function(Map<String, dynamic>) apiUpdateFunction,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();

    // 1. Local'i güncelle
    await _localDB.insertOrUpdate(tableName, id, data);

    // 2. İnternet varsa API'ye gönder
    if (connectivity != ConnectivityResult.none) {
      final success = await apiUpdateFunction(data);
      if (!success) {
        await _localDB.addPendingOperation(
          operation: 'update',
          tableName: tableName,
          data: {...data, '_id': id},
        );
      }
      return success;
    } else {
      // İnternet yoksa pending queue'ye ekle
      await _localDB.addPendingOperation(
        operation: 'update',
        tableName: tableName,
        data: {...data, '_id': id},
      );
      return true;
    }
  }

  // DELETE için (varsa)
  Future<bool> deleteData({
    required String tableName,
    required String id,
    required Future<bool> Function(String) apiDeleteFunction,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();

    // 1. Local'den sil
    await _localDB.deleteById(tableName, id);

    // 2. İnternet varsa API'ye gönder
    if (connectivity != ConnectivityResult.none) {
      final success = await apiDeleteFunction(id);
      if (!success) {
        await _localDB.addPendingOperation(
          operation: 'delete',
          tableName: tableName,
          data: {'id': id},
        );
      }
      return success;
    } else {
      // İnternet yoksa pending queue'ye ekle
      await _localDB.addPendingOperation(
        operation: 'delete',
        tableName: tableName,
        data: {'id': id},
      );
      return true;
    }
  }
}
