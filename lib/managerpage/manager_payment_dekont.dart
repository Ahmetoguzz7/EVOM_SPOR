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

  // Yıl seçimi için
  int _selectedYear = DateTime.now().year;
  late int _previousYear;
  late int _currentYear;

  // Seçilen eksik ay (ödemesi yapılacak ay)
  DateTime? _selectedMissingMonth;

  List<Group> studentGroups = [];
  List<Payment> paymentHistory = [];
  String? selectedGroupId;
  String selectedGroupName = "";
  double monthlyFee = 0;

  final List<String> paymentMethods = [
    "Nakit",
    "Kredi Kartı",
    "Havale/EFT",
    "Mail Order",
  ];

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime.now().year;
    _previousYear = _currentYear - 1;
    _selectedYear = _currentYear;
    _allDataFuture = _loadAllData();
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

  int _getCurrentYear() {
    return DateTime.now().year;
  }

  int _getCurrentMonth() {
    return DateTime.now().month;
  }

  String _getCurrentMonthYear() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      if (dateStr.contains('T')) {
        dateStr = dateStr.split('T')[0];
      }
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return "${parts[2]}/${parts[1]}/${parts[0]}";
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDisplayDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  String _formatMonthYear(String monthYear) {
    if (monthYear.isEmpty) return monthYear;
    try {
      if (monthYear.contains('-') && monthYear.length >= 7) {
        final parts = monthYear.split('-');
        final year = parts[0];
        final month = int.parse(parts[1]);
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
        return "${months[month - 1]} $year";
      }
      return monthYear;
    } catch (e) {
      return monthYear;
    }
  }

  // =========================================================================
  // TARİH PARSE FONKSİYONLARI
  // =========================================================================

  int? _getYearFromDueDate(String dueDate) {
    if (dueDate.isEmpty) return null;

    if (dueDate.contains('-') && dueDate.length >= 10) {
      return int.tryParse(dueDate.substring(0, 4));
    }

    final months = {
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

    for (var entry in months.entries) {
      if (dueDate.contains(entry.key)) {
        final yearMatch = RegExp(r'\d{4}').firstMatch(dueDate);
        if (yearMatch != null) {
          return int.parse(yearMatch.group(0)!);
        }
      }
    }
    return null;
  }

  int? _getMonthFromDueDate(String dueDate) {
    if (dueDate.isEmpty) return null;

    if (dueDate.contains('-') && dueDate.length >= 10) {
      return int.tryParse(dueDate.substring(5, 7));
    }

    final months = {
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

    for (var entry in months.entries) {
      if (dueDate.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  // =========================================================================
  // SEÇİLİ YILA GÖRE FİLTRELEME
  // =========================================================================

  List<Payment> _getPaymentsForYear(int year) {
    return paymentHistory.where((p) {
      int? paymentYear = _getYearFromDueDate(p.due_date);
      return paymentYear == year && p.status == "paid";
    }).toList();
  }

  List<DateTime> _getMonthsOfYear(int year) {
    List<DateTime> months = [];
    final now = DateTime.now();

    for (int month = 1; month <= 12; month++) {
      final monthDate = DateTime(year, month, 1);
      if (year < _currentYear) {
        months.add(monthDate);
      } else if (year == _currentYear) {
        if (monthDate.isBefore(DateTime(now.year, now.month + 1, 1))) {
          months.add(monthDate);
        }
      }
    }
    return months;
  }

  double _getPaidAmountForExactMonth(int year, int month) {
    double total = 0;
    final yearPayments = _getPaymentsForYear(year);

    for (var p in yearPayments) {
      int? paymentYear = _getYearFromDueDate(p.due_date);
      int? paymentMonth = _getMonthFromDueDate(p.due_date);

      if (paymentYear == year && paymentMonth == month) {
        total += double.tryParse(p.amount) ?? 0;
      }
    }
    return total;
  }

  // EKSİK AYLAR: Geçmiş aylar (içinde bulunduğumuz aydan öncekiler) + Cari ay (eğer bitmişse)
  // Yani: Ödenmemiş HERHANGİ bir ay varsa, onu eksik olarak göster
  List<Map<String, dynamic>> _getMissingPaymentsForYear(int year) {
    List<Map<String, dynamic>> missingMonths = [];
    final allMonths = _getMonthsOfYear(year);
    final currentMonth = _getCurrentMonth();
    final now = DateTime.now();

    for (var month in allMonths) {
      final paid = _getPaidAmountForExactMonth(year, month.month);
      final required = monthlyFee;
      final remaining = required - paid;

      // Eğer ödenmemişse (remaining > 0)
      if (remaining > 0.01) {
        // Ay bitmiş mi kontrol et (içinde bulunduğumuz aydan küçükse bitmiştir)
        // VEYA aynı ay ama ay bitmiş mi? (Örneğin 30 Haziran'dan sonra Haziran da bitmiş sayılır)
        bool isMonthOver = false;

        if (year < _currentYear) {
          isMonthOver = true; // Geçmiş yıl kesin bitmiş
        } else if (year == _currentYear) {
          if (month.month < currentMonth) {
            isMonthOver = true; // Geçmiş ay (Örn: Mayıs, Haziran'dan önce)
          } else if (month.month == currentMonth) {
            // Aynı ay içindeyiz, ayın son günü geçti mi kontrol et
            final lastDayOfMonth = DateTime(year, month.month + 1, 0);
            isMonthOver = now.isAfter(lastDayOfMonth);
          }
        }

        missingMonths.add({
          'date': month,
          'required': required,
          'paid': paid,
          'remaining': remaining,
          'monthName': _formatMonthYear(
            "${year}-${month.month.toString().padLeft(2, '0')}",
          ),
          'isMonthOver':
              isMonthOver, // Ay bitmiş mi? (bitmişse ödemesi zorunlu)
          'isCurrentMonth':
              (year == _currentYear && month.month == currentMonth),
        });
      }
    }

    // Sırala: Önce bitmiş aylar, sonra cari ay
    missingMonths.sort((a, b) {
      if (a['isMonthOver'] && !b['isMonthOver']) return -1;
      if (!a['isMonthOver'] && b['isMonthOver']) return 1;
      return (a['date'] as DateTime).compareTo(b['date'] as DateTime);
    });

    return missingMonths;
  }

  double _getTotalReceivedForYear(int year) {
    double total = 0;
    final yearPayments = _getPaymentsForYear(year);
    for (var p in yearPayments) {
      total += double.tryParse(p.amount) ?? 0;
    }
    return total;
  }

  double _getExpectedAnnualForYear(int year) {
    return monthlyFee * 12;
  }

  // Aylık durum kartı için (yeşil, turuncu, kırmızı)
  List<Map<String, dynamic>> _getMonthlyPaymentStatusForYear(int year) {
    List<Map<String, dynamic>> monthlyStatus = [];
    final allMonths = _getMonthsOfYear(year);
    final currentMonth = _getCurrentMonth();
    final now = DateTime.now();

    for (var month in allMonths) {
      final paid = _getPaidAmountForExactMonth(year, month.month);
      final required = monthlyFee;
      final remaining = required - paid;
      final isFullyPaid = remaining <= 0.01;

      String status;
      if (isFullyPaid) {
        status = "paid"; // Yeşil
      } else {
        // Ay bitmiş mi kontrol et
        bool isMonthOver = false;
        if (year < _currentYear) {
          isMonthOver = true;
        } else if (year == _currentYear) {
          if (month.month < currentMonth) {
            isMonthOver = true;
          } else if (month.month == currentMonth) {
            final lastDayOfMonth = DateTime(year, month.month + 1, 0);
            isMonthOver = now.isAfter(lastDayOfMonth);
          }
        }

        if (isMonthOver) {
          status = "overdue"; // Geçmiş ve ödenmemiş - KIRMIZI
        } else {
          status = "current"; // Cari ay (henüz bitmemiş) - TURUNCU
        }
      }

      monthlyStatus.add({
        'date': month,
        'required': required,
        'paid': paid,
        'remaining': remaining > 0 ? remaining : 0,
        'isFullyPaid': isFullyPaid,
        'monthName': _formatMonthYear(
          "${year}-${month.month.toString().padLeft(2, '0')}",
        ),
        'status': status,
      });
    }
    return monthlyStatus;
  }

  // =========================================================================
  // VERİ YÜKLEME
  // =========================================================================

  Future<Map<String, dynamic>> _loadAllData() async {
    try {
      final allGroups = await GoogleSheetService.getGroupsCached();
      final allRelations = await GoogleSheetService.getGroupStudentsCached();
      final allUsers = await GoogleSheetService.getUsersCached();
      final allPayments = await GoogleSheetService.getPaymentsCached();

      final currentStudent = allUsers.firstWhere(
        (u) => u.app == widget.student.app,
        orElse: () => widget.student,
      );

      monthlyFee = double.tryParse(currentStudent.amount) ?? 0;

      final groupRelations = allRelations
          .where(
            (rel) =>
                rel.student_id == widget.student.app &&
                rel.is_active.toString().toUpperCase() == "TRUE",
          )
          .toList();

      final groupIds = groupRelations.map((rel) => rel.groups_id).toList();
      final groups = allGroups
          .where((g) => groupIds.contains(g.groups_id))
          .toList();

      studentGroups = groups;
      if (groups.isNotEmpty) {
        selectedGroupId = groups.first.groups_id;
        selectedGroupName = groups.first.name;
      }

      final history =
          allPayments
              .where(
                (p) => p.student_id == widget.student.app && p.status == "paid",
              )
              .toList()
            ..sort((a, b) => b.paid_date.compareTo(a.paid_date));

      paymentHistory = history;

      return {
        'studentGroups': studentGroups,
        'selectedGroupId': selectedGroupId,
        'selectedGroupName': selectedGroupName,
        'monthlyFee': monthlyFee,
        'paymentHistory': paymentHistory,
        'currentYear': _currentYear,
        'previousYear': _previousYear,
      };
    } catch (e) {
      print("Veri yükleme hatası: $e");
      return {
        'studentGroups': <Group>[],
        'selectedGroupId': null,
        'selectedGroupName': "",
        'monthlyFee': 0.0,
        'paymentHistory': <Payment>[],
        'currentYear': _currentYear,
        'previousYear': _previousYear,
      };
    }
  }

  // =========================================================================
  // AYLIK ÜCRET GÜNCELLEME
  // =========================================================================

  Future<void> _updateMonthlyFee() async {
    final TextEditingController feeController = TextEditingController(
      text: monthlyFee.toStringAsFixed(0),
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aylık Ücreti Güncelle'),
        content: TextField(
          controller: feeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Yeni Aylık Ücret (TL)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newFee = double.tryParse(feeController.text) ?? 0;
              if (newFee > 0) {
                setState(() => isProcessing = true);
                bool success = await GoogleSheetService.updateUserAmount(
                  widget.student.app,
                  newFee,
                );
                setState(() => isProcessing = false);

                if (success) {
                  setState(() => monthlyFee = newFee);
                  _allDataFuture = _loadAllData();
                  setState(() {});
                  _showSnackBar(
                    'Aylık ücret güncellendi: ${newFee.toStringAsFixed(0)} TL',
                  );
                  Navigator.pop(context);
                } else {
                  _showSnackBar('Ücret güncellenemedi!', isError: true);
                }
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

  // =========================================================================
  // ÖDEME İŞLEMLERİ
  // =========================================================================

  Future<void> _selectPaymentDateForMissingMonth(DateTime missingMonth) async {
    // Seçilen ayın ilk günü
    final firstDay = DateTime(missingMonth.year, missingMonth.month, 1);
    // Seçilen ayın son günü
    final lastDay = DateTime(missingMonth.year, missingMonth.month + 1, 0);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: firstDay, // İlk günü göster
      firstDate: firstDay, // En erken seçilebilecek tarih: ayın 1'i
      lastDate: lastDay, // En geç seçilebilecek tarih: ayın son günü
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
      _showSnackBar("Lütfen bir tutar girin!", isError: true);
      return;
    }

    if (selectedGroupId == null) {
      _showSnackBar(
        "Öğrencinin kayıtlı olduğu grup bulunamadı!",
        isError: true,
      );
      return;
    }

    final tutar = double.tryParse(amountController.text) ?? 0;

    if (tutar > requiredAmount) {
      _showSnackBar(
        "Bu ay için kalan borç ${requiredAmount.toStringAsFixed(0)} TL. Daha fazla ödeme yapamazsınız!",
        isError: true,
      );
      return;
    }

    setState(() => isProcessing = true);

    final paymentMonth =
        "${missingMonth.year}-${missingMonth.month.toString().padLeft(2, '0')}-01";
    final formattedDate =
        "${selectedPaymentDate.year}-${selectedPaymentDate.month.toString().padLeft(2, '0')}-${selectedPaymentDate.day.toString().padLeft(2, '0')}";

    final newPayment = Payment(
      payments_id: "",
      student_id: widget.student.app,
      groups_id: selectedGroupId!,
      recorded_by: "Admin",
      amount: amountController.text,
      due_date: paymentMonth,
      paid_date: formattedDate,
      status: "paid",
      payment_method: selectedMethod,
      note: noteController.text.trim(),
    );

    bool success = await GoogleSheetService.addPayment(newPayment);
    setState(() => isProcessing = false);

    if (success) {
      _allDataFuture = _loadAllData();
      setState(() {
        _selectedMissingMonth = null;
        amountController.clear();
        noteController.clear();
      });
      _showSnackBar(
        "${_formatMonthYear(paymentMonth)} ödemesi başarıyla kaydedildi!",
        isError: false,
      );
    } else {
      _showSnackBar(
        "Ödeme kaydedilemedi! Lütfen tekrar deneyin.",
        isError: true,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =========================================================================
  // UI BİLEŞENLERİ
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Ödeme İşlemleri",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
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
              child: CircularProgressIndicator(color: Colors.teal),
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
                        setState(() => _allDataFuture = _loadAllData()),
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;

          final totalReceived = _getTotalReceivedForYear(_selectedYear);
          final expectedAnnual = _getExpectedAnnualForYear(_selectedYear);
          final missingPayments = _getMissingPaymentsForYear(_selectedYear);
          final monthlyStatus = _getMonthlyPaymentStatusForYear(_selectedYear);

          double collectionRate = 0;
          if (expectedAnnual > 0 && totalReceived > 0) {
            collectionRate = (totalReceived / expectedAnnual) * 100;
            if (collectionRate.isNaN || collectionRate.isInfinite) {
              collectionRate = 0;
            }
            collectionRate = collectionRate.clamp(0.0, 100.0);
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.white,
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
                      const SizedBox(height: 16),
                      _buildMonthlyPaymentStatusCard(
                        monthlyStatus,
                        _selectedYear,
                      ),
                      const SizedBox(height: 16),
                      if (missingPayments.isNotEmpty)
                        _buildMissingPaymentsCard(missingPayments, monthlyFee),
                      const SizedBox(height: 16),
                      _buildPaymentFormCard(),
                      const SizedBox(height: 16),
                      _buildPaymentHistoryCard(),
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

  Widget _buildYearButton(int year) {
    final isSelected = _selectedYear == year;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedYear = year;
            _selectedMissingMonth = null;
            amountController.clear();
            noteController.clear();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              "$year",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYearlyStatsCard(
    int year,
    double totalReceived,
    double expectedAnnual,
    double collectionRate,
  ) {
    final safeRate = collectionRate.isNaN || collectionRate.isInfinite
        ? 0
        : collectionRate;

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
          Expanded(
            child: Column(
              children: [
                Text(
                  "$year",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  "YILI",
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          Expanded(
            child: Column(
              children: [
                Text(
                  "${totalReceived.toStringAsFixed(0)} TL",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  "TAHSİLAT",
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          Expanded(
            child: Column(
              children: [
                Text(
                  "${expectedAnnual.toStringAsFixed(0)} TL",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  "BEKLENEN",
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          Expanded(
            child: Column(
              children: [
                Text(
                  "${safeRate.toStringAsFixed(0)}%",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  "ORAN",
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyPaymentStatusCard(
    List<Map<String, dynamic>> monthlyStatus,
    int year,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
              const Icon(Icons.calendar_today, size: 18, color: Colors.teal),
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
            itemBuilder: (context, index) {
              final item = monthlyStatus[index];
              final isFullyPaid = item['isFullyPaid'];
              final paid = item['paid'];
              final required = item['required'];
              final monthName = item['monthName'];
              final status = item['status'];

              Color bgColor;
              if (isFullyPaid) {
                bgColor = Colors.green.shade100;
              } else if (status == "current") {
                bgColor = Colors.orange.shade100;
              } else {
                bgColor = Colors.red.shade100;
              }

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
                      monthName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${paid.toStringAsFixed(0)}/${required.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 9),
                    ),
                    if (isFullyPaid)
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green,
                      )
                    else if (status == "current")
                      const Icon(Icons.pending, size: 14, color: Colors.orange)
                    else
                      const Icon(Icons.cancel, size: 14, color: Colors.red),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                    errorWidget: (_, __, ___) => Container(
                      width: 55,
                      height: 55,
                      color: Colors.teal.shade100,
                      child: Center(
                        child: Text(
                          widget.student.first_name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    width: 55,
                    height: 55,
                    color: Colors.teal.shade100,
                    child: Center(
                      child: Text(
                        widget.student.first_name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  ),
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
                    Icon(Icons.group, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        selectedGroupName,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.money, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      monthlyFee > 0
                          ? "${monthlyFee.toStringAsFixed(0)} TL/Ay"
                          : "Ücret yok",
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _updateMonthlyFee,
            icon: const Icon(Icons.edit, size: 18, color: Colors.teal),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // EKSİK ÖDEMELER KARTI (ÖNCE BİTMİŞ AYLAR, SONRA CARİ AYLAR)
  // =========================================================================

  Widget _buildMissingPaymentsCard(
    List<Map<String, dynamic>> missingPayments,
    double monthlyFee,
  ) {
    double totalDebt = missingPayments.fold(
      0,
      (sum, item) => sum + (item['remaining'] as double),
    );

    if (_selectedMissingMonth != null) {
      final selectedMissing = missingPayments.firstWhere(
        (item) =>
            (item['date'] as DateTime).year == _selectedMissingMonth!.year &&
            (item['date'] as DateTime).month == _selectedMissingMonth!.month,
        orElse: () => {},
      );
      if (selectedMissing.isNotEmpty) {
        return _buildPaymentFormForMissingMonth(selectedMissing);
      }
    }

    // Ayırt et: Geçmiş aylar (overdue) ve cari ay (current)
    final overdueMonths = missingPayments
        .where((m) => m['isMonthOver'] == true)
        .toList();
    final currentMonth = missingPayments
        .where((m) => m['isCurrentMonth'] == true && m['isMonthOver'] == false)
        .toList();

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
              const Icon(Icons.warning_amber, color: Colors.red, size: 20),
              const SizedBox(width: 6),
              const Text(
                'Ödenmemiş Aylar',
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
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${totalDebt.toStringAsFixed(0)} TL',
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

          // Bitmiş aylar (ödenmesi ZORUNLU)
          if (overdueMonths.isNotEmpty) ...[
            const Text(
              '📅 Geçmiş Aylar (Ödenmesi Zorunlu):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: overdueMonths.map((item) {
                final date = item['date'] as DateTime;
                final remaining = item['remaining'];
                final monthName = item['monthName'];
                return _buildPaymentButton(
                  date,
                  remaining,
                  monthName,
                  Colors.red,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Cari ay (bitmemiş ama ödenmemiş)
          if (currentMonth.isNotEmpty) ...[
            const Text(
              '📌 Bu Ay (Ödeme Yapılabilir):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: currentMonth.map((item) {
                final date = item['date'] as DateTime;
                final remaining = item['remaining'];
                final monthName = item['monthName'];
                return _buildPaymentButton(
                  date,
                  remaining,
                  monthName,
                  Colors.orange,
                );
              }).toList(),
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
                    'Kırmızı ayların ödemesi ZORUNLUDUR. Turuncu ay ise içinde bulunduğumuz aydır, ödemesi yapılabilir.',
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
      onTap: () {
        setState(() {
          _selectedMissingMonth = date;
          amountController.clear();
          noteController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${remaining.toStringAsFixed(0)} TL',
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

  // Eksik ay için ödeme formu
  Widget _buildPaymentFormForMissingMonth(Map<String, dynamic> missingMonth) {
    final date = missingMonth['date'] as DateTime;
    final remaining = missingMonth['remaining'];
    final monthName = missingMonth['monthName'];
    final isMonthOver = missingMonth['isMonthOver'];

    Color headerColor = isMonthOver ? Colors.red : Colors.orange;
    String headerText = isMonthOver
        ? "Geçmiş Ay Ödemesi (Zorunlu)"
        : "Bu Ay Ödemesi";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  color: headerColor,
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
                      "Kalan Borç: ${remaining.toStringAsFixed(0)} TL",
                      style: TextStyle(
                        fontSize: 12,
                        color: headerColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      headerText,
                      style: TextStyle(fontSize: 10, color: headerColor),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedMissingMonth = null;
                    amountController.clear();
                    noteController.clear();
                  });
                },
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
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.teal,
                    size: 18,
                  ),
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
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: "Ödenecek Tutar",
              hintText: "0.00",
              prefixIcon: const Icon(Icons.money, color: Colors.teal, size: 18),
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
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 6),
                        Text(m, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => selectedMethod = val!),
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
              hintText:
                  "${_formatMonthYear("${date.year}-${date.month.toString().padLeft(2, '0')}")} ödemesi...",
              prefixIcon: const Icon(Icons.note, color: Colors.teal, size: 18),
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
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isMonthOver
                          ? "Geçmiş Ay Ödemesini Yap (Zorunlu)"
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
          color: Colors.white,
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
            SizedBox(height: 4),
            Text(
              "Lütfen önce ücret tanımlayın.",
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      );
    }

    if (_selectedMissingMonth != null) {
      return const SizedBox.shrink();
    }

    // Cari ay bilgileri
    final currentMonth = _getCurrentMonth();
    final currentYear = _getCurrentYear();
    final paidThisMonth = _getPaidAmountForExactMonth(
      currentYear,
      currentMonth,
    );
    final remainingDebt = monthlyFee - paidThisMonth;
    final isCurrentMonthPaid = remainingDebt <= 0.01;

    if (isCurrentMonthPaid) {
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
        color: Colors.white,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bu ay için kalan borç: ${remainingDebt.toStringAsFixed(0)} TL",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const Text(
                        "Ödeme yapmak için yukarıdaki turuncu butona tıklayın.",
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
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
    final selectedYearPayments = _getPaymentsForYear(_selectedYear);

    if (selectedYearPayments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
                Icon(Icons.history, color: Colors.teal, size: 18),
                const SizedBox(width: 6),
                Text(
                  "$_selectedYear Yılı Ödeme Geçmişi",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: selectedYearPayments.length > 8
                ? 8
                : selectedYearPayments.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
            itemBuilder: (context, index) {
              final payment = selectedYearPayments[index];
              final paymentMonth = _getMonthFromDueDate(payment.due_date);
              final isCurrentMonth =
                  paymentMonth == _getCurrentMonth() &&
                  _selectedYear == _currentYear;
              return ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isCurrentMonth
                        ? Colors.orange.shade100
                        : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isCurrentMonth ? Icons.pending : Icons.receipt,
                    size: 18,
                    color: isCurrentMonth ? Colors.orange : Colors.teal,
                  ),
                ),
                title: Text(
                  "${double.tryParse(payment.amount)?.toStringAsFixed(0) ?? payment.amount} TL",
                  style: TextStyle(
                    fontWeight: isCurrentMonth
                        ? FontWeight.bold
                        : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  "${payment.payment_method} • ${_formatDate(payment.paid_date)}",
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                trailing: payment.note.isNotEmpty
                    ? Icon(
                        Icons.note_alt,
                        color: Colors.grey.shade400,
                        size: 16,
                      )
                    : null,
              );
            },
          ),
          if (selectedYearPayments.length > 8)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                "+ ${selectedYearPayments.length - 8} kayıt daha",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
