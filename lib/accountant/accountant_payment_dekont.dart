import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';

class PaymentScreen extends StatefulWidget {
  final Users student;
  const PaymentScreen({Key? key, required this.student}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  String selectedMethod = "Nakit";
  DateTime selectedPaymentDate = DateTime.now();
  bool isProcessing = false;

  late Future<Map<String, dynamic>> _allDataFuture;

  int _selectedYear = DateTime.now().year;
  late int _previousYear;
  late int _currentYear;

  DateTime? _selectedMissingMonth;

  // GEÇMİŞ BORÇ PANELİ açık/kapalı
  bool _historicalDebtExpanded = false;

  List<Group> studentGroups = [];
  List<Payment> paymentHistory = [];
  String? selectedGroupId;
  String selectedGroupName = "";
  double monthlyFee = 0;

  // 🔥 Ücret güncelleme geçmişi
  List<Map<String, dynamic>> _feeUpdateHistory = [];

  final List<String> paymentMethods = [
    "Nakit",
    "Kredi Kartı",
    "Havale/EFT",
    "Mail Order",
  ];

  // TEMA
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _teal = Color(0xFF0D9488);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF97316);
  static const Color _green = Color(0xFF22C55E);
  static const Color _textSub = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime.now().year;
    _previousYear = _currentYear - 1;
    _selectedYear = _currentYear;
    _allDataFuture = _loadAllDataParallel();
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  // =========================================================================
  // YARDIMCI FONKSİYONLAR
  // =========================================================================
  int _getCurrentYear() => DateTime.now().year;
  int _getCurrentMonth() => DateTime.now().month;

  int _getStudentRegistrationYear() {
    final createdDate = _parseDateString(widget.student.created_at);
    if (createdDate != null) {
      return createdDate.year;
    }
    return _currentYear;
  }

  int _getStudentRegistrationMonth() {
    final createdDate = _parseDateString(widget.student.created_at);
    if (createdDate != null) {
      return createdDate.month;
    }
    return 1;
  }

