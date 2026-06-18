import 'dart:async';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';

class OfflinePaymentService {
  static final OfflinePaymentService _instance =
      OfflinePaymentService._internal();
  factory OfflinePaymentService() => _instance;
  OfflinePaymentService._internal();

  late final LocalStorageService _localStorage;
  late Box _queueBox;
  final List<QueuedPayment> _paymentQueue = [];
  final StreamController<void> _paymentSyncController =
      StreamController.broadcast();
  Stream<void> get onPaymentSynced => _paymentSyncController.stream;

  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _localStorage = LocalStorageService();
    await _localStorage.init();
    _queueBox = await Hive.openBox('payment_queue_box');
    await _loadQueueFromStorage();
    _startPeriodicSync();
    _isInitialized = true;
    print(
      "✅ OfflinePaymentService başlatıldı, kuyrukta ${_paymentQueue.length} işlem",
    );
  }

  Future<bool> savePayment(Payment payment) async {
    if (_isDisposed) return false;

    try {
      final localPayments = _localStorage.getPayments();
      final newPayment = Payment(
        payments_id: _generateLocalId(),
        student_id: payment.student_id,
        groups_id: payment.groups_id,
        recorded_by: payment.recorded_by,
        amount: payment.amount,
        due_date: payment.due_date,
        paid_date: payment.paid_date,
        status: payment.status,
        payment_method: payment.payment_method,
        note: payment.note,
      );

      localPayments.add(newPayment);
      await _localStorage.savePayments(localPayments);

      _paymentQueue.add(
        QueuedPayment(
          localId: newPayment.payments_id,
          payment: newPayment,
          createdAt: DateTime.now(),
        ),
      );
      await _saveQueueToStorage();

      _paymentSyncController.add(null);
      unawaited(_processQueue());

      print("✅ Ödeme LOKAL'e kaydedildi: ${payment.amount} TL");
      return true;
    } catch (e) {
      print("❌ Lokal kayıt hatası: $e");
      return false;
    }
  }

  /// 🔥 TOPLU ÖDEME KAYDET
  Future<bool> savePaymentsBatch(List<Payment> payments) async {
    if (_isDisposed) return false;

    try {
      final localPayments = _localStorage.getPayments();

      for (var payment in payments) {
        final newPayment = Payment(
          payments_id: _generateLocalId(),
          student_id: payment.student_id,
          groups_id: payment.groups_id,
          recorded_by: payment.recorded_by,
          amount: payment.amount,
          due_date: payment.due_date,
          paid_date: payment.paid_date,
          status: payment.status,
          payment_method: payment.payment_method,
          note: payment.note,
        );

        localPayments.add(newPayment);

        _paymentQueue.add(
          QueuedPayment(
            localId: newPayment.payments_id,
            payment: newPayment,
            createdAt: DateTime.now(),
          ),
        );
      }

      await _localStorage.savePayments(localPayments);
      await _saveQueueToStorage();

      _paymentSyncController.add(null);
      unawaited(_processQueue());

      print("✅ ${payments.length} ödeme LOKAL'e kaydedildi");
      return true;
    } catch (e) {
      print("❌ Toplu kayıt hatası: $e");
      return false;
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    if (_isDisposed) return;

    _isProcessing = true;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      print(
        "⚠️ İnternet yok, sync bekletiliyor... (${_paymentQueue.length} işlem)",
      );
      _isProcessing = false;
      return;
    }

    if (_paymentQueue.isEmpty) {
      _isProcessing = false;
      return;
    }

    final queueSnapshot = List<QueuedPayment>.from(_paymentQueue);
    final List<QueuedPayment> succeeded = [];

    for (var queued in queueSnapshot) {
      try {
        final success = await GoogleSheetService.addPayment(
          queued.payment,
        ).timeout(const Duration(seconds: 10));

        if (success) {
          succeeded.add(queued);
          print("  ✅ Ödeme senkronize edildi: ${queued.payment.amount} TL");
        }
      } catch (e) {
        print("  ❌ Sync hatası: $e");
      }
    }

    _paymentQueue.removeWhere((q) => succeeded.contains(q));
    await _saveQueueToStorage();

    if (succeeded.isNotEmpty) {
      GoogleSheetService.invalidateCache('payments');
    }

    _isProcessing = false;
    print("✅ Senkronizasyon tamamlandı, ${_paymentQueue.length} işlem kaldı");
  }

  void _startPeriodicSync() {
    Timer.periodic(const Duration(minutes: 2), (timer) {
      if (_isDisposed)
        timer.cancel();
      else
        _processQueue();
    });
  }

  Future<void> _saveQueueToStorage() async {
    if (_isDisposed) return;

    try {
      final queueJson = _paymentQueue
          .map(
            (q) => {
              'localId': q.localId,
              'payment': q.payment.toJson(),
              'createdAt': q.createdAt.toIso8601String(),
            },
          )
          .toList();
      await _queueBox.put('queue', queueJson);
      print("💾 Ödeme kuyruğu kaydedildi: ${_paymentQueue.length} öğe");
    } catch (e) {
      print("❌ Kuyruk kaydetme hatası: $e");
    }
  }

  Future<void> _loadQueueFromStorage() async {
    if (_isDisposed) return;

    try {
      final queueJson = _queueBox.get('queue');
      if (queueJson != null && queueJson is List) {
        for (var item in queueJson) {
          try {
            Map<String, dynamic> typedItem;
            if (item is Map<String, dynamic>) {
              typedItem = item;
            } else if (item is Map<dynamic, dynamic>) {
              typedItem = Map<String, dynamic>.from(item);
            } else {
              continue;
            }

            Map<String, dynamic> paymentMap;
            final paymentData = typedItem['payment'];
            if (paymentData is Map<String, dynamic>) {
              paymentMap = paymentData;
            } else if (paymentData is Map<dynamic, dynamic>) {
              paymentMap = Map<String, dynamic>.from(paymentData);
            } else {
              continue;
            }

            _paymentQueue.add(
              QueuedPayment(
                localId: typedItem['localId'] as String,
                payment: Payment.fromJson(paymentMap),
                createdAt: DateTime.parse(typedItem['createdAt'] as String),
              ),
            );
          } catch (e) {
            print("❌ Queue item yüklenirken hata: $e");
          }
        }
        print("📦 Ödeme kuyruğundan ${_paymentQueue.length} öğe yüklendi");
      }
    } catch (e) {
      print("❌ Kuyruk yükleme hatası: $e");
    }
  }

  String _generateLocalId() {
    return "local_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}";
  }

  int get pendingSyncCount => _paymentQueue.length;

  void dispose() {
    _isDisposed = true;
    _paymentSyncController.close();
    _queueBox.close();
  }
}

class QueuedPayment {
  final String localId;
  final Payment payment;
  final DateTime createdAt;

  QueuedPayment({
    required this.localId,
    required this.payment,
    required this.createdAt,
  });
}
