import 'package:flutter/material.dart';
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

  List<Group> studentGroups = [];
  List<Payment> paymentHistory = [];
  bool isLoadingGroups = true;
  bool isLoadingHistory = true;
  bool isLoadingParent = true;

  String? selectedGroupId;
  String selectedGroupName = "";
  double monthlyFee = 0;

  Users? parentInfo;

  final List<String> paymentMethods = [
    "Nakit",
    "Kredi Kartı",
    "Havale/EFT",
    "Mail Order",
  ];

  @override
  void initState() {
    super.initState();
    _allDataFuture = _loadAllData();
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  // =========================================================================
  // YARDIMCI FONKSİYONLAR (DateFormat YERİNE)
  // =========================================================================

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
    if (monthYear.isEmpty || monthYear.length < 7) return monthYear;
    try {
      final parts = monthYear.split('-');
      if (parts.length != 2) return monthYear;
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
    } catch (e) {
      return monthYear;
    }
  }

  String _formatPaymentMonth(String dueDate) {
    if (dueDate.isEmpty || dueDate.length < 7) return dueDate;
    try {
      final parts = dueDate.substring(0, 7).split('-');
      if (parts.length == 2) {
        return "${parts[1]}/${parts[0]}";
      }
      return dueDate;
    } catch (e) {
      return dueDate;
    }
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

      // Parent bilgisi
      try {
        final parentRelations = await GoogleSheetService.getParentsByStudent(
          widget.student.app,
        );
        if (parentRelations.isNotEmpty) {
          final parentId = parentRelations.first.parent_id;
          final parent = allUsers.firstWhere(
            (u) => u.app == parentId,
            orElse: () => Users(
              app: "",
              branches_id: "",
              first_name: "Bilinmeyen",
              last_name: "Veli",
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
          parentInfo = parent;
        }
      } catch (e) {
        parentInfo = null;
      }

      return {
        'studentGroups': studentGroups,
        'selectedGroupId': selectedGroupId,
        'selectedGroupName': selectedGroupName,
        'monthlyFee': monthlyFee,
        'paymentHistory': paymentHistory,
        'parentInfo': parentInfo,
      };
    } catch (e) {
      print("Veri yükleme hatası: $e");
      return {
        'studentGroups': <Group>[],
        'selectedGroupId': null,
        'selectedGroupName': "",
        'monthlyFee': 0.0,
        'paymentHistory': <Payment>[],
        'parentInfo': null,
      };
    }
  }

  // =========================================================================
  // ÖDEME HESAPLAMA
  // =========================================================================

  int? _getYearFromDueDate(String dueDate) {
    if (dueDate.isEmpty) return null;
    if (dueDate.contains('-')) {
      return int.tryParse(dueDate.substring(0, 4));
    }
    return null;
  }

  int? _getMonthFromDueDate(String dueDate) {
    if (dueDate.isEmpty) return null;
    if (dueDate.contains('-') && dueDate.length >= 10) {
      return int.tryParse(dueDate.substring(5, 7));
    }
    return null;
  }

  double _getPaidAmountForMonth(String studentId, String monthYear) {
    double total = 0;
    List<String> targetParts = monthYear.split('-');
    if (targetParts.length != 2) return 0;

    int targetYear = int.parse(targetParts[0]);
    int targetMonth = int.parse(targetParts[1]);

    for (var p in paymentHistory) {
      if (p.student_id != studentId) continue;
      if (p.status != "paid") continue;

      int? paymentYear = _getYearFromDueDate(p.due_date);
      int? paymentMonth = _getMonthFromDueDate(p.due_date);

      if (paymentYear != null && paymentMonth != null) {
        if (paymentYear == targetYear && paymentMonth == targetMonth) {
          total += double.tryParse(p.amount) ?? 0;
        }
      }
    }
    return total;
  }

  double _getPaidForCurrentMonth() {
    final currentMonth = _getCurrentMonthYear();
    return _getPaidAmountForMonth(widget.student.app, currentMonth);
  }

  double _getRemainingDebtForCurrentMonth() {
    if (monthlyFee == 0) return 0;
    final paidThisMonth = _getPaidForCurrentMonth();
    final remaining = monthlyFee - paidThisMonth;
    return remaining > 0 ? remaining : 0;
  }

  // =========================================================================
  // ÖDEME İŞLEMLERİ
  // =========================================================================

  Future<void> _selectPaymentDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedPaymentDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedPaymentDate) {
      setState(() {
        selectedPaymentDate = picked;
      });
    }
  }

  Future<void> _processPayment() async {
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

    if (monthlyFee == 0) {
      _showSnackBar("Aylık ücret tanımlanmamış!", isError: true);
      return;
    }

    final tutar = double.tryParse(amountController.text) ?? 0;
    final kalanBorc = _getRemainingDebtForCurrentMonth();

    if (tutar > kalanBorc && kalanBorc > 0) {
      _showSnackBar(
        "Girilen tutar kalan borçtan ($kalanBorc TL) fazla olamaz!",
        isError: true,
      );
      return;
    }

    setState(() => isProcessing = true);

    final paymentMonth =
        "${selectedPaymentDate.year}-${selectedPaymentDate.month.toString().padLeft(2, '0')}-01";
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
      await _loadAllData();
      setState(() {});
      _showReceiptDialog(newPayment);
      amountController.clear();
      noteController.clear();
      _showSnackBar("Ödeme başarıyla kaydedildi!", isError: false);
      Navigator.pop(context, true);
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

  void _showReceiptDialog(Payment payment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text(
                  "İşlem Başarılı",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.teal.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    "${payment.amount} TL",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    "Öğrenci",
                    "${widget.student.first_name} ${widget.student.last_name}",
                  ),
                  _detailRow("Yöntem", payment.payment_method),
                  _detailRow(
                    "Dönem",
                    _formatMonthYear(payment.due_date.substring(0, 7)),
                  ),
                  _detailRow("Tarih", _formatDate(payment.paid_date)),
                  if (payment.note.isNotEmpty) _detailRow("Not", payment.note),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Kapat",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptDetail(Payment payment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt, color: Colors.teal, size: 28),
                SizedBox(width: 12),
                Text(
                  "Ödeme Detayı",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    "${payment.amount} TL",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _detailRow("Yöntem", payment.payment_method),
                  _detailRow(
                    "Dönem",
                    _formatMonthYear(payment.due_date.substring(0, 7)),
                  ),
                  _detailRow("Tarih", _formatDate(payment.paid_date)),
                  if (payment.note.isNotEmpty) _detailRow("Not", payment.note),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Kapat",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
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
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Ana sayfayı yeniden başlatmadan geri dön
            Navigator.pop(context);
          },
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _allDataFuture = _loadAllData();
                      });
                    },
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          studentGroups = data['studentGroups'] ?? [];
          selectedGroupId = data['selectedGroupId'];
          selectedGroupName = data['selectedGroupName'] ?? "";
          monthlyFee = data['monthlyFee'] ?? 0.0;
          paymentHistory = data['paymentHistory'] ?? [];
          parentInfo = data['parentInfo'];

          final currentMonth = _getCurrentMonthYear();
          final paidThisMonth = _getPaidForCurrentMonth();
          final remainingDebt = _getRemainingDebtForCurrentMonth();
          final isFullyPaid = monthlyFee > 0 && remainingDebt == 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStudentCard(),
                const SizedBox(height: 16),
                _buildPaymentSummaryCard(
                  monthlyFee,
                  paidThisMonth,
                  remainingDebt,
                  currentMonth,
                  isFullyPaid,
                ),
                const SizedBox(height: 16),
                _buildPaymentFormCard(remainingDebt, isFullyPaid),
                const SizedBox(height: 16),
                _buildPaymentHistoryCard(currentMonth),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStudentCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
              ],
            ),
            child: Center(
              child: Text(
                widget.student.first_name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${widget.student.first_name} ${widget.student.last_name}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.student.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.group,
                      size: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      selectedGroupName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.attach_money,
                      size: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      monthlyFee > 0 ? "$monthlyFee TL/Ay" : "Ücret yok",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
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

  Widget _buildPaymentSummaryCard(
    double monthly,
    double paid,
    double remaining,
    String monthYear,
    bool isFullyPaid,
  ) {
    double progress = monthly > 0 ? paid / monthly : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Ödeme Dönemi: ${_formatMonthYear(monthYear)}",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isFullyPaid)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Ödendi",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatColumn(
                "Aylık Ücret",
                "${monthly.toStringAsFixed(0)} TL",
                Colors.blue,
              ),
              _buildStatColumn(
                "Ödenen",
                "${paid.toStringAsFixed(0)} TL",
                Colors.green,
              ),
              _buildStatColumn(
                "Kalan",
                "${remaining.toStringAsFixed(0)} TL",
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "%${(progress * 100).toStringAsFixed(0)} tamamlandı",
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPaymentFormCard(double remainingDebt, bool isFullyPaid) {
    if (monthlyFee == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Icon(Icons.warning_amber, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            const Text(
              "Aylık Ücret Tanımlanmamış",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Öğrencinin aylık ücreti tanımlanmamış. Lütfen önce ücret tanımlayın.",
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Yeni Ödeme",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _selectPaymentDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.teal,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDisplayDate(selectedPaymentDate),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              labelText: "Tutar",
              hintText: "0.00",
              prefixIcon: const Icon(Icons.money, color: Colors.teal),
              suffixText: "TL",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedMethod,
            items: paymentMethods.map((m) {
              return DropdownMenuItem(
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
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    Text(m),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) => setState(() => selectedMethod = val!),
            decoration: InputDecoration(
              labelText: "Ödeme Yöntemi",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: noteController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: "Açıklama (Opsiyonel)",
              hintText: "Ödeme ile ilgili not ekleyin...",
              prefixIcon: const Icon(Icons.note, color: Colors.teal),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal, width: 2),
              ),
            ),
          ),
          if (!isFullyPaid && remainingDebt > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Kalan Borç: ${remainingDebt.toStringAsFixed(2)} TL",
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: (isProcessing || isFullyPaid) ? null : _processPayment,
              child: isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Tahsil Et ve Kaydet",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryCard(String currentMonth) {
    if (paymentHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text("Henüz ödeme kaydı bulunmuyor"),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.teal, size: 22),
                SizedBox(width: 8),
                Text(
                  "Ödeme Geçmişi",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paymentHistory.length > 10 ? 10 : paymentHistory.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 20),
            itemBuilder: (context, index) {
              final payment = paymentHistory[index];
              final paymentMonth = payment.due_date.length >= 7
                  ? payment.due_date.substring(0, 7)
                  : payment.due_date;
              final isCurrentMonth = paymentMonth == currentMonth;
              return ListTile(
                leading: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: isCurrentMonth
                        ? Colors.amber.shade100
                        : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isCurrentMonth ? Icons.star : Icons.receipt,
                    color: isCurrentMonth ? Colors.amber : Colors.teal,
                  ),
                ),
                title: Text(
                  "${double.tryParse(payment.amount)?.toStringAsFixed(0) ?? payment.amount} TL",
                  style: TextStyle(
                    fontWeight: isCurrentMonth
                        ? FontWeight.bold
                        : FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  "${payment.payment_method} • ${_formatDate(payment.paid_date)}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: payment.note.isNotEmpty
                    ? Icon(
                        Icons.note_alt,
                        color: Colors.grey.shade400,
                        size: 20,
                      )
                    : null,
                onTap: () => _showReceiptDetail(payment),
              );
            },
          ),
          if (paymentHistory.length > 10)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  "+ ${paymentHistory.length - 10} daha fazla kayıt",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
