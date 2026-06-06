/*
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';

class AidatPage extends StatefulWidget {
  final Users user;
  final List<Payment> tumOdemeler;
  final List<Group> tumGruplar;
  final List<GroupStudent> tumGroupStudents;

  const AidatPage({
    super.key,
    required this.user,
    required this.tumOdemeler,
    required this.tumGruplar,
    required this.tumGroupStudents,
  });

  @override
  State<AidatPage> createState() => _AidatPageState();
}

class _AidatPageState extends State<AidatPage> {
  late Future<Map<String, dynamic>> _paymentDataFuture;

  @override
  void initState() {
    super.initState();
    _paymentDataFuture = _loadPaymentData();
  }

  Future<Map<String, dynamic>> _loadPaymentData() async {
    // Verileri hesapla
    final monthlyFee = _getMonthlyFee();
    final currentMonth = _getCurrentMonthYear();
    final paidThisMonth = _getPaidAmountForMonth(currentMonth);
    final remainingDebt = monthlyFee - paidThisMonth;
    final status = _getPaymentStatus(monthlyFee, paidThisMonth);
    final groupName = _getGroupName();

    final odemeler =
        widget.tumOdemeler
            .where((p) => p.student_id == widget.user.app)
            .toList()
          ..sort((a, b) => b.paid_date.compareTo(a.paid_date));

    return {
      'monthlyFee': monthlyFee,
      'currentMonth': currentMonth,
      'paidThisMonth': paidThisMonth,
      'remainingDebt': remainingDebt > 0 ? remainingDebt : 0,
      'status': status,
      'groupName': groupName,
      'odemeler': odemeler,
    };
  }

  // due_date'den yıl çek
  int? _getYearFromDueDate(String dueDate) {
    if (dueDate.isEmpty) return null;
    if (dueDate.contains('-')) {
      return int.tryParse(dueDate.substring(0, 4));
    } else if (dueDate.contains('.') && dueDate.split('.').length == 3) {
      var parts = dueDate.split('.');
      return int.tryParse(parts[2]);
    }
    return null;
  }

  // due_date'den ay çek
  int? _getMonthFromDueDate(String dueDate) {
    if (dueDate.isEmpty) return null;
    if (dueDate.contains('-') && dueDate.length >= 10) {
      return int.tryParse(dueDate.substring(5, 7));
    } else if (dueDate.contains('-') && dueDate.length == 7) {
      return int.tryParse(dueDate.substring(5, 7));
    } else if (dueDate.contains('.') && dueDate.split('.').length == 3) {
      var parts = dueDate.split('.');
      return int.tryParse(parts[1]);
    } else if (dueDate.contains('T')) {
      return int.tryParse(dueDate.substring(5, 7));
    }
    return null;
  }

  String _getStudentGroupId() {
    final relation = widget.tumGroupStudents.firstWhere(
      (r) =>
          r.student_id == widget.user.app &&
          r.is_active.toString().toUpperCase() == "TRUE",
      orElse: () => GroupStudent(
        group_students_id: "",
        groups_id: "",
        student_id: "",
        enrolled_at: "",
        is_active: "",
      ),
    );
    return relation.groups_id;
  }

  double _getMonthlyFee() {
    return double.tryParse(widget.user.amount) ?? 0;
  }

  String _getGroupName() {
    final groupId = _getStudentGroupId();
    if (groupId.isEmpty) return "Atanmamış";
    final group = widget.tumGruplar.firstWhere(
      (g) => g.groups_id == groupId,
      orElse: () => Group(
        groups_id: "",
        branches_id: "",
        coach_id: "",
        sports_id: "",
        name: "Grup Bulunamadı",
        schedule: "",
        capacity: "",
        monthly_fee: "0",
        is_active: "",
      ),
    );
    return group.name;
  }

  String _getCurrentMonthYear() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM').format(now);
  }

  double _getPaidAmountForMonth(String monthYear) {
    double total = 0;
    List<String> targetParts = monthYear.split('-');
    int targetYear = int.parse(targetParts[0]);
    int targetMonth = int.parse(targetParts[1]);

    for (var p in widget.tumOdemeler) {
      if (p.student_id != widget.user.app) continue;
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

  String _getPaymentStatus(double monthlyFee, double paidThisMonth) {
    if (monthlyFee == 0) return "unpaid";
    if (paidThisMonth >= monthlyFee) return "paid";
    if (paidThisMonth > 0) return "partial";
    return "unpaid";
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "paid":
        return Colors.green;
      case "partial":
        return Colors.orange;
      case "unpaid":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case "paid":
        return "Tamamlandı";
      case "partial":
        return "Kısmi Ödeme";
      case "unpaid":
        return "Ödenmedi";
      default:
        return "Belirsiz";
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
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

  void _showPaymentDetail(BuildContext context, Payment payment) {
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${payment.amount} TL",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _detailRow("Ödeme Yöntemi", payment.payment_method, Icons.payment),
            _detailRow(
              "Ödeme Tarihi",
              _formatDate(payment.paid_date),
              Icons.calendar_today,
            ),
            _detailRow(
              "Dönem",
              _formatMonthYear(payment.due_date.substring(0, 7)),
              Icons.date_range,
            ),
            if (payment.note.isNotEmpty)
              _detailRow("Not", payment.note, Icons.note),
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

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.teal.shade400),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Aidat Bilgilerim",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _paymentDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text("Aidat bilgileri yükleniyor..."),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text("Veriler yüklenirken hata oluştu"),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _paymentDataFuture = _loadPaymentData();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Tekrar Dene"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final monthlyFee = snapshot.data?['monthlyFee'] as double? ?? 0;
          final currentMonth = snapshot.data?['currentMonth'] as String? ?? "";
          final paidThisMonth = snapshot.data?['paidThisMonth'] as double? ?? 0;
          final remainingDebt = snapshot.data?['remainingDebt'] as double? ?? 0;
          final status = snapshot.data?['status'] as String? ?? "unpaid";
          final groupName = snapshot.data?['groupName'] as String? ?? "";
          final odemeler = snapshot.data?['odemeler'] as List<Payment>? ?? [];

          final statusColor = _getStatusColor(status);
          final statusText = _getStatusText(status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Özet Kartı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          status == "paid"
                              ? Icons.check_circle
                              : status == "partial"
                              ? Icons.warning_amber
                              : Icons.cancel,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        statusText,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatMonthYear(currentMonth),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem(
                              "Aylık Ücret",
                              "$monthlyFee TL",
                              Icons.money,
                            ),
                            _buildSummaryItem(
                              "Ödenen",
                              "$paidThisMonth TL",
                              Icons.payment,
                            ),
                            _buildSummaryItem(
                              "Kalan",
                              "${remainingDebt.toStringAsFixed(2)} TL",
                              Icons.warning,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Bilgi Kartı
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoTile(
                        "Öğrenci",
                        "${widget.user.first_name} ${widget.user.last_name}",
                        Icons.person_outline,
                        Colors.blue,
                      ),
                      _buildDivider(),
                      _buildInfoTile(
                        "Grup",
                        groupName,
                        Icons.group_outlined,
                        Colors.purple,
                      ),
                      _buildDivider(),
                      _buildInfoTile(
                        "Aylık Ücret",
                        "$monthlyFee TL",
                        Icons.money_outlined,
                        Colors.green,
                      ),
                      _buildDivider(),
                      _buildInfoTile(
                        "Ödeme Dönemi",
                        _formatMonthYear(currentMonth),
                        Icons.calendar_month,
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Ödeme Geçmişi
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.history, color: Colors.teal, size: 22),
                            SizedBox(width: 8),
                            Text(
                              "Ödeme Geçmişi",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (odemeler.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                "Henüz ödeme kaydı bulunmuyor",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: odemeler.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final p = odemeler[index];
                            final paymentMonth = p.due_date.length >= 7
                                ? p.due_date.substring(0, 7)
                                : p.due_date;
                            final isCurrentMonth = paymentMonth == currentMonth;
                            return InkWell(
                              onTap: () => _showPaymentDetail(context, p),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        color: isCurrentMonth
                                            ? statusColor.withOpacity(0.15)
                                            : Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isCurrentMonth
                                            ? Icons.star
                                            : Icons.receipt,
                                        color: isCurrentMonth
                                            ? statusColor
                                            : Colors.teal,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${p.amount} TL",
                                            style: TextStyle(
                                              fontWeight: isCurrentMonth
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "${p.payment_method} • ${_formatDate(p.paid_date)}",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            "Dönem: ${_formatMonthYear(paymentMonth)}",
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (p.note.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.note_alt,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.white.withOpacity(0.9)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 68);
  }
}
*/
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';

