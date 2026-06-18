// lib/managerpage/manager_offline/offline_attendance_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineAttendanceService {
  static final OfflineAttendanceService _instance =
      OfflineAttendanceService._internal();
  factory OfflineAttendanceService() => _instance;
  OfflineAttendanceService._internal();

  final LocalStorageService _localStorage = LocalStorageService();
  final List<QueuedAttendance> _attendanceQueue = [];

  // 🔥 Değişenleri takip etmek için
  final Map<String, Attendance> _pendingChanges = {};
  final Map<String, Attendance> _syncedChanges = {};

  final StreamController<List<Attendance>> _syncController =
      StreamController<List<Attendance>>.broadcast();
  Stream<List<Attendance>> get onSyncComplete => _syncController.stream;

  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  // 🔥 İnternet durumu için
  ConnectivityResult _lastConnectivity = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();

  Future<void> init() async {
    if (_isInitialized) return;
    await _localStorage.init();
    await _loadQueueFromStorage();

    // 🔥 İnternet değişikliklerini dinle - DÜZELTİLDİ
    _connectivity.onConnectivityChanged.listen((result) {
      // 🔥 result bir Liste, ilk elemanı al
      _lastConnectivity = result.isNotEmpty
          ? result.first
          : ConnectivityResult.none;
      if (_lastConnectivity != ConnectivityResult.none &&
          _attendanceQueue.isNotEmpty) {
        print(
          "🌐 İnternet bağlantısı geldi, hemen yoklama senkronize ediliyor...",
        );
        _processQueue();
      }
    });

    _startPeriodicSync();
    _isInitialized = true;
    print(
      "✅ OfflineAttendanceService başlatıldı, kuyrukta ${_attendanceQueue.length} işlem",
    );
  }

  Future<Map<String, dynamic>> saveAttendanceBatch(
    List<Map<String, dynamic>> yoklamaListesi,
    DateTime selectedDate,
    Group selectedGroup,
    Users currentUser,
  ) async {
    print("🔥 saveAttendanceBatch çağrıldı!");
    print("📊 Öğrenci sayısı: ${yoklamaListesi.length}");

    if (_isDisposed) {
      print("❌ Service disposed!");
      return {'success': false, 'savedCount': 0, 'error': 'Service disposed'};
    }

    try {
      final formattedDate =
          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

      print("📅 Tarih: $formattedDate");

      final localAttendances = _localStorage.getAttendances();
      final batchId = "batch_${DateTime.now().millisecondsSinceEpoch}";
      int savedCount = 0;

      final List<Map<String, dynamic>> changedItems = [];

      for (var item in yoklamaListesi) {
        final student = item["student"] as Users;
        final isPresent = item["is_present"] == true;
        final note = item["note"] ?? "";

        print(
          "🔍 Öğrenci: ${student.first_name} ${student.last_name}, Durum: $isPresent",
        );

        final existingIndex = localAttendances.indexWhere(
          (a) =>
              a.student_id == student.app &&
              a.groups_id == selectedGroup.groups_id &&
              a.attendance_date.startsWith(formattedDate),
        );

        final newAttendance = Attendance(
          attendances_id: item["attendance_id"]?.isNotEmpty == true
              ? item["attendance_id"]
              : "local_${DateTime.now().millisecondsSinceEpoch}_${student.app}",
          groups_id: selectedGroup.groups_id,
          student_id: student.app,
          taken_by: currentUser.app,
          attendance_date: formattedDate,
          status: isPresent ? "TRUE" : "FALSE",
          note: note,
        );

        changedItems.add({
          "student": student,
          "is_present": isPresent,
          "note": note,
          "new_attendance": newAttendance,
          "old_attendance": existingIndex != -1
              ? localAttendances[existingIndex]
              : null,
        });

        print("✅ Eklendi: ${student.first_name}");
      }

      print("📊 Değişen öğrenci sayısı: ${changedItems.length}");

      for (var change in changedItems) {
        final newAttendance = change["new_attendance"] as Attendance;
        final oldAttendance = change["old_attendance"] as Attendance?;

        if (oldAttendance != null) {
          final existingIndex = localAttendances.indexWhere(
            (a) => a.attendances_id == oldAttendance.attendances_id,
          );
          if (existingIndex != -1) {
            localAttendances[existingIndex] = newAttendance;
          }
        } else {
          localAttendances.add(newAttendance);
        }
        savedCount++;

        _attendanceQueue.removeWhere(
          (q) =>
              q.attendance.student_id == newAttendance.student_id &&
              q.attendance.groups_id == selectedGroup.groups_id &&
              q.attendance.attendance_date.startsWith(formattedDate),
        );

        _attendanceQueue.add(
          QueuedAttendance(
            localId: newAttendance.attendances_id,
            attendance: newAttendance,
            batchId: batchId,
            createdAt: DateTime.now(),
          ),
        );

        _pendingChanges[newAttendance.attendances_id] = newAttendance;
      }

      await _localStorage.saveAttendances(localAttendances);
      await _saveQueueToStorage();

      print("📦 Kuyruk boyutu: ${_attendanceQueue.length}");

      if (!_syncController.isClosed && !_isDisposed) {
        _syncController.add(localAttendances);
      }

      // 🔥🔥🔥 İNTERNET KONTROLÜNÜ GÜNCELLE - DÜZELTİLDİ
      final connectivityResult = await _connectivity.checkConnectivity();
      _lastConnectivity = connectivityResult.isNotEmpty
          ? connectivityResult.first
          : ConnectivityResult.none;
      print("🌐 Güncel internet durumu: $_lastConnectivity");

      if (_lastConnectivity != ConnectivityResult.none &&
          changedItems.isNotEmpty) {
        print("🌐 İnternet var, hemen senkronize ediliyor...");
        unawaited(_processQueue());
      } else if (changedItems.isNotEmpty) {
        print("📡 İnternet yok, kuyruğa alındı.");
      }

      return {
        'success': true,
        'savedCount': savedCount,
        'batchId': batchId,
        'changedCount': changedItems.length,
      };
    } catch (e) {
      print("❌ Lokal kayıt hatası: $e");
      return {'success': false, 'savedCount': 0, 'error': e.toString()};
    }
  }

  Future<List<Attendance>> getLocalAttendances(
    String groupId,
    DateTime date,
  ) async {
    await init();
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final allAttendances = _localStorage.getAttendances();

    return allAttendances.where((a) {
      final attDate = a.attendance_date.split('T')[0];
      return attDate == formattedDate && a.groups_id == groupId;
    }).toList();
  }

  // 🔥 SENKRONİZASYON - DÜZELTİLDİ
  Future<void> _processQueue() async {
    if (_isProcessing || _isDisposed) return;
    if (_attendanceQueue.isEmpty) return;

    _isProcessing = true;

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final connectivity = connectivityResult.isNotEmpty
          ? connectivityResult.first
          : ConnectivityResult.none;

      if (connectivity == ConnectivityResult.none) {
        print("📡 İnternet yok, yoklama senkronizasyonu ertelendi.");
        _isProcessing = false;
        return;
      }

      print(
        "🌐 İnternet var, ${_attendanceQueue.length} yoklama senkronize ediliyor...",
      );

      final List<QueuedAttendance> queueSnapshot = List.from(_attendanceQueue);
      final List<QueuedAttendance> succeeded = [];

      // 🔥 Grup bazlı toplu gönderim
      final Map<String, List<QueuedAttendance>> groupedByBatch = {};
      for (var q in queueSnapshot) {
        groupedByBatch.putIfAbsent(q.batchId, () => []).add(q);
      }

      for (var batchId in groupedByBatch.keys) {
        final batch = groupedByBatch[batchId]!;
        print(
          "📦 Batch $batchId: ${batch.length} kayıt senkronize ediliyor...",
        );

        bool allSuccess = true;
        for (var queued in batch) {
          try {
            // 🔥 VERİYİ GÖNDER
            print(
              "📤 Gönderiliyor: student_id=${queued.attendance.student_id}, status=${queued.attendance.status}",
            );

            final success = await GoogleSheetService.saveAttendance(
              queued.attendance,
            ).timeout(const Duration(seconds: 10));

            if (success) {
              succeeded.add(queued);
              _pendingChanges.remove(queued.attendance.attendances_id);
              _syncedChanges[queued.attendance.attendances_id] =
                  queued.attendance;
              print("  ✅ ${queued.attendance.student_id} senkronize edildi");
            } else {
              allSuccess = false;
              print("  ❌ ${queued.attendance.student_id} senkronize edilemedi");
            }
          } catch (e) {
            allSuccess = false;
            print("  ❌ ${queued.attendance.student_id} hatası: $e");
          }
        }

        if (allSuccess) {
          print("✅ Batch $batchId tamamen senkronize edildi!");
        } else {
          print("⚠️ Batch $batchId kısmen senkronize edildi.");
        }
      }

      // Başarılı olanları kuyruktan temizle
      _attendanceQueue.removeWhere((q) => succeeded.contains(q));
      await _saveQueueToStorage();

      if (succeeded.isNotEmpty) {
        GoogleSheetService.invalidateCache('attendances');

        // 🔥 SENKRONİZASYON TAMAMLANDI - GÜNCEL VERİLERİ ÇEK
        await _refreshDataFromCloud();

        _syncController.add(_localStorage.getAttendances());
        print(
          "✅ ${succeeded.length} yoklama senkronize edildi. Kuyrukta ${_attendanceQueue.length} işlem kaldı.",
        );
      }
    } catch (e) {
      print("❌ _processQueue hatası: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // 🔥 YENİ: Google Sheets'ten sadece güncel yoklamaları çek
  Future<void> _refreshDataFromCloud() async {
    try {
      print("🔄 Google Sheets'ten güncel yoklamalar çekiliyor...");

      final attendancesData = await GoogleSheetService.fetchTable(
        'attendances',
      );

      if (attendancesData.isNotEmpty) {
        final updatedAttendances = attendancesData
            .map((json) => Attendance.fromJson(json))
            .toList();
        await _localStorage.saveAttendances(updatedAttendances);
        print("✅ ${updatedAttendances.length} yoklama güncellendi");
      }

      print("✅ Yoklama verileri başarıyla güncellendi!");
    } catch (e) {
      print("❌ Yoklama verileri çekilirken hata: $e");
    }
  }

  void _startPeriodicSync() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
      } else if (_attendanceQueue.isNotEmpty) {
        print("⏰ Periyodik yoklama senkronizasyonu çalışıyor...");
        _processQueue();
      }
    });
  }

  Future<void> _saveQueueToStorage() async {
    if (_isDisposed) return;
    final queueJson = _attendanceQueue
        .map(
          (q) => {
            'localId': q.localId,
            'attendance': q.attendance.toJson(),
            'batchId': q.batchId,
            'createdAt': q.createdAt.toIso8601String(),
          },
        )
        .toList();
    await _localStorage.saveData('attendance_queue', queueJson);
  }

  Future<void> _loadQueueFromStorage() async {
    if (_isDisposed) return;
    try {
      final queueJson = _localStorage.getData('attendance_queue');
      List queueList = [];
      if (queueJson is List)
        queueList = queueJson;
      else if (queueJson != null) {
        final decoded = json.decode(queueJson.toString());
        if (decoded is List) queueList = decoded;
      }

      for (var item in queueList) {
        final typedItem = item is Map ? Map<String, dynamic>.from(item) : {};
        if (typedItem.isEmpty) continue;
        final attendanceMap = Map<String, dynamic>.from(
          typedItem['attendance'],
        );

        _attendanceQueue.add(
          QueuedAttendance(
            localId: typedItem['localId'] as String,
            attendance: Attendance.fromJson(attendanceMap),
            batchId: typedItem['batchId'] as String,
            createdAt: DateTime.parse(typedItem['createdAt'] as String),
          ),
        );
      }
    } catch (e) {
      print("❌ Kuyruk yükleme hatası: $e");
    }
  }

  void dispose() {
    _isDisposed = true;
    if (!_syncController.isClosed) _syncController.close();
  }

  void reset() {
    _isDisposed = false;
    _isInitialized = false;
    _isProcessing = false;
    _attendanceQueue.clear();
    _pendingChanges.clear();
    _syncedChanges.clear();
    print("🔄 OfflineAttendanceService resetlendi");
  }
}

class QueuedAttendance {
  final String localId;
  final Attendance attendance;
  final String batchId;
  final DateTime createdAt;
  QueuedAttendance({
    required this.localId,
    required this.attendance,
    required this.batchId,
    required this.createdAt,
  });
}