  DateTime? _parseDateString(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      if (dateStr.contains('T')) return DateTime.parse(dateStr);
      if (dateStr.contains('-') && dateStr.length >= 10) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final d = int.tryParse(parts[2]);
          if (y != null && m != null && d != null) return DateTime(y, m, d);
        }
      }
      return DateTime.tryParse(dateStr);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(String d) {
    if (d.isEmpty) return "Belirsiz";
    try {
      if (d.contains('T')) d = d.split('T')[0];
      final p = d.split('-');
      if (p.length == 3) return "${p[2]}/${p[1]}/${p[0]}";
    } catch (_) {}
    return d;
  }

  String _formatDisplayDate(DateTime d) => "${d.day}/${d.month}/${d.year}";

  String _formatMonthYear(String my) {
    if (my.isEmpty) return my;
    try {
      if (my.contains('-') && my.length >= 7) {
        final p = my.split('-');
        const months = [
          "Ocak",
          "Şubat",
          "Mart",
          "Nisan",
          "Mayıs",
          "Haziran",
          "Temmuz",
          "Ağustos",
          "Eylül",
          "Ekim",
          "Kasım",
          "Aralık",
        ];
        return "${months[int.parse(p[1]) - 1]} ${p[0]}";
      }
    } catch (_) {}
    return my;
  }

  int? _getYearFromDueDate(String d) {
    if (d.isEmpty) return null;
    if (d.contains('-') && d.length >= 10)
      return int.tryParse(d.substring(0, 4));
    final m = RegExp(r'\d{4}').firstMatch(d);
    return m != null ? int.parse(m.group(0)!) : null;
  }

  int? _getMonthFromDueDate(String d) {
    if (d.isEmpty) return null;
    if (d.contains('-') && d.length >= 10)
      return int.tryParse(d.substring(5, 7));
    const monthMap = {
      'Ocak': 1,
      'Şubat': 2,
      'Mart': 3,
      'Nisan': 4,
      'Mayıs': 5,
      'Haziran': 6,
      'Temmuz': 7,
      'Ağustos': 8,
      'Eylül': 9,
      'Ekim': 10,
      'Kasım': 11,
      'Aralık': 12,
    };
    for (var e in monthMap.entries) {
      if (d.contains(e.key)) return e.value;
    }
    return null;
  }

  // =========================================================================
  // 🔥 AYA ÖZEL ÜCRET HESAPLAMA (GÜNCELLEME TARİHİNE GÖRE)
  // =========================================================================
  double _getStudentMonthlyFeeForMonth(int year, int month) {
    final registrationYear = _getStudentRegistrationYear();
    final registrationMonth = _getStudentRegistrationMonth();

    // Kayıt olmadan önceki aylar için ücret 0
    if (year < registrationYear ||
        (year == registrationYear && month < registrationMonth)) {
      return 0;
    }

    // Varsayılan ücret (en son güncellenen veya başlangıç ücreti)
    double feeForMonth = monthlyFee;

    // Ücret güncelleme geçmişini tarihe göre sırala (eskiden yeniye)
    final updates = List<Map<String, dynamic>>.from(_feeUpdateHistory);
    updates.sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );

    // İlgili aydan önceki en son güncellemeyi bul
    DateTime targetDate = DateTime(year, month, 1);
    double lastFee = monthlyFee;

    for (var update in updates) {
      final updateDate = update['date'] as DateTime;
      if (updateDate.isBefore(targetDate) ||
          (updateDate.year == year && updateDate.month == month)) {
        lastFee = update['fee'] as double;
      }
    }

    return lastFee;
  }

  // 🔥 Yılın beklenen toplam tahsilatını hesapla (aylık ücretler toplamı)
  double _getExpectedAnnualForYear(int year) {
    double total = 0;
    for (var month in _getMonthsOfYear(year)) {
      total += _getStudentMonthlyFeeForMonth(year, month.month);
    }
    return total;
  }

  // =========================================================================
  // HESAPLAMALAR
  // =========================================================================
  List<Payment> _getPaymentsForYear(int year) => paymentHistory
      .where(
        (p) => _getYearFromDueDate(p.due_date) == year && p.status == "paid",
      )
      .toList();

  List<DateTime> _getMonthsOfYear(int year) {
    final now = DateTime.now();
    final registrationYear = _getStudentRegistrationYear();
    final registrationMonth = _getStudentRegistrationMonth();

    List<DateTime> months = [];
    for (int m = 1; m <= 12; m++) {
      final md = DateTime(year, m, 1);

      if (year == registrationYear) {
        if (m < registrationMonth) {
          continue;
        }
      }

      if (year < _currentYear ||
          (year == _currentYear &&
              md.isBefore(DateTime(now.year, now.month + 1, 1)))) {
        months.add(md);
      }
    }
    return months;
  }

  double _getPaidAmountForExactMonth(int year, int month) {
    double total = 0;
    for (var p in _getPaymentsForYear(year)) {
      if (_getYearFromDueDate(p.due_date) == year &&
          _getMonthFromDueDate(p.due_date) == month) {
        total += double.tryParse(p.amount) ?? 0;
      }
    }
    return total;
  }

  List<Map<String, dynamic>> _getMissingPaymentsForYear(int year) {
    final now = DateTime.now();
    final currentMonth = _getCurrentMonth();
    final registrationYear = _getStudentRegistrationYear();
    final registrationMonth = _getStudentRegistrationMonth();

    List<Map<String, dynamic>> result = [];

    for (var month in _getMonthsOfYear(year)) {
      if (year == registrationYear && month.month < registrationMonth) {
        continue;
      }

      final monthlyFeeForThisMonth = _getStudentMonthlyFeeForMonth(
        year,
        month.month,
      );
      if (monthlyFeeForThisMonth == 0) continue;

      final paid = _getPaidAmountForExactMonth(year, month.month);
      final remaining = monthlyFeeForThisMonth - paid;
      if (remaining <= 0.01) continue;

      bool isMonthOver = false;
      if (year < _currentYear) {
        isMonthOver = true;
      } else if (year == _currentYear) {
        if (month.month < currentMonth) {
          isMonthOver = true;
        } else if (month.month == currentMonth) {
          isMonthOver = now.isAfter(DateTime(year, month.month + 1, 0));
        }
      }

      result.add({
        'date': month,
        'required': monthlyFeeForThisMonth,
        'paid': paid,
        'remaining': remaining,
        'monthName': _formatMonthYear(
          "${year}-${month.month.toString().padLeft(2, '0')}",
        ),
        'isMonthOver': isMonthOver,
        'isCurrentMonth': (year == _currentYear && month.month == currentMonth),
      });
    }

    result.sort((a, b) {
      if (a['isMonthOver'] && !b['isMonthOver']) return -1;
      if (!a['isMonthOver'] && b['isMonthOver']) return 1;
      return (a['date'] as DateTime).compareTo(b['date'] as DateTime);
    });
    return result;
  }

  double _getTotalReceivedForYear(int year) => _getPaymentsForYear(
    year,
  ).fold(0, (s, p) => s + (double.tryParse(p.amount) ?? 0));

  List<Map<String, dynamic>> _getAllHistoricalDebts() {
    final List<Map<String, dynamic>> result = [];

    final registrationYear = _getStudentRegistrationYear();
    final startYear = registrationYear;
    final endYear = _currentYear - 1;

    for (int year = startYear; year <= endYear; year++) {
      final missing = _getMissingPaymentsForYear(year);
      if (missing.isEmpty) continue;
      final totalDebt = missing.fold<double>(
        0,
        (s, m) => s + (m['remaining'] as double),
      );
      result.add({'year': year, 'months': missing, 'totalDebt': totalDebt});
    }
    return result;
  }

  List<Map<String, dynamic>> _getMonthlyPaymentStatusForYear(int year) {
    final now = DateTime.now();
    final currentMonth = _getCurrentMonth();

    return _getMonthsOfYear(year)
        .map((month) {
          final monthlyFeeForThisMonth = _getStudentMonthlyFeeForMonth(
            year,
            month.month,
          );
          if (monthlyFeeForThisMonth == 0) return null;

          final paid = _getPaidAmountForExactMonth(year, month.month);
          final remaining = monthlyFeeForThisMonth - paid;
          final isPaid = remaining <= 0.01;

          String status;
          if (isPaid) {
            status = "paid";
          } else {
            bool over = false;
            if (year < _currentYear)
              over = true;
            else if (month.month < currentMonth)
              over = true;
            else if (month.month == currentMonth)
              over = now.isAfter(DateTime(year, month.month + 1, 0));
            status = over ? "overdue" : "current";
          }

          return {
            'date': month,
            'required': monthlyFeeForThisMonth,
            'paid': paid,
            'remaining': remaining > 0 ? remaining : 0,
            'isFullyPaid': isPaid,
            'monthName': _formatMonthYear(
              "${year}-${month.month.toString().padLeft(2, '0')}",
            ),
            'status': status,
          };
        })
        .where((item) => item != null)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  // =========================================================================
  // PARALEL VERİ YÜKLEME
  // =========================================================================
  Future<Map<String, dynamic>> _loadAllDataParallel() async {
    final stopwatch = Stopwatch()..start();

    try {
      final results = await Future.wait([
        GoogleSheetService.getGroupsCached(),
        GoogleSheetService.getGroupStudentsCached(),
        GoogleSheetService.getUsersCached(),
        GoogleSheetService.getPaymentsCached(),
      ]);

      final allGroups = results[0] as List<Group>;
      final allRelations = results[1] as List<GroupStudent>;
      final allUsers = results[2] as List<Users>;
      final allPayments = results[3] as List<Payment>;

      stopwatch.stop();
      print(
        "⏱️ PaymentScreen verileri PARALEL olarak ${stopwatch.elapsedMilliseconds}ms'de yüklendi",
      );

      final current = allUsers.firstWhere(
        (u) => u.app == widget.student.app,
        orElse: () => widget.student,
      );
      monthlyFee = double.tryParse(current.amount) ?? 0;

      final groupIds = allRelations
          .where(
            (r) =>
                r.student_id == widget.student.app &&
                r.is_active.toString().toUpperCase() == "TRUE",
          )
          .map((r) => r.groups_id)
          .toList();

      studentGroups = allGroups
          .where((g) => groupIds.contains(g.groups_id))
          .toList();
      if (studentGroups.isNotEmpty) {
        selectedGroupId = studentGroups.first.groups_id;
        selectedGroupName = studentGroups.first.name;
      }

      paymentHistory =
          allPayments
              .where(
                (p) => p.student_id == widget.student.app && p.status == "paid",
              )
              .toList()
            ..sort((a, b) => b.paid_date.compareTo(a.paid_date));

      // 🔥 Ücret güncelleme geçmişini paymentHistory'dan çek
      _feeUpdateHistory.clear();
      for (var payment in paymentHistory) {
        if (payment.note.contains("FEE_UPDATE:")) {
          final match = RegExp(r'FEE_UPDATE:\s*(\d+)').firstMatch(payment.note);
          if (match != null) {
            final fee = double.tryParse(match.group(1)!) ?? 0;
            final updateDate = _parseDateString(payment.paid_date);
            if (updateDate != null && fee > 0) {
              _feeUpdateHistory.add({'date': updateDate, 'fee': fee});
            }
          }
        }
      }

      // Başlangıç ücretini de ekle (kayıt tarihinden itibaren)
      final registrationDate = _parseDateString(widget.student.created_at);
      if (registrationDate != null && monthlyFee > 0) {
        _feeUpdateHistory.add({'date': registrationDate, 'fee': monthlyFee});
      }

      // Tarihe göre sırala
      _feeUpdateHistory.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
      );

      return {
        'monthlyFee': monthlyFee,
        'currentYear': _currentYear,
        'previousYear': _previousYear,
      };
    } catch (e) {
      print("❌ PaymentScreen veri yükleme hatası: $e");
      return {
        'monthlyFee': 0.0,
        'currentYear': _currentYear,
        'previousYear': _previousYear,
      };
    }
  }

  // =========================================================================
  // ÖDEME İŞLEMLERİ
  // =========================================================================
  Future<void> _updateMonthlyFee() async {
    final ctrl = TextEditingController(text: monthlyFee.toStringAsFixed(0));
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aylık Ücreti Güncelle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Yeni Aylık Ücret (TL)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Güncelleme bu aydan itibaren geçerli olacaktır.\nGeçmiş aylar eski ücret üzerinden hesaplanır.",
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newFee = double.tryParse(ctrl.text) ?? 0;
              if (newFee > 0 && newFee != monthlyFee) {
                setState(() => isProcessing = true);

                final ok = await GoogleSheetService.updateUserAmount(
                  widget.student.app,
                  newFee,
                );

                if (ok) {
                  final now = DateTime.now();
                  final currentMonth =
                      "${now.year}-${now.month.toString().padLeft(2, '0')}-01";
                  final currentDate =
                      "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

                  await GoogleSheetService.addPayment(
                    Payment(
                      payments_id: "",
                      student_id: widget.student.app,
                      groups_id: selectedGroupId ?? "",
                      recorded_by: "Admin",
                      amount: "0",
                      due_date: currentMonth,
                      paid_date: currentDate,
                      status: "fee_update",
                      payment_method: "Sistem",
                      note: "FEE_UPDATE: $newFee (Eski: $monthlyFee TL)",
                    ),
                  );

                  setState(() {
                    monthlyFee = newFee;
                    _allDataFuture = _loadAllDataParallel();
                  });
                  _showSnackBar(
                    'Aylık ücret güncellendi: ${newFee.toStringAsFixed(0)} TL\nBu aydan itibaren geçerlidir.',
                  );
                } else {
                  _showSnackBar('Ücret güncellenemedi!', isError: true);
                }
                setState(() => isProcessing = false);
                Navigator.pop(context);
              } else if (newFee == monthlyFee) {
                Navigator.pop(context);
              } else {
                _showSnackBar('Geçerli bir tutar girin!', isError: true);
              }
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPaymentDateForMissingMonth(DateTime missingMonth) async {
    final first = DateTime(missingMonth.year, missingMonth.month, 1);
    final last = DateTime(missingMonth.year, missingMonth.month + 1, 0);
    final picked = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null)
      setState(() {
        selectedPaymentDate = picked;
        _selectedMissingMonth = missingMonth;
      });
  }

  Future<void> _processPaymentForMissingMonth(
    DateTime missingMonth,
    double requiredAmount,
  ) async {
    if (amountController.text.isEmpty) {
      _showSnackBar("Lütfen tutar girin!", isError: true);
      return;
    }
    if (selectedGroupId == null) {
      _showSnackBar("Grup bulunamadı!", isError: true);
      return;
    }

    final tutar = double.tryParse(amountController.text) ?? 0;
    if (tutar > requiredAmount) {
      _showSnackBar(
        "Maksimum ${requiredAmount.toStringAsFixed(0)} TL girebilirsiniz!",
        isError: true,
      );
      return;
    }

    setState(() => isProcessing = true);

    final payMonth =
        "${missingMonth.year}-${missingMonth.month.toString().padLeft(2, '0')}-01";
    final payDate =
        "${selectedPaymentDate.year}-${selectedPaymentDate.month.toString().padLeft(2, '0')}-${selectedPaymentDate.day.toString().padLeft(2, '0')}";

    final ok = await GoogleSheetService.addPayment(
      Payment(
        payments_id: "",
        student_id: widget.student.app,
        groups_id: selectedGroupId!,
        recorded_by: "Admin",
        amount: amountController.text,
        due_date: payMonth,
        paid_date: payDate,
        status: "paid",
        payment_method: selectedMethod,
        note: noteController.text.trim(),
      ),
    );

    setState(() => isProcessing = false);

    if (ok) {
      _allDataFuture = _loadAllDataParallel();
      setState(() {
        _selectedMissingMonth = null;
        amountController.clear();
        noteController.clear();
      });
      _showSnackBar("${_formatMonthYear(payMonth)} ödemesi kaydedildi!");
    } else {
      _showSnackBar("Ödeme kaydedilemedi!", isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? _red : _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showPaymentDetailPopup(Payment p) {
    final month = _getMonthFromDueDate(p.due_date);
    final year = _getYearFromDueDate(p.due_date);
    final monthName = (month != null && year != null)
        ? _formatMonthYear("$year-${month.toString().padLeft(2, '0')}")
        : "—";

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.receipt_long, color: _teal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Ödeme Detayı",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          monthName,
                          style: TextStyle(color: _textSub, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: _textSub),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _popupRow(
                Icons.attach_money,
                "Tutar",
                "${double.tryParse(p.amount)?.toStringAsFixed(0) ?? p.amount} TL",
                _green,
              ),
              _popupRow(
                Icons.calendar_today,
                "Ödeme Tarihi",
                _formatDate(p.paid_date),
                _teal,
              ),
              _popupRow(Icons.date_range, "Ay", monthName, _teal),
              _popupRow(
                p.payment_method == "Nakit"
                    ? Icons.money
                    : p.payment_method == "Kredi Kartı"
                    ? Icons.credit_card
                    : Icons.account_balance,
                "Yöntem",
                p.payment_method,
                _orange,
              ),
              if (p.note.isNotEmpty && !p.note.contains("FEE_UPDATE:"))
                _popupRow(Icons.note_alt_outlined, "Not", p.note, _textSub),
              if (p.note.contains("FEE_UPDATE:"))
                _popupRow(Icons.update, "Ücret Güncelleme", p.note, _teal),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Kapat",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _popupRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: _textSub)),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          "Ödeme İşlemleri",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: _surface,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _allDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D9488)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text("Hata: ${snapshot.error}"),
                  ElevatedButton(
                    onPressed: () =>
                        setState(() => _allDataFuture = _loadAllDataParallel()),
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            );
          }

          final totalReceived = _getTotalReceivedForYear(_selectedYear);
          final expectedAnnual = _getExpectedAnnualForYear(_selectedYear);
          final missingPayments = _getMissingPaymentsForYear(_selectedYear);
          final monthlyStatus = _getMonthlyPaymentStatusForYear(_selectedYear);
          final historicalDebts = _getAllHistoricalDebts();
          final registrationYear = _getStudentRegistrationYear();

          double collectionRate = expectedAnnual > 0
              ? (totalReceived / expectedAnnual * 100).clamp(0.0, 100.0)
              : 0;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: _surface,
                child: Row(
                  children: [
                    _buildYearButton(_previousYear),
                    const SizedBox(width: 12),
                    _buildYearButton(_currentYear),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStudentCard(),
                      const SizedBox(height: 12),
                      _buildYearlyStatsCard(
                        _selectedYear,
                        totalReceived,
                        expectedAnnual,
                        collectionRate,
                      ),
                      const SizedBox(height: 12),
                      if (historicalDebts.isNotEmpty)
                        _buildHistoricalDebtPanel(
                          historicalDebts,
                          registrationYear,
                        ),
                      const SizedBox(height: 12),
                      if (monthlyStatus.isNotEmpty)
                        _buildMonthlyPaymentStatusCard(
                          monthlyStatus,
                          _selectedYear,
                        ),
                      const SizedBox(height: 12),
                      if (missingPayments.isNotEmpty)
                        _buildMissingPaymentsCard(missingPayments),
                      const SizedBox(height: 12),
                      _buildPaymentFormCard(),
                      const SizedBox(height: 12),
                      _buildPaymentHistoryCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // GEÇMİŞ YIL BORÇ PANELİ
  // =========================================================================
  Widget _buildHistoricalDebtPanel(
    List<Map<String, dynamic>> debts,
    int registrationYear,
  ) {
    final totalDebt = debts.fold<double>(
      0,
      (s, d) => s + (d['totalDebt'] as double),
    );
    final firstYear = debts.first['year'] as int;
    final lastYear = debts.last['year'] as int;
    final yearRange = firstYear == lastYear
        ? "$firstYear"
        : "$firstYear–$lastYear";

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _red.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(
              () => _historicalDebtExpanded = !_historicalDebtExpanded,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.05),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(_historicalDebtExpanded ? 0 : 20),
                  bottomRight: Radius.circular(
                    _historicalDebtExpanded ? 0 : 20,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.history, color: _red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Geçmiş Yıl Borçları",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          "Kayıt: $registrationYear • $yearRange",
                          style: TextStyle(color: _textSub, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${totalDebt.toStringAsFixed(0)} TL",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _historicalDebtExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _red,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: debts.map((debt) {
                      final year = debt['year'] as int;
                      final months =
                          debt['months'] as List<Map<String, dynamic>>;
                      final yDebt = debt['totalDebt'] as double;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _red.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _red.withOpacity(0.08),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: _red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "$year Yılı",
                                    style: TextStyle(
                                      color: _red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    "${yDebt.toStringAsFixed(0)} TL borç",
                                    style: TextStyle(
                                      color: _red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: months.map((m) {
                                  final remaining = m['remaining'] as double;
                                  final paid = m['paid'] as double;
                                  final required = m['required'] as double;
                                  final pct = required > 0
                                      ? (paid / required).clamp(0.0, 1.0)
                                      : 0.0;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _red.withOpacity(0.15),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              size: 14,
                                              color: _red,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              m['monthName'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _red.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                "${remaining.toStringAsFixed(0)} TL kalan",
                                                style: TextStyle(
                                                  color: _red,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (paid > 0) ...[
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: pct,
                                              backgroundColor: _red.withOpacity(
                                                0.1,
                                              ),
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    _orange,
                                                  ),
                                              minHeight: 4,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              "${paid.toStringAsFixed(0)} / ${required.toStringAsFixed(0)} TL ödendi",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: _textSub,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            crossFadeState: _historicalDebtExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // DİĞER WIDGET'LAR
  // =========================================================================
  Widget _buildYearButton(int year) {
    final isSel = _selectedYear == year;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedYear = year;
          _selectedMissingMonth = null;
          amountController.clear();
          noteController.clear();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? _teal : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              "$year",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSel ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard() {
    final registrationYear = _getStudentRegistrationYear();
    final registrationDate = _parseDateString(widget.student.created_at);
    final registrationText = registrationDate != null
        ? "Kayıt: ${registrationDate.day}/${registrationDate.month}/$registrationYear"
        : "Kayıt: $registrationYear";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          ClipOval(
            child: widget.student.profile_photo_url.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.student.profile_photo_url,
                    width: 55,
                    height: 55,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const SizedBox(
                      width: 55,
                      height: 55,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => _avatarFallback(),
                  )
                : _avatarFallback(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${widget.student.first_name} ${widget.student.last_name}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.student.email,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 11, color: _teal),
                    const SizedBox(width: 4),
                    Text(
                      registrationText,
                      style: const TextStyle(fontSize: 10),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.group, size: 11, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        selectedGroupName,
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _updateMonthlyFee,
            icon: Icon(Icons.edit, size: 18, color: _teal),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Container(
    width: 55,
    height: 55,
    color: const Color(0xFF0D9488),
    child: Center(
      child: Text(
        widget.student.first_name.isNotEmpty
            ? widget.student.first_name[0].toUpperCase()
            : "?",
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
  );

  Widget _buildYearlyStatsCard(
    int year,
    double totalReceived,
    double expectedAnnual,
    double collectionRate,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _statCol("$year", "YILI"),
          _divider(),
          _statCol("${totalReceived.toStringAsFixed(0)} TL", "TAHSİLAT"),
          _divider(),
          _statCol("${expectedAnnual.toStringAsFixed(0)} TL", "BEKLENEN"),
          _divider(),
          _statCol("${collectionRate.toStringAsFixed(0)}%", "ORAN"),
        ],
      ),
    );
  }

  Widget _statCol(String val, String label) => Expanded(
    child: Column(
      children: [
        Text(
          val,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    ),
  );

  Widget _divider() => Container(width: 1, height: 40, color: Colors.white30);

  Widget _buildMonthlyPaymentStatusCard(
    List<Map<String, dynamic>> monthlyStatus,
    int year,
  ) {
    if (monthlyStatus.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
          ],
        ),
        child: const Center(
          child: Text(
            "Bu yıla ait ödeme dönemi bulunmuyor",
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: _teal),
              const SizedBox(width: 8),
              Text(
                "$year Yılı Aylık Ödeme Durumu",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: monthlyStatus.length,
            itemBuilder: (_, i) {
              final item = monthlyStatus[i];
              final isPaid = item['isFullyPaid'];
              final status = item['status'];
              final requiredFee = item['required'] as double;

              Color bgColor = isPaid
                  ? Colors.green.shade100
                  : status == "current"
                  ? Colors.orange.shade100
                  : Colors.red.shade100;

              return Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item['monthName'],
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${(item['paid'] as double).toStringAsFixed(0)}/${requiredFee.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 9),
                    ),
                    isPaid
                        ? const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green,
                          )
                        : status == "current"
                        ? const Icon(
                            Icons.pending,
                            size: 14,
                            color: Colors.orange,
                          )
                        : const Icon(Icons.cancel, size: 14, color: Colors.red),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMissingPaymentsCard(List<Map<String, dynamic>> missingPayments) {
    if (_selectedMissingMonth != null) {
      final sel = missingPayments.firstWhere(
        (m) =>
            (m['date'] as DateTime).year == _selectedMissingMonth!.year &&
            (m['date'] as DateTime).month == _selectedMissingMonth!.month,
        orElse: () => {},
      );
      if (sel.isNotEmpty) return _buildPaymentFormForMissingMonth(sel);
    }

    final overdue = missingPayments
        .where((m) => m['isMonthOver'] == true)
        .toList();
    final current = missingPayments
        .where((m) => m['isCurrentMonth'] == true && m['isMonthOver'] == false)
        .toList();
    final totalDebt = missingPayments.fold<double>(
      0,
      (s, m) => s + (m['remaining'] as double),
    );

    if (missingPayments.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: _red, size: 20),
              const SizedBox(width: 6),
              const Text(
                "Ödenmemiş Aylar",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${totalDebt.toStringAsFixed(0)} TL",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (overdue.isNotEmpty) ...[
            Text(
              "📅 Geçmiş Aylar (Ödenmesi Zorunlu):",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _red,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: overdue
                  .map(
                    (m) => _buildPaymentButton(
                      m['date'] as DateTime,
                      m['remaining'],
                      m['monthName'],
                      _red,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (current.isNotEmpty) ...[
            Text(
              "📌 Bu Ay (Ödeme Yapılabilir):",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _orange,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: current
                  .map(
                    (m) => _buildPaymentButton(
                      m['date'] as DateTime,
                      m['remaining'],
                      m['monthName'],
                      _orange,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.blue),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Kırmızı ayların ödemesi ZORUNLUDUR. Turuncu ay cari aydır.",
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton(
    DateTime date,
    double remaining,
    String monthName,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => setState(() {
        _selectedMissingMonth = date;
        amountController.clear();
        noteController.clear();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              monthName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${remaining.toStringAsFixed(0)} TL",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentFormForMissingMonth(Map<String, dynamic> missingMonth) {
    final date = missingMonth['date'] as DateTime;
    final remaining = missingMonth['remaining'] as double;
    final requiredAmount = missingMonth['required'] as double;
    final monthName = missingMonth['monthName'] as String;
    final isMonthOver = missingMonth['isMonthOver'] as bool;
    final headerColor = isMonthOver ? _red : _orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: headerColor, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: headerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isMonthOver ? Icons.warning : Icons.pending,
                  color: headerColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$monthName Ödemesi",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Aylık Ücret: ${requiredAmount.toStringAsFixed(0)} TL • Kalan: ${remaining.toStringAsFixed(0)} TL",
                      style: TextStyle(
                        fontSize: 12,
                        color: headerColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _selectedMissingMonth = null;
                  amountController.clear();
                  noteController.clear();
                }),
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _selectPaymentDateForMissingMonth(date),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: _teal, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Ödeme Tarihi: ${_formatDisplayDate(selectedPaymentDate)}",
                    style: const TextStyle(fontSize: 13),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Ödenecek Tutar",
              hintText: "0.00",
              prefixIcon: Icon(Icons.money, color: _teal, size: 18),
              suffixText: "TL",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              helperText: "Maksimum: ${remaining.toStringAsFixed(0)} TL",
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedMethod,
            items: paymentMethods
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Row(
                      children: [
                        Icon(
                          m == "Nakit"
                              ? Icons.money
                              : m == "Kredi Kartı"
                              ? Icons.credit_card
                              : m == "Havale/EFT"
                              ? Icons.account_balance
                              : Icons.qr_code,
                          size: 16,
                          color: _teal,
                        ),
                        const SizedBox(width: 6),
                        Text(m, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => selectedMethod = v!),
            decoration: InputDecoration(
              labelText: "Ödeme Yöntemi",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: "Açıklama (Opsiyonel)",
              prefixIcon: Icon(Icons.note, color: _teal, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () => _processPaymentForMissingMonth(date, remaining),
              style: ElevatedButton.styleFrom(
                backgroundColor: headerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isMonthOver
                          ? "Geçmiş Ay Ödemesini Yap"
                          : "Bu Ayın Ödemesini Yap",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentFormCard() {
    if (monthlyFee == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            Icon(Icons.warning_amber, size: 40, color: Colors.orange),
            SizedBox(height: 8),
            Text(
              "Aylık Ücret Tanımlanmamış",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    if (_selectedMissingMonth != null) return const SizedBox.shrink();

    final currentYear = _getCurrentYear();
    final currentMonth = _getCurrentMonth();
    final registrationYear = _getStudentRegistrationYear();
    final registrationMonth = _getStudentRegistrationMonth();

    if (currentYear < registrationYear ||
        (currentYear == registrationYear && currentMonth < registrationMonth)) {
      return const SizedBox.shrink();
    }

    final currentMonthlyFee = _getStudentMonthlyFeeForMonth(
      currentYear,
      currentMonth,
    );
    final paidThisMonth = _getPaidAmountForExactMonth(
      currentYear,
      currentMonth,
    );
    final remaining = currentMonthlyFee - paidThisMonth;

    if (remaining <= 0.01) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Bu ayın ödemesi tamamlanmıştır.",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pending,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Bu Ay Ödemesi",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Bu ay için aylık ücret: ${currentMonthlyFee.toStringAsFixed(0)} TL • Kalan: ${remaining.toStringAsFixed(0)} TL",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryCard() {
    final payments = _getPaymentsForYear(_selectedYear);
    final feeUpdates = payments
        .where((p) => p.note.contains("FEE_UPDATE:"))
        .toList();
    final regularPayments = payments
        .where((p) => !p.note.contains("FEE_UPDATE:"))
        .toList();

    if (regularPayments.isEmpty && feeUpdates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            Icon(Icons.history, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              "Bu yıl henüz ödeme kaydı yok",
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      );
    }

    final allItems = <Map<String, dynamic>>[];
    for (var p in regularPayments) {
      allItems.add({
        'type': 'payment',
        'data': p,
        'date': _parseDateString(p.paid_date) ?? DateTime.now(),
      });
    }
    for (var p in feeUpdates) {
      allItems.add({
        'type': 'fee_update',
        'data': p,
        'date': _parseDateString(p.paid_date) ?? DateTime.now(),
      });
    }
    allItems.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );

    final shown = allItems.length > 10 ? allItems.sublist(0, 10) : allItems;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(Icons.history, color: _teal, size: 18),
                const SizedBox(width: 6),
                Text(
                  "$_selectedYear Yılı Ödeme Geçmişi",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (feeUpdates.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${feeUpdates.length} ücret güncellemesi",
                      style: TextStyle(fontSize: 10, color: _teal),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shown.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
            itemBuilder: (_, i) {
              final item = shown[i];
              if (item['type'] == 'fee_update') {
                final p = item['data'] as Payment;
                final match = RegExp(r'FEE_UPDATE:\s*(\d+)').firstMatch(p.note);
                final newFee = match != null ? match.group(1) : "?";

                return InkWell(
                  onTap: () => _showPaymentDetailPopup(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.update, size: 18, color: _teal),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Ücret Güncellemesi: $newFee TL",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                _formatDate(p.paid_date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade300,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                final p = item['data'] as Payment;
                final payMonth = _getMonthFromDueDate(p.due_date);
                final isCurrent =
                    payMonth == _getCurrentMonth() &&
                    _selectedYear == _currentYear;

                return InkWell(
                  onTap: () => _showPaymentDetailPopup(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Colors.orange.shade100
                                : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isCurrent ? Icons.pending : Icons.receipt,
                            size: 18,
                            color: isCurrent ? Colors.orange : _teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${double.tryParse(p.amount)?.toStringAsFixed(0) ?? p.amount} TL",
                                style: TextStyle(
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "${p.payment_method} · ${_formatDate(p.paid_date)}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade300,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
          if (allItems.length > 10)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                "+ ${allItems.length - 10} kayıt daha",
                style: TextStyle(color: _textSub, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