class AidatPage extends StatefulWidget {
  final Users user;
  final List<Payment> tumOdemeler;
  final List<Group> tumGruplar;
  final List<GroupStudent> tumGroupStudents;

  const AidatPage({
    super.key,
    required this.user,
    required this.tumOdemeler,
    required this.tumGruplar,
    required this.tumGroupStudents,
  });

  @override
  State<AidatPage> createState() => _AidatPageState();
}

class _AidatPageState extends State<AidatPage> {
  late Future<Map<String, dynamic>> _paymentDataFuture;

  // =========================================================================
  // 🔥 TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

  // Tarihi "dd MMMM yyyy" formatında göster (örn: 15 Ocak 2025)
  String _formatDateLongTurkish(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // Tarihi "dd/MM/yyyy" formatında göster
  String _formatDateShortTurkish(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // Ay ve yılı "MMMM yyyy" formatında göster (örn: Ocak 2025)
  String _formatMonthYearTurkish(String monthYear) {
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

  // Saatli tarih formatı (dd MMMM yyyy HH:mm)
  String _formatDateTimeTurkish(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMMM yyyy HH:mm', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // Kısa ay adı (Oca, Şub, Mar...)
  String _getShortMonthName(int month) {
    const months = [
      "Oca",
      "Şub",
      "Mar",
      "Nis",
      "May",
      "Haz",
      "Tem",
      "Ağu",
      "Eyl",
      "Eki",
      "Kas",
      "Ara",
    ];
    return months[month - 1];
  }

  @override
  void initState() {
    super.initState();
    _paymentDataFuture = _loadPaymentData();
  }

  Future<Map<String, dynamic>> _loadPaymentData() async {
    final monthlyFee = _getMonthlyFee();
    final currentMonth = _getCurrentMonthYear();
    final paidThisMonth = _getPaidAmountForMonth(currentMonth);
    final remainingDebt = monthlyFee - paidThisMonth;
    final status = _getPaymentStatus(monthlyFee, paidThisMonth);
    final groupName = _getGroupName();

    final odemeler =
        widget.tumOdemeler
            .where((p) => p.student_id == widget.user.app && p.status == "paid")
            .toList()
          ..sort((a, b) => b.paid_date.compareTo(a.paid_date));

    return {
      'monthlyFee': monthlyFee,
      'currentMonth': currentMonth,
      'paidThisMonth': paidThisMonth,
      'remainingDebt': remainingDebt > 0 ? remainingDebt : 0,
      'status': status,
      'groupName': groupName,
      'odemeler': odemeler,
    };
  }

  int? _getYearFromDueDate(String dueDate) {
    if (dueDate.isEmpty) return null;
    if (dueDate.contains('-')) {
      return int.tryParse(dueDate.substring(0, 4));
    } else if (dueDate.contains('.') && dueDate.split('.').length == 3) {
      var parts = dueDate.split('.');
      return int.tryParse(parts[2]);
    }
    return null;
  }

  int? _getMonthFromDueDate(String dueDate) {
    if (dueDate.isEmpty) return null;
    if (dueDate.contains('-') && dueDate.length >= 10) {
      return int.tryParse(dueDate.substring(5, 7));
    } else if (dueDate.contains('-') && dueDate.length == 7) {
      return int.tryParse(dueDate.substring(5, 7));
    } else if (dueDate.contains('.') && dueDate.split('.').length == 3) {
      var parts = dueDate.split('.');
      return int.tryParse(parts[1]);
    } else if (dueDate.contains('T')) {
      return int.tryParse(dueDate.substring(5, 7));
    }
    return null;
  }

  String _getStudentGroupId() {
    final relation = widget.tumGroupStudents.firstWhere(
      (r) =>
          r.student_id == widget.user.app &&
          r.is_active.toString().toUpperCase() == "TRUE",
      orElse: () => GroupStudent(
        group_students_id: "",
        groups_id: "",
        student_id: "",
        enrolled_at: "",
        is_active: "",
      ),
    );
    return relation.groups_id;
  }

  double _getMonthlyFee() {
    return double.tryParse(widget.user.amount) ?? 0;
  }

  String _getGroupName() {
    final groupId = _getStudentGroupId();
    if (groupId.isEmpty) return "Atanmamış";
    final group = widget.tumGruplar.firstWhere(
      (g) => g.groups_id == groupId,
      orElse: () => Group(
        groups_id: "",
        branches_id: "",
        coach_id: "",
        sports_id: "",
        name: "Grup Bulunamadı",
        schedule: "",
        capacity: "",
        monthly_fee: "0",
        is_active: "",
      ),
    );
    return group.name;
  }

  String _getCurrentMonthYear() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM').format(now);
  }

  double _getPaidAmountForMonth(String monthYear) {
    double total = 0;
    List<String> targetParts = monthYear.split('-');
    int targetYear = int.parse(targetParts[0]);
    int targetMonth = int.parse(targetParts[1]);

    for (var p in widget.tumOdemeler) {
      if (p.student_id != widget.user.app) continue;
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

  String _getPaymentStatus(double monthlyFee, double paidThisMonth) {
    if (monthlyFee == 0) return "unpaid";
    if (paidThisMonth >= monthlyFee) return "paid";
    if (paidThisMonth > 0) return "partial";
    return "unpaid";
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "paid":
        return const Color(0xFF22C55E);
      case "partial":
        return const Color(0xFFF97316);
      case "unpaid":
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case "paid":
        return "Ödendi";
      case "partial":
        return "Kısmi Ödeme";
      case "unpaid":
        return "Ödenmedi";
      default:
        return "Belirsiz";
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case "paid":
        return Icons.check_circle_rounded;
      case "partial":
        return Icons.warning_amber_rounded;
      case "unpaid":
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline;
    }
  }

  void _showPaymentDetail(BuildContext context, Payment payment) {
    final monthKey = payment.due_date.length >= 7
        ? payment.due_date.substring(0, 7)
        : payment.due_date;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Ödeme Detayı",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatMonthYearTurkish(monthKey),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Ödenen Tutar",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${double.tryParse(payment.amount)?.toStringAsFixed(2) ?? payment.amount} ₺",
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _detailRow(
                    "Ödeme Yöntemi",
                    payment.payment_method,
                    Icons.payment,
                    const Color(0xFF0D9488),
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    "Ödeme Tarihi",
                    _formatDateLongTurkish(payment.paid_date),
                    Icons.calendar_today,
                    const Color(0xFF3B82F6),
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    "Dönem",
                    _formatMonthYearTurkish(monthKey),
                    Icons.date_range,
                    const Color(0xFFF97316),
                  ),
                  if (payment.note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailRow(
                      "Not",
                      payment.note,
                      Icons.note_alt,
                      const Color(0xFF8B5CF6),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Kapat",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Aidat Bilgilerim",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _paymentDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF0D9488),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Aidat bilgileri yükleniyor...",
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Veriler yüklenirken hata oluştu",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _paymentDataFuture = _loadPaymentData();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Tekrar Dene"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final monthlyFee = snapshot.data?['monthlyFee'] as double? ?? 0;
          final currentMonth = snapshot.data?['currentMonth'] as String? ?? "";
          final paidThisMonth = snapshot.data?['paidThisMonth'] as double? ?? 0;
          final remainingDebt = snapshot.data?['remainingDebt'] as double? ?? 0;
          final status = snapshot.data?['status'] as String? ?? "unpaid";
          final groupName = snapshot.data?['groupName'] as String? ?? "";
          final odemeler = snapshot.data?['odemeler'] as List<Payment>? ?? [];

          final statusColor = _getStatusColor(status);
          final statusText = _getStatusText(status);
          final statusIcon = _getStatusIcon(status);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _paymentDataFuture = _loadPaymentData();
              });
              await _paymentDataFuture;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Özet Kartı
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [statusColor, statusColor.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  statusIcon,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                statusText,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatMonthYearTurkish(currentMonth),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem(
                                "Aylık Ücret",
                                "${monthlyFee.toStringAsFixed(0)} ₺",
                                Icons.money_outlined,
                              ),
                              _buildSummaryItem(
                                "Ödenen",
                                "${paidThisMonth.toStringAsFixed(2)} ₺",
                                Icons.payment,
                              ),
                              _buildSummaryItem(
                                "Kalan",
                                "${remainingDebt.toStringAsFixed(2)} ₺",
                                Icons.warning_amber_rounded,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bilgi Kartı
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoTile(
                          "Öğrenci",
                          "${widget.user.first_name} ${widget.user.last_name}",
                          Icons.person_outline,
                          const Color(0xFF3B82F6),
                        ),
                        _buildDivider(),
                        _buildInfoTile(
                          "Grup",
                          groupName,
                          Icons.group_outlined,
                          const Color(0xFF8B5CF6),
                        ),
                        _buildDivider(),
                        _buildInfoTile(
                          "Aylık Ücret",
                          "${monthlyFee.toStringAsFixed(0)} ₺",
                          Icons.money_outlined,
                          const Color(0xFF22C55E),
                        ),
                        _buildDivider(),
                        _buildInfoTile(
                          "Ödeme Dönemi",
                          _formatMonthYearTurkish(currentMonth),
                          Icons.calendar_month,
                          const Color(0xFFF97316),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Ödeme Geçmişi
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history_rounded,
                                color: Color(0xFF0D9488),
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Text(
                                "Ödeme Geçmişi",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        if (odemeler.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(48),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Henüz ödeme kaydı bulunmuyor",
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: odemeler.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: Color(0xFFE2E8F0),
                            ),
                            itemBuilder: (context, index) {
                              final p = odemeler[index];
                              final paymentMonth = p.due_date.length >= 7
                                  ? p.due_date.substring(0, 7)
                                  : p.due_date;
                              final isCurrentMonth =
                                  paymentMonth == currentMonth;
                              return InkWell(
                                onTap: () => _showPaymentDetail(context, p),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: isCurrentMonth
                                              ? statusColor.withOpacity(0.15)
                                              : const Color(
                                                  0xFF0D9488,
                                                ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Icon(
                                          isCurrentMonth
                                              ? Icons.star_rounded
                                              : Icons.receipt_long_rounded,
                                          color: isCurrentMonth
                                              ? statusColor
                                              : const Color(0xFF0D9488),
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${double.tryParse(p.amount)?.toStringAsFixed(2) ?? p.amount} ₺",
                                              style: TextStyle(
                                                fontWeight: isCurrentMonth
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                fontSize: 16,
                                                color: const Color(0xFF1E293B),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "${p.payment_method} • ${_formatDateShortTurkish(p.paid_date)}",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                            Text(
                                              "Dönem: ${_formatMonthYearTurkish(paymentMonth)}",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (p.note.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.note_alt_rounded,
                                            size: 16,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xFF94A3B8),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 22, color: Colors.white.withOpacity(0.9)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 72, color: Color(0xFFE2E8F0));
  }
}
