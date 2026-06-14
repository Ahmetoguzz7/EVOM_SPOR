/*
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
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

  bool _historicalDebtExpanded = false;

  List<Group> studentGroups = [];
  List<Payment> paymentHistory = [];
  String? selectedGroupId;
  String selectedGroupName = "";
  double monthlyFee = 0;

  List<Map<String, dynamic>> _feeUpdateHistory = [];
  Map<String, double> _feeOverrides = {};

  final List<String> paymentMethods = [
    "Nakit",
    "Kredi Kartı",
    "Havale/EFT",
    "Mail Order",
  ];

  // TEMA (GÜNCELLENDİ - daha modern ve yumuşak renkler)
  static const Color _bg = Color(0xFFF4F6FA);
  static const Color _surface = Colors.white;
  static const Color _teal = Color(0xFF0D9488);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF97316);
  static const Color _green = Color(0xFF22C55E);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textSub = Color(0xFF94A3B8);
  static const Color _borderLight = Color(0xFFE2E8F0);

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
  // TÜRKÇE TARİH FONKSİYONLARI (AYNEN)
  // =========================================================================

  DateTime? _parseDateString(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      if (dateStr.contains('T')) return DateTime.parse(dateStr);
      if (dateStr.contains('-') && dateStr.length >= 10) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final d = int.tryParse(parts[2].substring(0, 2));
          if (y != null && m != null && d != null) return DateTime(y, m, d);
        }
      }
      return DateTime.tryParse(dateStr);
    } catch (_) {
      return null;
    }
  }

  String _formatDateTurkish(DateTime? date) {
    if (date == null) return "Belirsiz";
    final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
    return formatter.format(date);
  }

  String _formatDateFromString(String dateStr) {
    final date = _parseDateString(dateStr);
    return _formatDateTurkish(date);
  }

  String _getMonthNameTurkish(int month) {
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
    return months[month - 1];
  }

  String _formatDisplayDateTurkish(DateTime date) {
    return _formatDateTurkish(date);
  }

  // =========================================================================
  // YARDIMCI FONKSİYONLAR (AYNEN)
  // =========================================================================
  int _getCurrentYear() => DateTime.now().year;
  int _getCurrentMonth() => DateTime.now().month;

  int _getStudentRegistrationYear() {
    final createdDate = _parseDateString(widget.student.created_at);
    if (createdDate != null) return createdDate.year;
    return _currentYear;
  }

  int _getStudentRegistrationMonth() {
    final createdDate = _parseDateString(widget.student.created_at);
    if (createdDate != null) return createdDate.month;
    return 1;
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
    for (int i = 1; i <= 12; i++) {
      if (d.contains(_getMonthNameTurkish(i))) return i;
    }
    return null;
  }

  // =========================================================================
  // ÜCRET HESAPLAMA (AYNEN)
  // =========================================================================
  double _getStudentMonthlyFeeForMonth(int year, int month) {
    final registrationYear = _getStudentRegistrationYear();
    final registrationMonth = _getStudentRegistrationMonth();
    if (year < registrationYear ||
        (year == registrationYear && month < registrationMonth)) {
      return 0;
    }
    final key = "$year-${month.toString().padLeft(2, '0')}";
    if (_feeOverrides.containsKey(key)) {
      return _feeOverrides[key]!;
    }
    if (_feeUpdateHistory.isEmpty) return monthlyFee;
    final updates = List<Map<String, dynamic>>.from(
      _feeUpdateHistory,
    )..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    for (var update in updates) {
      final uDate = update['date'] as DateTime;
      final uYear = uDate.year;
      final uMonth = uDate.month;
      final bool targetIsOnOrAfterUpdateMonth =
          (year > uYear) || (year == uYear && month >= uMonth);
      if (!targetIsOnOrAfterUpdateMonth) {
        return update['oldFee'] as double;
      }
    }
    return monthlyFee;
  }

  double _getExpectedAnnualForYear(int year) {
    double total = 0;
    for (var month in _getMonthsOfYear(year)) {
      total += _getStudentMonthlyFeeForMonth(year, month.month);
    }
    return total;
  }

  // =========================================================================
  // HESAPLAMALAR (AYNEN)
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
      if (year == registrationYear && m < registrationMonth) continue;
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
      if (year == registrationYear && month.month < registrationMonth) continue;
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
        'monthName': _getMonthNameTurkish(month.month) + " ${month.year}",
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
            'monthName': _getMonthNameTurkish(month.month) + " ${month.year}",
            'status': status,
          };
        })
        .where((item) => item != null)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  // =========================================================================
  // VERİ YÜKLEME (AYNEN)
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
      print
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
      final allFeeUpdatePayments = allPayments
          .where(
            (p) =>
                p.student_id == widget.student.app &&
                (p.status == "fee_update" || p.note.contains("FEE_UPDATE:")),
          )
          .toList();
      allFeeUpdatePayments.sort((a, b) => a.paid_date.compareTo(b.paid_date));
      _feeUpdateHistory.clear();
      for (var payment in allFeeUpdatePayments) {
        final match = RegExp(r'FEE_UPDATE:\s*(\d+)').firstMatch(payment.note);
        final oldMatch = RegExp(
          r'\(Eski:\s*(\d+)\s*TL\)',
        ).firstMatch(payment.note);
        if (match != null) {
          final fee = double.tryParse(match.group(1)!) ?? 0;
          final oldFee = oldMatch != null
              ? (double.tryParse(oldMatch.group(1)!) ?? fee)
              : fee;
          final updateDate = _parseDateString(payment.paid_date);
          if (updateDate != null && fee > 0) {
            _feeUpdateHistory.add({
              'date': updateDate,
              'fee': fee,
              'oldFee': oldFee,
            });
          }
        }
      }
      _feeUpdateHistory.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
      );
      final overridePayments = allPayments.where((p) {
        return p.student_id == widget.student.app &&
            (p.status == "fee_override" || p.note.contains("OVERRIDE:"));
      }).toList();
      overridePayments.sort((a, b) => b.paid_date.compareTo(a.paid_date));
      _feeOverrides.clear();
      for (var ov in overridePayments) {
        final dueDate = ov.due_date;
        if (dueDate.length >= 7) {
          final yearMonth = dueDate.substring(0, 7);
          final amount = double.tryParse(ov.amount) ?? 0;
          if (amount > 0 && !_feeOverrides.containsKey(yearMonth)) {
            _feeOverrides[yearMonth] = amount;
          }
        }
      }
      print Fee update geçmişi: ${_feeUpdateHistory.length} kayıt");
      print Override edilen aylar: ${_feeOverrides.length}");
      return {
        'monthlyFee': monthlyFee,
        'currentYear': _currentYear,
        'previousYear': _previousYear,
      };
    } catch (e) {
      print PaymentScreen veri yükleme hatası: $e");
      return {
        'monthlyFee': 0.0,
        'currentYear': _currentYear,
        'previousYear': _previousYear,
      };
    }
  }

  // =========================================================================
  // ÖDEME İŞLEMLERİ (AYNEN)
  // =========================================================================
  Future<void> _updateMonthlyFee() async {
    final ctrl = TextEditingController(text: monthlyFee.toStringAsFixed(0));
    bool isSubmitting = false;
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.edit, color: _teal),
                SizedBox(width: 8),
                Text('Aylık Ücreti Güncelle'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Yeni Aylık Ücret (TL)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.money),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Güncelleme yapılan ay itibari ile geçerlidir.\nGeçmiş aylar eski ücret üzerinden hesaplanır.",
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
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  minimumSize: const Size(100, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final newFee = double.tryParse(ctrl.text) ?? 0;
                        if (newFee > 0 && newFee != monthlyFee) {
                          setDialogState(() => isSubmitting = true);
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
                                note:
                                    "FEE_UPDATE: ${newFee.toStringAsFixed(0)} (Eski: ${monthlyFee.toStringAsFixed(0)} TL)",
                              ),
                            );
                            GoogleSheetService.invalidateCache('users');
                            GoogleSheetService.invalidateCache('payments');
                            setState(() {
                              monthlyFee = newFee;
                              _allDataFuture = _loadAllDataParallel();
                            });
                            if (mounted) {
                              Navigator.pop(context);
                              _showSnackBar(
                                '✅ Aylık ücret güncellendi: ${newFee.toStringAsFixed(0)} TL\n Bu aydan itibaren geçerlidir.',
                              );
                            }
                          } else {
                            setDialogState(() => isSubmitting = false);
                            _showSnackBar(
                              '❌ Ücret güncellenemedi!',
                              isError: true,
                            );
                          }
                        } else if (newFee == monthlyFee) {
                          Navigator.pop(context);
                        } else {
                          _showSnackBar(
                            '❌ Geçerli bir tutar girin!',
                            isError: true,
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Güncelle'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Tek ay için override (tasarımı güncellendi, mantık aynı)
  Future<void> _overridePastMonthFee() async {
    int selectedYear = _currentYear;
    int selectedMonth = DateTime.now().month;
    double newFee = 0;
    String generatedCode = "";
    String enteredCode = "";
    bool stepTwo = false;
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.history, color: _teal),
                SizedBox(width: 8),
                Text('Geçmiş Ay Ücret Düzeltme'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          items: List.generate(5, (i) {
                            int year = _currentYear - i;
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
                          onChanged: stepTwo
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setDialogState(() => selectedYear = val);
                                  }
                                },
                          decoration: InputDecoration(
                            labelText: "Yıl",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedMonth,
                          items: List.generate(12, (i) {
                            int month = i + 1;
                            return DropdownMenuItem(
                              value: month,
                              child: Text(_getMonthNameTurkish(month)),
                            );
                          }),
                          onChanged: stepTwo
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setDialogState(() => selectedMonth = val);
                                  }
                                },
                          decoration: InputDecoration(
                            labelText: "Ay",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    keyboardType: TextInputType.number,
                    enabled: !stepTwo,
                    onChanged: (val) => newFee = double.tryParse(val) ?? 0,
                    decoration: InputDecoration(
                      labelText: "Yeni Ücret (TL)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.money),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!stepTwo)
                    ElevatedButton.icon(
                      onPressed: () {
                        if (newFee <= 0) {
                          _showSnackBar(
                            "Lütfen geçerli bir ücret girin!",
                            isError: true,
                          );
                          return;
                        }
                        generatedCode =
                            (100000 +
                                    DateTime.now().millisecondsSinceEpoch %
                                        900000)
                                .toString();
                        setDialogState(() => stepTwo = true);
                      },
                      icon: const Icon(Icons.security),
                      label: const Text("Kod Oluştur"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  if (stepTwo) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Doğrulama Kodu:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            generatedCode,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Bu kodu aşağıya yazın ve onaylayın.",
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) => enteredCode = val,
                      decoration: InputDecoration(
                        labelText: "Kodu Girin",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.vpn_key),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              if (stepTwo)
                ElevatedButton(
                  onPressed: () async {
                    if (enteredCode != generatedCode) {
                      _showSnackBar("❌ Kod hatalı!", isError: true);
                      return;
                    }
                    final dueDate =
                        "$selectedYear-${selectedMonth.toString().padLeft(2, '0')}-01";
                    final today = DateTime.now();
                    final paidDate =
                        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
                    final success = await GoogleSheetService.addPayment(
                      Payment(
                        payments_id: "",
                        student_id: widget.student.app,
                        groups_id: selectedGroupId ?? "",
                        recorded_by: "Admin",
                        amount: newFee.toStringAsFixed(0),
                        due_date: dueDate,
                        paid_date: paidDate,
                        status: "fee_override",
                        payment_method: "Sistem",
                        note: "OVERRIDE: $generatedCode",
                      ),
                    );
                    if (success) {
                      GoogleSheetService.invalidateCache('payments');
                      setState(() {
                        _allDataFuture = _loadAllDataParallel();
                      });
                      if (mounted) Navigator.pop(context);
                      _showSnackBar(
                        "✅ ${_getMonthNameTurkish(selectedMonth)} $selectedYear ücreti ${newFee.toStringAsFixed(0)} TL olarak düzeltildi.",
                      );
                    } else {
                      _showSnackBar("❌ Düzeltme kaydedilemedi!", isError: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Onayla ve Kaydet"),
                ),
            ],
          );
        },
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
      helpText: 'Tarih Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      fieldHintText: 'gg/aa/yyyy',
      fieldLabelText: 'Tarih',
      errorFormatText: 'Geçersiz format',
      errorInvalidText: 'Geçersiz tarih',
    );
    if (picked != null) {
      setState(() {
        selectedPaymentDate = picked;
        _selectedMissingMonth = missingMonth;
      });
    }
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
      final monthName =
          _getMonthNameTurkish(missingMonth.month) + " ${missingMonth.year}";
      _showSnackBar("$monthName ödemesi kaydedildi!");
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
        ? _getMonthNameTurkish(month) + " $year"
        : "—";
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
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
                      borderRadius: BorderRadius.circular(16),
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
                          style: TextStyle(color: _textSecondary, fontSize: 13),
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
                _formatDateFromString(p.paid_date),
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
              if (p.note.isNotEmpty &&
                  !p.note.contains("FEE_UPDATE:") &&
                  !p.note.contains("OVERRIDE:"))
                _popupRow(Icons.note_alt_outlined, "Not", p.note, _textSub),
              if (p.note.contains("FEE_UPDATE:"))
                _popupRow(Icons.update, "Ücret Güncelleme", p.note, _teal),
              if (p.note.contains("OVERRIDE:"))
                _popupRow(
                  Icons.edit,
                  "Ücret Düzeltme (Override)",
                  p.note,
                  _orange,
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(10),
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

  void _showPhoneDialog() {
    final phone = widget.student.phone ?? "Telefon bilgisi yok";
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.phone, color: _teal),
            SizedBox(width: 8),
            Text("İletişim Bilgisi"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${widget.student.first_name} ${widget.student.last_name}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_android, size: 18, color: _teal),
                const SizedBox(width: 8),
                Text(phone, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kapat"),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // BUILD (TASARIM GÜNCELLENDİ)
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
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: _teal),
            tooltip: "Aylık Ücreti Güncelle",
            onPressed: _updateMonthlyFee,
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: _teal),
            tooltip: "Telefon Numarası",
            onPressed: _showPhoneDialog,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _allDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _teal));
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
              // Yıl seçici
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
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
                      const SizedBox(height: 16),
                      _buildYearlyStatsCard(
                        _selectedYear,
                        totalReceived,
                        expectedAnnual,
                        collectionRate,
                      ),
                      const SizedBox(height: 16),
                      _buildOverrideCard(), // Geçmiş ay ücret düzeltme kartı
                      const SizedBox(height: 16),
                      if (historicalDebts.isNotEmpty)
                        _buildHistoricalDebtPanel(
                          historicalDebts,
                          registrationYear,
                        ),
                      const SizedBox(height: 16),
                      if (monthlyStatus.isNotEmpty)
                        _buildMonthlyPaymentStatusCard(
                          monthlyStatus,
                          _selectedYear,
                        ),
                      const SizedBox(height: 16),
                      if (missingPayments.isNotEmpty)
                        _buildMissingPaymentsCard(missingPayments),
                      const SizedBox(height: 16),
                      _buildPaymentFormCard(),
                      const SizedBox(height: 16),
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
  // GÜNCELLENMİŞ WIDGET'LAR (SADECE TASARIM)
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? _teal : _bg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSel ? Colors.transparent : _borderLight,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              "$year",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSel ? Colors.white : _textPrimary,
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
        ? "Kayıt: ${_formatDateTurkish(registrationDate)}"
        : "Kayıt: $registrationYear";
    final phoneNumber = widget.student.phone ?? "Telefon yok";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${widget.student.first_name} ${widget.student.last_name}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.student.email,
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: _teal),
                    const SizedBox(width: 4),
                    Text(
                      registrationText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.group, size: 12, color: _teal),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        selectedGroupName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.phone, size: 12, color: _teal),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        phoneNumber,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.call, size: 16, color: _teal),
                      onPressed: () => _showPhoneDialog(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Container(
    width: 55,
    height: 55,
    color: _teal,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    ),
  );

  Widget _divider() => Container(width: 1, height: 40, color: Colors.white24);

  Widget _buildOverrideCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: InkWell(
        onTap: _overridePastMonthFee,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.history_edu,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Geçmiş Ay Ücret Düzeltme",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _textPrimary,
                    ),
                  ),
                  Text(
                    "Sadece seçilen ay için ücret değiştir (diğer aylar etkilenmez)",
                    style: TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: _textSub),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyPaymentStatusCard(
    List<Map<String, dynamic>> monthlyStatus,
    int year,
  ) {
    if (monthlyStatus.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
          ],
        ),
        child: Center(
          child: Text(
            "Bu yıla ait ödeme dönemi bulunmuyor",
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
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
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: monthlyStatus.length,
            itemBuilder: (_, i) {
              final item = monthlyStatus[i];
              final isPaid = item['isFullyPaid'];
              final status = item['status'];
              final requiredFee = item['required'] as double;

              Color bgColor = isPaid
                  ? Colors.green.shade50
                  : status == "current"
                  ? Colors.orange.shade50
                  : Colors.red.shade50;

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPaid
                        ? Colors.green.shade200
                        : status == "current"
                        ? Colors.orange.shade200
                        : Colors.red.shade200,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item['monthName'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${(item['paid'] as double).toStringAsFixed(0)}/${requiredFee.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    isPaid
                        ? const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          )
                        : status == "current"
                        ? const Icon(
                            Icons.pending,
                            size: 16,
                            color: Colors.orange,
                          )
                        : const Icon(Icons.cancel, size: 16, color: Colors.red),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _red, size: 22),
              const SizedBox(width: 8),
              const Text(
                "Ödenmemiş Aylar",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _red,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  "${totalDebt.toStringAsFixed(0)} TL",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (overdue.isNotEmpty) ...[
            Text(
              "📅 Geçmiş Aylar (Ödenmesi Zorunlu):",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _red,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
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
            const SizedBox(height: 14),
          ],
          if (current.isNotEmpty) ...[
            Text(
              "📌 Bu Ay (Ödeme Yapılabilir):",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _orange,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
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
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: _teal),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Kırmızı ayların ödemesi ZORUNLUDUR. Turuncu ay cari aydır.",
                    style: TextStyle(fontSize: 11, color: _textSecondary),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: color, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
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
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${remaining.toStringAsFixed(0)} TL",
                style: const TextStyle(
                  fontSize: 11,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: headerColor, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: headerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isMonthOver ? Icons.warning_amber_rounded : Icons.pending,
                  color: headerColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$monthName Ödemesi",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
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
                icon: const Icon(Icons.close, size: 20, color: _textSub),
              ),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => _selectPaymentDateForMissingMonth(date),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: _borderLight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: _teal, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    "Ödeme Tarihi: ${_formatDisplayDateTurkish(selectedPaymentDate)}",
                    style: const TextStyle(fontSize: 13, color: _textPrimary),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: _textSub),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Ödenecek Tutar",
              hintText: "0.00",
              prefixIcon: Icon(Icons.money, color: _teal, size: 18),
              suffixText: "TL",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _teal, width: 1.5),
              ),
              helperText: "Maksimum: ${remaining.toStringAsFixed(0)} TL",
              helperStyle: TextStyle(color: _textSecondary, fontSize: 11),
            ),
          ),
          const SizedBox(height: 16),
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
                          size: 18,
                          color: _teal,
                        ),
                        const SizedBox(width: 8),
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
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _borderLight),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: noteController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: "Açıklama (Opsiyonel)",
              prefixIcon: Icon(Icons.note, color: _teal, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _borderLight),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () => _processPaymentForMissingMonth(date, remaining),
              style: ElevatedButton.styleFrom(
                backgroundColor: headerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
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
                        fontSize: 15,
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
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.warning_amber_rounded, size: 44, color: Colors.orange),
            SizedBox(height: 12),
            Text(
              "Aylık Ücret Tanımlanmamış",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
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
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Bu ayın ödemesi tamamlanmıştır.",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                ),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.pending,
                  color: Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Bu Ay Ödemesi",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Bu ay için aylık ücret: ${currentMonthlyFee.toStringAsFixed(0)} TL • Kalan: ${remaining.toStringAsFixed(0)} TL",
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
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
        .where(
          (p) =>
              !p.note.contains("FEE_UPDATE:") && !p.note.contains("OVERRIDE:"),
        )
        .toList();
    final overrides = payments
        .where((p) => p.note.contains("OVERRIDE:"))
        .toList();

    if (regularPayments.isEmpty && feeUpdates.isEmpty && overrides.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.history, size: 48, color: _textSub),
            SizedBox(height: 12),
            Text(
              "Bu yıl henüz ödeme kaydı yok",
              style: TextStyle(fontSize: 13, color: _textSecondary),
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
    for (var p in overrides) {
      allItems.add({
        'type': 'override',
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.history, color: _teal, size: 20),
                const SizedBox(width: 8),
                Text(
                  "$_selectedYear Yılı Ödeme Geçmişi",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                if (feeUpdates.isNotEmpty || overrides.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${feeUpdates.length + overrides.length} düzeltme",
                      style: TextStyle(fontSize: 11, color: _teal),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _borderLight),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shown.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: _borderLight, indent: 16),
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.update, size: 20, color: _teal),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Ücret Güncellemesi: $newFee TL",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDateFromString(p.paid_date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: _textSub, size: 18),
                      ],
                    ),
                  ),
                );
              } else if (item['type'] == 'override') {
                final p = item['data'] as Payment;
                final amount =
                    double.tryParse(p.amount)?.toStringAsFixed(0) ?? p.amount;
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.edit, size: 20, color: Colors.blue),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Ücret Düzeltme (Override): $amount TL",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDateFromString(p.paid_date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: _textSub, size: 18),
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Colors.orange.shade100
                                : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isCurrent ? Icons.pending : Icons.receipt,
                            size: 20,
                            color: isCurrent ? Colors.orange : _teal,
                          ),
                        ),
                        const SizedBox(width: 14),
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
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${p.payment_method} · ${_formatDateFromString(p.paid_date)}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: _textSub, size: 18),
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
                style: TextStyle(color: _textSub, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _red.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
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
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(_historicalDebtExpanded ? 0 : 24),
                  bottomRight: Radius.circular(
                    _historicalDebtExpanded ? 0 : 24,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.history, color: _red, size: 22),
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
                            fontSize: 15,
                            color: _textPrimary,
                          ),
                        ),
                        Text(
                          "Kayıt: $registrationYear • $yearRange",
                          style: TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _red,
                      borderRadius: BorderRadius.circular(30),
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
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _red,
                      size: 24,
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
                const Divider(height: 1, thickness: 1, color: _borderLight),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: debts.map((debt) {
                      final year = debt['year'] as int;
                      final months =
                          debt['months'] as List<Map<String, dynamic>>;
                      final yDebt = debt['totalDebt'] as double;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _red.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _red.withOpacity(0.08),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
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
                                      fontSize: 14,
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
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: months.map((m) {
                                  final remaining = m['remaining'] as double;
                                  final paid = m['paid'] as double;
                                  final required = m['required'] as double;
                                  final pct = required > 0
                                      ? (paid / required).clamp(0.0, 1.0)
                                      : 0.0;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
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
                                                color: _textPrimary,
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
                                                    BorderRadius.circular(20),
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
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
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
                                              minHeight: 5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              "${paid.toStringAsFixed(0)} / ${required.toStringAsFixed(0)} TL ödendi",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: _textSecondary,
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
            duration: const Duration(milliseconds: 280),
          ),
        ],
      ),
    );
  }
}
*/
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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

  bool _historicalDebtExpanded = false;

  List<Group> studentGroups = [];
  List<Payment> paymentHistory = [];
  String? selectedGroupId;
  String selectedGroupName = "";
  double monthlyFee = 0;

  List<Map<String, dynamic>> _feeUpdateHistory = [];
  Map<String, double> _feeOverrides = {};

  final List<String> paymentMethods = [
    "Nakit",
    "Kredi Kartı",
    "Havale/EFT",
    "Mail Order",
  ];

  // TEMA
  static const Color _bg = Color(0xFFF4F6FA);
  static const Color _surface = Colors.white;
  static const Color _teal = Color(0xFF0D9488);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF97316);
  static const Color _green = Color(0xFF22C55E);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textSub = Color(0xFF94A3B8);
  static const Color _borderLight = Color(0xFFE2E8F0);

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
  // TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

  DateTime? _parseDateString(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      if (dateStr.contains('T')) return DateTime.parse(dateStr);
      if (dateStr.contains('-') && dateStr.length >= 10) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final d = int.tryParse(parts[2].substring(0, 2));
          if (y != null && m != null && d != null) return DateTime(y, m, d);
        }
      }
      return DateTime.tryParse(dateStr);
    } catch (_) {
      return null;
    }
  }

  String _formatDateTurkish(DateTime? date) {
    if (date == null) return "Belirsiz";
    final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
    return formatter.format(date);
  }

  String _formatDateFromString(String dateStr) {
    final date = _parseDateString(dateStr);
    return _formatDateTurkish(date);
  }

  String _getMonthNameTurkish(int month) {
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
    return months[month - 1];
  }

  String _formatDisplayDateTurkish(DateTime date) {
    return _formatDateTurkish(date);
  }

  // =========================================================================
  // YARDIMCI FONKSİYONLAR
  // =========================================================================
  int _getCurrentYear() => DateTime.now().year;
  int _getCurrentMonth() => DateTime.now().month;

  int _getStudentRegistrationYear() {
    final createdDate = _parseDateString(widget.student.created_at);
    if (createdDate != null) return createdDate.year;
    return _currentYear;
  }

  int _getStudentRegistrationMonth() {
    final createdDate = _parseDateString(widget.student.created_at);
    if (createdDate != null) return createdDate.month;
    return 1;
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
    for (int i = 1; i <= 12; i++) {
      if (d.contains(_getMonthNameTurkish(i))) return i;
    }
    return null;
  }

  // =========================================================================
  // ÜCRET HESAPLAMA
  // =========================================================================
  double _getStudentMonthlyFeeForMonth(int year, int month) {
    final registrationYear = _getStudentRegistrationYear();
    final registrationMonth = _getStudentRegistrationMonth();
    if (year < registrationYear ||
        (year == registrationYear && month < registrationMonth)) {
      return 0;
    }
    final key = "$year-${month.toString().padLeft(2, '0')}";
    if (_feeOverrides.containsKey(key)) {
      return _feeOverrides[key]!;
    }
    if (_feeUpdateHistory.isEmpty) return monthlyFee;
    final updates = List<Map<String, dynamic>>.from(
      _feeUpdateHistory,
    )..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    for (var update in updates) {
      final uDate = update['date'] as DateTime;
      final uYear = uDate.year;
      final uMonth = uDate.month;
      final bool targetIsOnOrAfterUpdateMonth =
          (year > uYear) || (year == uYear && month >= uMonth);
      if (!targetIsOnOrAfterUpdateMonth) {
        return update['oldFee'] as double;
      }
    }
    return monthlyFee;
  }

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
      if (year == registrationYear && m < registrationMonth) continue;
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
      if (year == registrationYear && month.month < registrationMonth) continue;
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
        'monthName': _getMonthNameTurkish(month.month) + " ${month.year}",
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
            'monthName': _getMonthNameTurkish(month.month) + " ${month.year}",
            'status': status,
          };
        })
        .where((item) => item != null)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  // =========================================================================
  // VERİ YÜKLEME
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
      /* print
        "⏱️ PaymentScreen verileri PARALEL olarak ${stopwatch.elapsedMilliseconds}ms'de yüklendi",
      );*/
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
      final allFeeUpdatePayments = allPayments
          .where(
            (p) =>
                p.student_id == widget.student.app &&
                (p.status == "fee_update" || p.note.contains("FEE_UPDATE:")),
          )
          .toList();
      allFeeUpdatePayments.sort((a, b) => a.paid_date.compareTo(b.paid_date));
      _feeUpdateHistory.clear();
      for (var payment in allFeeUpdatePayments) {
        final match = RegExp(r'FEE_UPDATE:\s*(\d+)').firstMatch(payment.note);
        final oldMatch = RegExp(
          r'\(Eski:\s*(\d+)\s*TL\)',
        ).firstMatch(payment.note);
        if (match != null) {
          final fee = double.tryParse(match.group(1)!) ?? 0;
          final oldFee = oldMatch != null
              ? (double.tryParse(oldMatch.group(1)!) ?? fee)
              : fee;
          final updateDate = _parseDateString(payment.paid_date);
          if (updateDate != null && fee > 0) {
            _feeUpdateHistory.add({
              'date': updateDate,
              'fee': fee,
              'oldFee': oldFee,
            });
          }
        }
      }
      _feeUpdateHistory.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
      );
      final overridePayments = allPayments.where((p) {
        return p.student_id == widget.student.app &&
            (p.status == "fee_override" || p.note.contains("OVERRIDE:"));
      }).toList();
      overridePayments.sort((a, b) => b.paid_date.compareTo(a.paid_date));
      _feeOverrides.clear();
      for (var ov in overridePayments) {
        final dueDate = ov.due_date;
        if (dueDate.length >= 7) {
          final yearMonth = dueDate.substring(0, 7);
          final amount = double.tryParse(ov.amount) ?? 0;
          if (amount > 0 && !_feeOverrides.containsKey(yearMonth)) {
            _feeOverrides[yearMonth] = amount;
          }
        }
      }
      //print Fee update geçmişi: ${_feeUpdateHistory.length} kayıt");
      // print Override edilen aylar: ${_feeOverrides.length}");
      return {
        'monthlyFee': monthlyFee,
        'currentYear': _currentYear,
        'previousYear': _previousYear,
      };
    } catch (e) {
      // print PaymentScreen veri yükleme hatası: $e");
      return {
        'monthlyFee': 0.0,
        'currentYear': _currentYear,
        'previousYear': _previousYear,
      };
    }
  }

  // =========================================================================
  // ÜCRET GÜNCELLEME (GEÇMİŞ ve GELECEK)
  // =========================================================================

  /// Ana ücret güncelleme butonu - AppBar kalem ikonu
  Future<void> _showFeeUpdateOptions() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Ücret Güncelleme Türü"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.trending_up, color: _teal),
              title: const Text("Geleceğe Yönelik"),
              subtitle: const Text(
                "Seçilen aydan itibaren tüm aylar etkilenir",
              ),
              onTap: () => Navigator.pop(context, "future"),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: _orange),
              title: const Text("Geçmişe Yönelik"),
              subtitle: const Text("Sadece seçilen ayın ücretini değiştirir"),
              onTap: () => Navigator.pop(context, "past"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
        ],
      ),
    );
    if (result == "future") {
      _updateMonthlyFee();
    } else if (result == "past") {
      _bulkOverridePastMonths();
    }
  }

  /// Geleceğe yönelik ücret güncelleme (mevcut)
  Future<void> _updateMonthlyFee() async {
    final ctrl = TextEditingController(text: monthlyFee.toStringAsFixed(0));
    bool isSubmitting = false;
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.edit, color: _teal),
                SizedBox(width: 8),
                Text('Gelecek Aylar İçin\nÜcret Güncelle'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Yeni Aylık Ücret (TL)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.money),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Güncelleme yapılan ay itibari ile geçerlidir.\nGeçmiş aylar eski ücret üzerinden hesaplanır.",
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
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  minimumSize: const Size(100, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final newFee = double.tryParse(ctrl.text) ?? 0;
                        if (newFee > 0 && newFee != monthlyFee) {
                          setDialogState(() => isSubmitting = true);
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
                                note:
                                    "FEE_UPDATE: ${newFee.toStringAsFixed(0)} (Eski: ${monthlyFee.toStringAsFixed(0)} TL)",
                              ),
                            );
                            GoogleSheetService.invalidateCache('users');
                            GoogleSheetService.invalidateCache('payments');
                            setState(() {
                              monthlyFee = newFee;
                              _allDataFuture = _loadAllDataParallel();
                            });
                            if (mounted) {
                              Navigator.pop(context);
                              _showSnackBar(
                                '✅ Aylık ücret güncellendi: ${newFee.toStringAsFixed(0)} TL\n Bu aydan itibaren geçerlidir.',
                              );
                            }
                          } else {
                            setDialogState(() => isSubmitting = false);
                            _showSnackBar(
                              '❌ Ücret güncellenemedi!',
                              isError: true,
                            );
                          }
                        } else if (newFee == monthlyFee) {
                          Navigator.pop(context);
                        } else {
                          _showSnackBar(
                            '❌ Geçerli bir tutar girin!',
                            isError: true,
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Güncelle'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Geçmişe yönelik çoklu ay override
  Future<void> _bulkOverridePastMonths() async {
    int selectedYear = _currentYear;
    List<int> selectedMonths = [];
    double newFee = 0;
    String generatedCode = "";
    String enteredCode = "";
    bool stepTwo = false;

    // Kullanıcının seçebileceği aylar: kayıt tarihinden bugüne kadar
    final registrationYear = _getStudentRegistrationYear();
    final registrationMonth = _getStudentRegistrationMonth();
    Set<String> availableMonthsSet = {};
    for (int y = registrationYear; y <= _currentYear; y++) {
      int startMonth = (y == registrationYear) ? registrationMonth : 1;
      int endMonth = (y == _currentYear) ? _getCurrentMonth() : 12;
      for (int m = startMonth; m <= endMonth; m++) {
        availableMonthsSet.add("$y-$m");
      }
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.history_edu, color: _teal),
                SizedBox(width: 8),
                Text('Geçmiş Aylar İçin\nToplu Ücret Düzeltme'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Yıl seçimi
                  DropdownButtonFormField<int>(
                    value: selectedYear,
                    items: List.generate(_currentYear - registrationYear + 1, (
                      i,
                    ) {
                      int year = registrationYear + i;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: stepTwo
                        ? null
                        : (val) {
                            if (val != null)
                              setDialogState(() => selectedYear = val);
                          },
                    decoration: InputDecoration(
                      labelText: "Yıl",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Ay seçimi (çoklu)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _borderLight),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text(
                            "Değiştirmek İstediğinz Ayı Seçin ",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(12, (index) {
                              int month = index + 1;
                              final key = "$selectedYear-$month";
                              if (!availableMonthsSet.contains(key)) {
                                return const SizedBox.shrink();
                              }
                              bool isSelected = selectedMonths.contains(month);
                              return FilterChip(
                                label: Text(_getMonthNameTurkish(month)),
                                selected: isSelected,
                                onSelected: stepTwo
                                    ? null
                                    : (selected) {
                                        setDialogState(() {
                                          if (selected) {
                                            selectedMonths.add(month);
                                          } else {
                                            selectedMonths.remove(month);
                                          }
                                        });
                                      },
                                backgroundColor: _bg,
                                selectedColor: _teal.withOpacity(0.2),
                                checkmarkColor: _teal,
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    keyboardType: TextInputType.number,
                    enabled: !stepTwo,
                    onChanged: (val) => newFee = double.tryParse(val) ?? 0,
                    decoration: InputDecoration(
                      labelText: "Yeni Ücret (TL)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.money),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!stepTwo)
                    ElevatedButton.icon(
                      onPressed: () {
                        if (newFee <= 0) {
                          _showSnackBar(
                            "Lütfen geçerli bir ücret girin!",
                            isError: true,
                          );
                          return;
                        }
                        if (selectedMonths.isEmpty) {
                          _showSnackBar(
                            "Lütfen en az bir ay seçin!",
                            isError: true,
                          );
                          return;
                        }
                        generatedCode =
                            (100000 +
                                    DateTime.now().millisecondsSinceEpoch %
                                        900000)
                                .toString();
                        setDialogState(() => stepTwo = true);
                      },
                      icon: const Icon(Icons.security),
                      label: const Text("Kod Oluştur"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  if (stepTwo) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Doğrulama Kodu:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            generatedCode,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Bu kodu aşağıya yazın ve onaylayın.",
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) => enteredCode = val,
                      decoration: InputDecoration(
                        labelText: "Kodu Girin",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.vpn_key),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              if (stepTwo)
                ElevatedButton(
                  onPressed: () async {
                    if (enteredCode != generatedCode) {
                      _showSnackBar("❌ Kod hatalı!", isError: true);
                      return;
                    }
                    bool allSuccess = true;
                    for (int month in selectedMonths) {
                      final dueDate =
                          "$selectedYear-${month.toString().padLeft(2, '0')}-01";
                      final today = DateTime.now();
                      final paidDate =
                          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
                      final success = await GoogleSheetService.addPayment(
                        Payment(
                          payments_id: "",
                          student_id: widget.student.app,
                          groups_id: selectedGroupId ?? "",
                          recorded_by: "Admin",
                          amount: newFee.toStringAsFixed(0),
                          due_date: dueDate,
                          paid_date: paidDate,
                          status: "fee_override",
                          payment_method: "Sistem",
                          note: "OVERRIDE: $generatedCode (Toplu güncelleme)",
                        ),
                      );
                      if (!success) allSuccess = false;
                    }
                    if (allSuccess) {
                      GoogleSheetService.invalidateCache('payments');
                      setState(() {
                        _allDataFuture = _loadAllDataParallel();
                      });
                      if (mounted) Navigator.pop(context);
                      _showSnackBar(
                        "✅ ${selectedMonths.length} ayın ücreti ${newFee.toStringAsFixed(0)} TL olarak düzeltildi.",
                      );
                    } else {
                      _showSnackBar(
                        "❌ Bazı düzeltmeler kaydedilemedi!",
                        isError: true,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Onayla ve Kaydet"),
                ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // ÖDEME İŞLEMLERİ
  // =========================================================================
  Future<void> _selectPaymentDateForMissingMonth(
    DateTime missingMonth, {
    bool isMonthOver = false,
  }) async {
    final firstDay = DateTime(missingMonth.year, missingMonth.month, 1);
    final lastDay = DateTime(missingMonth.year, missingMonth.month + 1, 0);

    // 🔥 SADECE GEÇMİŞ AYLAR İÇİN default 15
    DateTime initialDate;
    if (isMonthOver) {
      // Geçmiş ay: default olarak ayın 15'ini al (eğer geçerli değilse son günü al)
      try {
        initialDate = DateTime(missingMonth.year, missingMonth.month, 15);
        if (initialDate.day != 15) {
          initialDate = lastDay;
        }
      } catch (e) {
        initialDate = firstDay;
      }
    } else {
      // Cari ay: bugünü göster
      initialDate = selectedPaymentDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDay,
      lastDate: lastDay,
      helpText:
          'Ödeme Tarihi Seç (${_getMonthNameTurkish(missingMonth.month)} ${missingMonth.year})',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      fieldHintText: 'gg/aa/yyyy',
      fieldLabelText: 'Tarih',
      errorFormatText: 'Geçersiz format',
      errorInvalidText: 'Geçersiz tarih',
    );

    if (picked != null) {
      setState(() {
        selectedPaymentDate = picked;
        _selectedMissingMonth = missingMonth;
      });
    }
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
      final monthName =
          _getMonthNameTurkish(missingMonth.month) + " ${missingMonth.year}";
      _showSnackBar("$monthName ödemesi kaydedildi!");
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
        ? _getMonthNameTurkish(month) + " $year"
        : "—";

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(24),
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
                          borderRadius: BorderRadius.circular(16),
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
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 13,
                              ),
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
                    _formatDateFromString(p.paid_date),
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
                  if (p.note.isNotEmpty &&
                      !p.note.contains("FEE_UPDATE:") &&
                      !p.note.contains("OVERRIDE:"))
                    _popupRow(Icons.note_alt_outlined, "Not", p.note, _textSub),
                  if (p.note.contains("FEE_UPDATE:"))
                    _popupRow(Icons.update, "Ücret Güncelleme", p.note, _teal),
                  if (p.note.contains("OVERRIDE:"))
                    _popupRow(
                      Icons.edit,
                      "Ücret Düzeltme (Override)",
                      p.note,
                      _orange,
                    ),
                  const SizedBox(height: 16),

                  // 🔥 DÜZENLEME VE SİLME BUTONLARI
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditPaymentDialog(p);
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text("Düzenle"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _teal,
                            side: BorderSide(color: _teal),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDeletePayment(p),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text("Sil"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _red,
                            side: BorderSide(color: _red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
          );
        },
      ),
    );
  }

  // 🔥 ÖDEME DÜZENLEME DİYALOĞU
  void _showEditPaymentDialog(Payment payment) async {
    final amountCtrl = TextEditingController(text: payment.amount);
    final noteCtrl = TextEditingController(text: payment.note);
    String selectedMethodEdit = payment.payment_method;
    DateTime selectedDateEdit =
        _parseDateString(payment.paid_date) ?? DateTime.now();
    bool isSaving = false;

    // Önce grupları kontrol et
    if (studentGroups.isEmpty) {
      final allGroups = await GoogleSheetService.getGroupsCached();
      final allRelations = await GoogleSheetService.getGroupStudentsCached();
      final groupIds = allRelations
          .where(
            (r) => r.student_id == widget.student.app && r.is_active == "TRUE",
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
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.edit, color: _teal),
                SizedBox(width: 8),
                Text("Ödemeyi Düzenle", style: TextStyle(fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grup seçimi (eğer birden fazla grup varsa)
                  if (studentGroups.length > 1)
                    DropdownButtonFormField<String>(
                      value: selectedGroupId,
                      decoration: const InputDecoration(
                        labelText: "Grup",
                        border: OutlineInputBorder(),
                      ),
                      items: studentGroups.map((g) {
                        return DropdownMenuItem(
                          value: g.groups_id,
                          child: Text(g.name),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedGroupId = v),
                    ),
                  const SizedBox(height: 12),
                  // Tutar
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Tutar (TL)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Ödeme Yöntemi
                  DropdownButtonFormField<String>(
                    value: selectedMethodEdit,
                    items: paymentMethods.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedMethodEdit = v!),
                    decoration: const InputDecoration(
                      labelText: "Ödeme Yöntemi",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tarih seçimi
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDateEdit,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDateEdit = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: _borderLight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: _teal),
                          const SizedBox(width: 12),
                          Text(_formatDateTurkish(selectedDateEdit)),
                          const Spacer(),
                          Icon(Icons.arrow_drop_down, color: _textSub),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Not
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "Not (Opsiyonel)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("İptal"),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);

                        final updateData = {
                          "amount": amountCtrl.text.trim(),
                          "payment_method": selectedMethodEdit,
                          "paid_date": _formatDateForDB(selectedDateEdit),
                          "note": noteCtrl.text.trim(),
                        };

                        if (selectedGroupId != null &&
                            studentGroups.length > 1) {
                          updateData["groups_id"] = selectedGroupId!;
                        }

                        final success = await GoogleSheetService.updatePayment(
                          payment.payments_id,
                          updateData,
                        );

                        setDialogState(() => isSaving = false);

                        if (success && mounted) {
                          Navigator.pop(context);
                          setState(() {
                            _allDataFuture = _loadAllDataParallel();
                          });
                          _showSnackBar("✅ Ödeme güncellendi!");
                        } else {
                          _showSnackBar(
                            "❌ Güncelleme başarısız!",
                            isError: true,
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: _teal),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Kaydet"),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🔥 ÖDEME SİLME ONAYI
  void _confirmDeletePayment(Payment payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Ödemeyi Sil", style: TextStyle(color: _red)),
        content: Text(
          "${_formatDateFromString(payment.paid_date)} tarihli ${payment.amount} TL ödeme silinecek. Devam etmek istiyor musunuz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _red),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await GoogleSheetService.deletePayment(payment.payments_id);

    if (success && mounted) {
      setState(() {
        _allDataFuture = _loadAllDataParallel();
      });
      _showSnackBar("✅ Ödeme silindi!");
    } else {
      _showSnackBar("❌ Silme başarısız!", isError: true);
    }
  }

  String _formatDateForDB(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
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
              borderRadius: BorderRadius.circular(10),
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

  // Telefon arama fonksiyonu
  Future<void> _makePhoneCall() async {
    final phone = widget.student.phone;
    if (phone.isEmpty) {
      _showSnackBar("Telefon numarası mevcut değil", isError: true);
      return;
    }
    final Uri telUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      _showSnackBar("Arama yapılamadı", isError: true);
    }
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
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: _teal),
            tooltip: "Ücret Güncelle",
            onPressed: _showFeeUpdateOptions,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _allDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _teal));
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
              // Yıl seçici
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
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
                      const SizedBox(height: 16),
                      _buildYearlyStatsCard(
                        _selectedYear,
                        totalReceived,
                        expectedAnnual,
                        collectionRate,
                      ),
                      const SizedBox(height: 16),
                      if (historicalDebts.isNotEmpty)
                        _buildHistoricalDebtPanel(
                          historicalDebts,
                          registrationYear,
                        ),
                      const SizedBox(height: 16),
                      if (monthlyStatus.isNotEmpty)
                        _buildMonthlyPaymentStatusCard(
                          monthlyStatus,
                          _selectedYear,
                        ),
                      const SizedBox(height: 16),
                      if (missingPayments.isNotEmpty)
                        _buildMissingPaymentsCard(missingPayments),
                      const SizedBox(height: 16),
                      _buildPaymentFormCard(),
                      const SizedBox(height: 16),
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
  // WIDGET'LAR
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? _teal : _bg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSel ? Colors.transparent : _borderLight,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              "$year",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSel ? Colors.white : _textPrimary,
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
        ? "Kayıt: ${_formatDateTurkish(registrationDate)}"
        : "Kayıt: $registrationYear";
    final phoneNumber = widget.student.phone ?? "Telefon yok";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${widget.student.first_name} ${widget.student.last_name}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.student.email,
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: _teal),
                    const SizedBox(width: 4),
                    Text(
                      registrationText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.group, size: 12, color: _teal),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        selectedGroupName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.phone, size: 12, color: _teal),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        phoneNumber,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.call, size: 16, color: _teal),
                      onPressed: _makePhoneCall,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Container(
    width: 55,
    height: 55,
    color: _teal,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    ),
  );

  Widget _divider() => Container(width: 1, height: 40, color: Colors.white24);

  Widget _buildMonthlyPaymentStatusCard(
    List<Map<String, dynamic>> monthlyStatus,
    int year,
  ) {
    if (monthlyStatus.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
          ],
        ),
        child: Center(
          child: Text(
            "Bu yıla ait ödeme dönemi bulunmuyor",
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
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
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: monthlyStatus.length,
            itemBuilder: (_, i) {
              final item = monthlyStatus[i];
              final isPaid = item['isFullyPaid'];
              final status = item['status'];
              final requiredFee = item['required'] as double;

              Color bgColor = isPaid
                  ? Colors.green.shade50
                  : status == "current"
                  ? Colors.orange.shade50
                  : Colors.red.shade50;

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPaid
                        ? Colors.green.shade200
                        : status == "current"
                        ? Colors.orange.shade200
                        : Colors.red.shade200,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item['monthName'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${(item['paid'] as double).toStringAsFixed(0)}/${requiredFee.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    isPaid
                        ? const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          )
                        : status == "current"
                        ? const Icon(
                            Icons.pending,
                            size: 16,
                            color: Colors.orange,
                          )
                        : const Icon(Icons.cancel, size: 16, color: Colors.red),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _red, size: 22),
              const SizedBox(width: 8),
              const Text(
                "Ödenmemiş Aylar",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _red,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  "${totalDebt.toStringAsFixed(0)} TL",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (overdue.isNotEmpty) ...[
            Text(
              "📅 Geçmiş Aylar (Ödenmesi Zorunlu):",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _red,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
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
            const SizedBox(height: 14),
          ],
          if (current.isNotEmpty) ...[
            Text(
              "📌 Bu Ay (Ödeme Yapılabilir):",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _orange,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
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
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: _teal),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Kırmızı ayların ödemesi ZORUNLUDUR. Turuncu ay cari aydır.",
                    style: TextStyle(fontSize: 11, color: _textSecondary),
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
    final isMonthOver = color == _red; // Geçmiş ay kontrolü

    return GestureDetector(
      onTap: () {
        // 🔥 ÖNCE DEFAULT TARİHİ AYARLA
        if (isMonthOver) {
          selectedPaymentDate = _getDefaultPaymentDate(date);
        } else {
          selectedPaymentDate = DateTime.now();
        }

        setState(() {
          _selectedMissingMonth = date;
          amountController.clear();
          noteController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: color, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
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
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${remaining.toStringAsFixed(0)} TL",
                style: const TextStyle(
                  fontSize: 11,
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

    // 🔥 GEÇMİŞ AY İÇİN DEFAULT TARİHİ AYIN 15'İ YAP
    if (isMonthOver && _selectedMissingMonth == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            selectedPaymentDate = _getDefaultPaymentDate(date);
          });
        }
      });
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: headerColor, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: headerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isMonthOver ? Icons.warning_amber_rounded : Icons.pending,
                  color: headerColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$monthName Ödemesi",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
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
                icon: const Icon(Icons.close, size: 20, color: _textSub),
              ),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => _selectPaymentDateForMissingMonth(
              date,
              isMonthOver: isMonthOver,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: _borderLight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: _teal, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    "Ödeme Tarihi: ${_formatDisplayDateTurkish(selectedPaymentDate)}",
                    style: const TextStyle(fontSize: 13, color: _textPrimary),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: _textSub),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Ödenecek Tutar",
              hintText: "0.00",
              prefixIcon: Icon(Icons.money, color: _teal, size: 18),
              suffixText: "TL",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _teal, width: 1.5),
              ),
              helperText: "Maksimum: ${remaining.toStringAsFixed(0)} TL",
              helperStyle: TextStyle(color: _textSecondary, fontSize: 11),
            ),
          ),
          const SizedBox(height: 16),
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
                          size: 18,
                          color: _teal,
                        ),
                        const SizedBox(width: 8),
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
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _borderLight),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: noteController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: "Açıklama (Opsiyonel)",
              prefixIcon: Icon(Icons.note, color: _teal, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _borderLight),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () => _processPaymentForMissingMonth(date, remaining),
              style: ElevatedButton.styleFrom(
                backgroundColor: headerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
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
                        fontSize: 15,
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
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.warning_amber_rounded, size: 44, color: Colors.orange),
            SizedBox(height: 12),
            Text(
              "Aylık Ücret Tanımlanmamış",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
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
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Bu ayın ödemesi tamamlanmıştır.",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                ),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.pending,
                  color: Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Bu Ay Ödemesi",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Bu ay için aylık ücret: ${currentMonthlyFee.toStringAsFixed(0)} TL • Kalan: ${remaining.toStringAsFixed(0)} TL",
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
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
        .where(
          (p) =>
              !p.note.contains("FEE_UPDATE:") && !p.note.contains("OVERRIDE:"),
        )
        .toList();
    final overrides = payments
        .where((p) => p.note.contains("OVERRIDE:"))
        .toList();

    if (regularPayments.isEmpty && feeUpdates.isEmpty && overrides.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.history, size: 48, color: _textSub),
            SizedBox(height: 12),
            Text(
              "Bu yıl henüz ödeme kaydı yok",
              style: TextStyle(fontSize: 13, color: _textSecondary),
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
    for (var p in overrides) {
      allItems.add({
        'type': 'override',
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.history, color: _teal, size: 20),
                const SizedBox(width: 8),
                Text(
                  "$_selectedYear Yılı Ödeme Geçmişi",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                if (feeUpdates.isNotEmpty || overrides.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${feeUpdates.length + overrides.length} düzeltme",
                      style: TextStyle(fontSize: 11, color: _teal),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _borderLight),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shown.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: _borderLight, indent: 16),
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.update, size: 20, color: _teal),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Ücret Güncellemesi: $newFee TL",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDateFromString(p.paid_date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: _textSub, size: 18),
                      ],
                    ),
                  ),
                );
              } else if (item['type'] == 'override') {
                final p = item['data'] as Payment;
                final amount =
                    double.tryParse(p.amount)?.toStringAsFixed(0) ?? p.amount;
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.edit, size: 20, color: Colors.blue),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Ücret Düzeltme (Override): $amount TL",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDateFromString(p.paid_date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: _textSub, size: 18),
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Colors.orange.shade100
                                : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isCurrent ? Icons.pending : Icons.receipt,
                            size: 20,
                            color: isCurrent ? Colors.orange : _teal,
                          ),
                        ),
                        const SizedBox(width: 14),
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
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${p.payment_method} · ${_formatDateFromString(p.paid_date)}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: _textSub, size: 18),
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
                style: TextStyle(color: _textSub, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _red.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
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
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(_historicalDebtExpanded ? 0 : 24),
                  bottomRight: Radius.circular(
                    _historicalDebtExpanded ? 0 : 24,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.history, color: _red, size: 22),
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
                            fontSize: 15,
                            color: _textPrimary,
                          ),
                        ),
                        Text(
                          "Kayıt: $registrationYear • $yearRange",
                          style: TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _red,
                      borderRadius: BorderRadius.circular(30),
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
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _red,
                      size: 24,
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
                const Divider(height: 1, thickness: 1, color: _borderLight),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: debts.map((debt) {
                      final year = debt['year'] as int;
                      final months =
                          debt['months'] as List<Map<String, dynamic>>;
                      final yDebt = debt['totalDebt'] as double;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _red.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _red.withOpacity(0.08),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
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
                                      fontSize: 14,
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
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: months.map((m) {
                                  final remaining = m['remaining'] as double;
                                  final paid = m['paid'] as double;
                                  final required = m['required'] as double;
                                  final pct = required > 0
                                      ? (paid / required).clamp(0.0, 1.0)
                                      : 0.0;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
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
                                                color: _textPrimary,
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
                                                    BorderRadius.circular(20),
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
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
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
                                              minHeight: 5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              "${paid.toStringAsFixed(0)} / ${required.toStringAsFixed(0)} TL ödendi",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: _textSecondary,
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
            duration: const Duration(milliseconds: 280),
          ),
        ],
      ),
    );
  }

  // 🔥 Geçmiş ay için default ödeme tarihini hesapla (o ayın 15'i)
  DateTime _getDefaultDueDate(DateTime selectedMonth) {
    // Seçilen ayın 15'i
    DateTime defaultDate = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      15,
    );

    // Eğer 15 geçersizse (örneğin Şubat 29 çekmiyorsa) ayın son gününü al
    if (defaultDate.day != 15) {
      defaultDate = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    }

    return defaultDate;
  }

  DateTime _getDefaultPaymentDate(DateTime forMonth) {
    try {
      return DateTime(forMonth.year, forMonth.month, 15);
    } catch (e) {
      // 15 geçerli değilse (Şubat 29 vs) ayın son gününü al
      return DateTime(forMonth.year, forMonth.month + 1, 0);
    }
  }
}
