// lib/managerpage/daily_payment_tracker.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

class DailyPaymentTracker extends StatefulWidget {
  const DailyPaymentTracker({super.key});

  @override
  State<DailyPaymentTracker> createState() => _DailyPaymentTrackerState();
}

class _DailyPaymentTrackerState extends State<DailyPaymentTracker> {
  final AppRepository _repo = AppRepository();
  DateTime _selectedDate = DateTime.now();
  List<Payment> _todayPayments = [];
  double _totalAmount = 0;
  bool _isLoading = true;
  String? _error;

  // 🔥 YENİ DEĞİŞKENLER
  bool _isGroupView = false; // false: Öğrenci bazlı, true: Grup bazlı
  String? _selectedGroupId;
  List<Group> _allGroups = [];

  // Rapor için veriler
  Map<String, GroupReportData> _groupReports = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!_repo.isLoaded) {
        await _repo.loadAllData();
      }

      _allGroups = List.from(_repo.allGroups);
      _filterPaymentsByDate();
      _calculateGroupReports();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterPaymentsByDate() {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final payments = _repo.allPayments.where((p) {
      if (p.status != "paid") return false;
      final paidDate = p.paid_date.split('T')[0];
      return paidDate == formattedDate;
    }).toList();

    payments.sort((a, b) => b.paid_date.compareTo(a.paid_date));

    final total = payments.fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p.amount) ?? 0),
    );

    setState(() {
      _todayPayments = payments;
      _totalAmount = total;
      _isLoading = false;
    });
  }

  /// 🔥 AYLIK BAZLI GRUP RAPORU (Seçilen ay için)
  Future<void> _calculateGroupReports() async {
    final reports = <String, GroupReportData>{};

    // Seçilen tarihin ayını al
    final selectedMonth = _selectedDate.month;
    final selectedYear = _selectedDate.year;

    for (var group in _allGroups) {
      // Gruptaki öğrencileri bul
      final relations = _repo.getGroupStudentsByGroupId(group.groups_id);
      final studentIds = relations.map((r) => r.student_id).toSet();

      // 🔥 HEDEF: Gruptaki öğrencilerin aylık ücretleri toplamı (olması gereken)
      double targetTotal = 0;
      final studentsInGroup = <Users>[];

      for (var studentId in studentIds) {
        final student = _repo.getUserById(studentId);
        if (student != null && student.role.toLowerCase() == "student") {
          studentsInGroup.add(student);
          targetTotal += double.tryParse(student.amount) ?? 0;
        }
      }

      // 🔥 TAHSİLAT: O ay içinde bu gruptan yapılan gerçek ödemeler
      double collectedThisMonth = 0;
      final paymentsThisMonth = <Payment>[];

      for (var payment in _repo.allPayments) {
        if (payment.status != "paid") continue;
        if (!studentIds.contains(payment.student_id)) continue;

        try {
          final paidDate = DateTime.parse(payment.paid_date.split('T')[0]);
          // Aynı ay ve yıl mı kontrol et
          if (paidDate.year == selectedYear &&
              paidDate.month == selectedMonth) {
            collectedThisMonth += double.tryParse(payment.amount) ?? 0;
            paymentsThisMonth.add(payment);
          }
        } catch (e) {}
      }

      reports[group.groups_id] = GroupReportData(
        groupName: group.name,
        targetTotal: targetTotal, // Hedef (olması gereken)
        collectedToday: collectedThisMonth, // Tahsilat (gerçek ödenen)
        studentCount: studentsInGroup.length,
        paymentsToday: paymentsThisMonth,
        students: studentsInGroup,
      );
    }

    setState(() {
      _groupReports = reports;
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Tarih Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _filterPaymentsByDate();
      _calculateGroupReports();
    }
  }

  void _showReportDialog() {
    final ayAdi = _getMonthNameTurkish(_selectedDate.month);
    final yil = _selectedDate.year;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart, color: Colors.teal, size: 28),
                  SizedBox(width: 10),
                  Text(
                    "📊 Aylık Grup Tahsilat Raporu",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "$ayAdi $yil • Aylık Ücret Toplamı vs Tahsilat",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const Divider(height: 24),

              // Toplam Özet Kartı (isteğe bağlı)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            "Toplam Hedef",
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            "${_groupReports.values.fold<double>(0, (s, r) => s + r.targetTotal).toStringAsFixed(0)} TL",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.teal.shade200,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            "Toplam Tahsilat",
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            "${_groupReports.values.fold<double>(0, (s, r) => s + r.collectedToday).toStringAsFixed(0)} TL",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.teal.shade200,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            "Toplam Eksik",
                            style: TextStyle(fontSize: 11),
                          ),
                          Text(
                            "${_groupReports.values.fold<double>(0, (s, r) => s + (r.targetTotal - r.collectedToday)).toStringAsFixed(0)} TL",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _allGroups.length,
                  itemBuilder: (context, index) {
                    final group = _allGroups[index];
                    final report = _groupReports[group.groups_id];
                    if (report == null) return const SizedBox.shrink();

                    final collectionRate = report.targetTotal > 0
                        ? (report.collectedToday / report.targetTotal) * 100
                        : 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: collectionRate >= 100
                              ? Colors.green.shade200
                              : collectionRate >= 70
                              ? Colors.orange.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.group,
                                  color: Colors.teal,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      report.groupName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      "${report.studentCount} öğrenci",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: collectionRate >= 100
                                      ? Colors.green.shade100
                                      : collectionRate >= 70
                                      ? Colors.orange.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "${collectionRate.toStringAsFixed(0)}%",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: collectionRate >= 100
                                        ? Colors.green
                                        : collectionRate >= 70
                                        ? Colors.orange
                                        : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _reportTile(
                                  "Hedef (Olması Gereken)",
                                  "${report.targetTotal.toStringAsFixed(0)} TL",
                                  Colors.blue,
                                ),
                              ),
                              Expanded(
                                child: _reportTile(
                                  "Tahsilat (Ödenen)",
                                  "${report.collectedToday.toStringAsFixed(0)} TL",
                                  Colors.green,
                                ),
                              ),
                              Expanded(
                                child: _reportTile(
                                  "Eksik (Kalan)",
                                  "${(report.targetTotal - report.collectedToday).toStringAsFixed(0)} TL",
                                  Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: collectionRate / 100,
                              backgroundColor: Colors.grey.shade200,
                              color: collectionRate >= 100
                                  ? Colors.green
                                  : collectionRate >= 70
                                  ? Colors.orange
                                  : Colors.red,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Yardımcı fonksiyon
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

  Widget _reportTile(String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  String _getFormattedDate() {
    final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
    return formatter.format(_selectedDate);
  }

  String _getDayName() {
    final days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    return days[_selectedDate.weekday - 1];
  }

  String _getStudentName(String studentId) {
    final student = _repo.getUserById(studentId);
    if (student == null) return "Bilinmeyen";
    return "${student.first_name} ${student.last_name}";
  }

  String _getGroupName(String groupId) {
    final group = _repo.getGroupById(groupId);
    return group?.name ?? "Grup Yok";
  }

  void _showPaymentDetail(Payment payment) {
    final studentName = _getStudentName(payment.student_id);
    final groupName = _getGroupName(payment.groups_id);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.teal, size: 28),
                SizedBox(width: 10),
                Text(
                  "Ödeme Detayı",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow(Icons.person, "Öğrenci", studentName),
            const Divider(),
            _detailRow(Icons.group, "Grup", groupName),
            const Divider(),
            _detailRow(Icons.attach_money, "Tutar", "${payment.amount} TL"),
            const Divider(),
            _detailRow(Icons.payment, "Yöntem", payment.payment_method),
            const Divider(),
            _detailRow(
              Icons.calendar_today,
              "Tarih",
              _formatDate(payment.paid_date),
            ),
            const Divider(),
            if (payment.note.isNotEmpty)
              _detailRow(Icons.note, "Not", payment.note),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.teal),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr.split('T')[0]);
      final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  List<Payment> _getFilteredPayments() {
    if (_isGroupView && _selectedGroupId != null) {
      final group = _repo.getGroupById(_selectedGroupId!);
      if (group != null) {
        final relations = _repo.getGroupStudentsByGroupId(group.groups_id);
        final studentIds = relations.map((r) => r.student_id).toSet();
        return _todayPayments
            .where((p) => studentIds.contains(p.student_id))
            .toList();
      }
    }
    return _todayPayments;
  }

  double _getFilteredTotal() {
    return _getFilteredPayments().fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p.amount) ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPayments = _getFilteredPayments();
    final filteredTotal = _getFilteredTotal();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Günlük Ödeme Takibi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          // 🔥 RAPOR BUTONU
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.teal),
            onPressed: _showReportDialog,
            tooltip: "Raporlar",
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.teal),
            onPressed: _selectDate,
            tooltip: "Tarih Seç",
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.teal),
            onPressed: _loadData,
            tooltip: "Yenile",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text("Ödemeler yükleniyor..."),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text("Hata: $_error"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Tarih ve Toplam Kartı
                    Container(
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
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getDayName(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getFormattedDate(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _selectDate,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Toplam Tahsilat",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${filteredTotal.toStringAsFixed(0)} TL",
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "${filteredPayments.length} ödeme",
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🔥 TOGGLE VE GRUP SEÇİMİ
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Grup Bazlı Görünüm",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Switch(
                                value: _isGroupView,
                                onChanged: (value) {
                                  setState(() {
                                    _isGroupView = value;
                                    if (!value) {
                                      _selectedGroupId = null;
                                    }
                                  });
                                },
                                activeColor: Colors.teal,
                              ),
                            ],
                          ),
                          if (_isGroupView)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: DropdownButtonFormField<String>(
                                value: _selectedGroupId,
                                hint: const Text("Grup Seçiniz"),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.group),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text("Tüm Gruplar"),
                                  ),
                                  ..._allGroups.map((group) {
                                    return DropdownMenuItem(
                                      value: group.groups_id,
                                      child: Text(group.name),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedGroupId = value;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Ödeme Yapanlar Listesi
                    if (filteredPayments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.payment_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isGroupView && _selectedGroupId != null
                                  ? "Bu gruba ait ödeme kaydı bulunamadı"
                                  : "Bu güne ait ödeme kaydı bulunamadı",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.people,
                                    color: Colors.teal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isGroupView && _selectedGroupId != null
                                        ? "Gruba Ait Ödemeler (${filteredPayments.length})"
                                        : "Ödeme Yapanlar (${filteredPayments.length})",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredPayments.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, indent: 16),
                              itemBuilder: (context, index) {
                                final payment = filteredPayments[index];
                                final studentName = _getStudentName(
                                  payment.student_id,
                                );

                                return ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.teal,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    studentName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${payment.payment_method} • ${_formatDate(payment.paid_date)}",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      if (_isGroupView &&
                                          _selectedGroupId != null)
                                        Text(
                                          _getGroupName(payment.groups_id),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.teal.shade700,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "${double.tryParse(payment.amount)?.toStringAsFixed(0) ?? payment.amount} TL",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                  onTap: () => _showPaymentDetail(payment),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}

// 🔥 RAPOR VERİ MODELİ
class GroupReportData {
  final String groupName;
  final double targetTotal;
  final double collectedToday;
  final int studentCount;
  final List<Payment> paymentsToday;
  final List<Users> students;

  GroupReportData({
    required this.groupName,
    required this.targetTotal,
    required this.collectedToday,
    required this.studentCount,
    required this.paymentsToday,
    required this.students,
  });
}
