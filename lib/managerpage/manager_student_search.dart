import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_payment_dekont.dart';

class StudentSearchScreen extends StatefulWidget {
  final Users? currentUser;

  const StudentSearchScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _StudentSearchScreenState createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  List<Users> allStudents = [];
  List<Users> filteredStudents = [];
  List<Payment> allPayments = [];
  List<Group> allGroups = [];
  List<GroupStudent> allRelations = [];

  bool isLoading = true;

  String selectedGroupFilter = "Tümü";
  String selectedMonthFilter = "";
  String selectedPaymentFilter = "Tümü";

  List<String> groupNames = ["Tümü"];
  List<String> monthOptions = [];

  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        GoogleSheetService.getStudentsOnlyCached(),
        GoogleSheetService.getPaymentsCached(),
        GoogleSheetService.getGroupsCached(),
        GoogleSheetService.getGroupStudentsCached(),
      ]);

      allStudents = results[0] as List<Users>;
      allPayments = results[1] as List<Payment>;
      allGroups = results[2] as List<Group>;
      allRelations = results[3] as List<GroupStudent>;

      _prepareFilters();
      _applyFilters();

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _prepareFilters() {
    final Set<String> uniqueGroups = {};
    for (var group in allGroups) {
      uniqueGroups.add(group.name);
    }
    groupNames = ["Tümü", ...uniqueGroups.toList()];

    final now = DateTime.now();
    monthOptions.clear();
    for (int i = -6; i <= 6; i++) {
      final date = DateTime(now.year, now.month + i);
      monthOptions.add(DateFormat('yyyy-MM').format(date));
    }
    selectedMonthFilter = monthOptions[6];
  }

  String _getMonthName(int month) {
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

  int _getMonthNumber(String monthName) {
    switch (monthName) {
      case "Ocak":
        return 1;
      case "Şubat":
        return 2;
      case "Mart":
        return 3;
      case "Nisan":
        return 4;
      case "Mayıs":
        return 5;
      case "Haziran":
        return 6;
      case "Temmuz":
        return 7;
      case "Ağustos":
        return 8;
      case "Eylül":
        return 9;
      case "Ekim":
        return 10;
      case "Kasım":
        return 11;
      case "Aralık":
        return 12;
      default:
        return 1;
    }
  }

  DateTime _parseMonthYear(String monthYear) {
    final parts = monthYear.split(' ');
    final month = _getMonthNumber(parts[0]);
    final year = int.parse(parts[1]);
    return DateTime(year, month);
  }

  List<String> _getStudentGroups(String studentId) {
    final relations = allRelations
        .where(
          (r) =>
              r.student_id == studentId &&
              r.is_active.toString().toUpperCase() == "TRUE",
        )
        .toList();
    return relations.map((r) => r.groups_id).toList();
  }

  String _getStudentGroupName(String studentId) {
    final groups = _getStudentGroups(studentId);
    if (groups.isEmpty) return "Grup Yok";
    final group = allGroups.firstWhere(
      (g) => g.groups_id == groups.first,
      orElse: () => Group(
        groups_id: "",
        name: "Belirsiz",
        coach_id: "",
        branches_id: "",
        sports_id: "",
        schedule: "",
        capacity: "",
        monthly_fee: "",
        is_active: "",
      ),
    );
    return group.name;
  }

  double _getStudentMonthlyFee(String studentId) {
    final student = allStudents.firstWhere(
      (s) => s.app == studentId,
      orElse: () => Users(
        app: "",
        branches_id: "",
        first_name: "",
        last_name: "",
        email: "",
        phone: "",
        password_hash: "",
        role: "",
        profile_photo_url: "",
        amount: "0",
        b_date: "",
        created_at: "",
        last_login: "",
        is_active: "",
      ),
    );
    final fee = double.tryParse(student.amount) ?? 0;
    return fee;
  }

  double _getStudentTotalPaid(String studentId, String monthYear) {
    final parts = monthYear.split('-');
    if (parts.length != 2) return 0;

    final targetYear = int.parse(parts[0]);
    final targetMonth = int.parse(parts[1]);

    double total = 0;
    for (var payment in allPayments) {
      if (payment.student_id != studentId) continue;
      final status = payment.status.toString().toUpperCase();
      if (status != "PAID" && status != "TRUE") continue;

      try {
        String dateStr = payment.paid_date;
        if (dateStr.contains('T')) dateStr = dateStr.split('T')[0];
        final paymentDate = DateTime.parse(dateStr);
        if (paymentDate.year == targetYear &&
            paymentDate.month == targetMonth) {
          total += double.tryParse(payment.amount) ?? 0;
        }
      } catch (e) {}
    }
    return total;
  }

  // 🔥 DURUM HESAPLAMA - DÜZELTİLDİ
  String _getPaymentStatus(String studentId, String monthYear) {
    final monthlyFee = _getStudentMonthlyFee(studentId);
    final totalPaid = _getStudentTotalPaid(studentId, monthYear);

    if (monthlyFee == 0) return "unknown";
    if (totalPaid >= monthlyFee) return "paid";
    if (totalPaid > 0 && totalPaid < monthlyFee) return "partial";
    return "unpaid";
  }

  // 🔥 RENKLER - GÜNCELLENDİ
  Color _getPaymentColor(String status) {
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

  // 🔥 METİNLER - GÜNCELLENDİ
  String _getPaymentText(String status) {
    switch (status) {
      case "paid":
        return "Ödedi ✅";
      case "partial":
        return "Kısmi Ödedi ⚠️";
      case "unpaid":
        return "Ödemedi ❌";
      default:
        return "Belirsiz";
    }
  }

  void _applyFilters() {
    setState(() {
      filteredStudents = allStudents.where((student) {
        if (searchQuery.isNotEmpty) {
          final fullName = "${student.first_name} ${student.last_name}"
              .toLowerCase();
          if (!fullName.contains(searchQuery.toLowerCase())) return false;
        }

        if (selectedGroupFilter != "Tümü") {
          final studentGroupName = _getStudentGroupName(student.app);
          if (studentGroupName != selectedGroupFilter) return false;
        }

        if (selectedPaymentFilter != "Tümü") {
          final status = _getPaymentStatus(student.app, selectedMonthFilter);
          if (selectedPaymentFilter == "Ödeyenler" && status != "paid")
            return false;
          if (selectedPaymentFilter == "Ödemeyenler" && status != "unpaid")
            return false;
          if (selectedPaymentFilter == "Kısmi Ödeyenler" && status != "partial")
            return false;
        }

        return true;
      }).toList();
    });
  }

  void _search(String query) {
    searchQuery = query;
    _applyFilters();
  }

  void _showPaymentDetail(Payment payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ödeme Detayı"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tutar: ${payment.amount} TL",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text("Yöntem: ${payment.payment_method}"),
            Text("Tarih: ${_formatDate(payment.paid_date)}"),
            Text("Durum: ${payment.status}"),
            if (payment.note.isNotEmpty) Text("Not: ${payment.note}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Kapat"),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      String cleanDate = dateStr;
      if (cleanDate.contains('T')) cleanDate = cleanDate.split('T')[0];
      final date = DateTime.parse(cleanDate);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _showPaymentHistory(Users student) {
    Map<String, List<Payment>> paymentsByMonth = {};

    for (var payment in allPayments.where((p) => p.student_id == student.app)) {
      final status = payment.status.toString().toUpperCase();
      if (status != "PAID" && status != "TRUE") continue;

      try {
        String dateStr = payment.paid_date;
        if (dateStr.contains('T')) dateStr = dateStr.split('T')[0];
        final date = DateTime.parse(dateStr);
        final monthKey = "${_getMonthName(date.month)} ${date.year}";

        if (!paymentsByMonth.containsKey(monthKey)) {
          paymentsByMonth[monthKey] = [];
        }
        paymentsByMonth[monthKey]!.add(payment);
      } catch (e) {}
    }

    final sortedMonths = paymentsByMonth.keys.toList()
      ..sort((a, b) => _parseMonthYear(b).compareTo(_parseMonthYear(a)));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${student.first_name} ${student.last_name} - Ödeme Geçmişi",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sortedMonths.isEmpty
                    ? const Center(child: Text("Henüz ödeme kaydı yok"))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: sortedMonths.length,
                        itemBuilder: (context, index) {
                          final month = sortedMonths[index];
                          final payments = paymentsByMonth[month]!;
                          final monthlyFee = _getStudentMonthlyFee(student.app);
                          final totalPaid = payments.fold<double>(
                            0,
                            (sum, p) => sum + (double.tryParse(p.amount) ?? 0),
                          );
                          final isFullyPaid = totalPaid >= monthlyFee;
                          final isPartial =
                              totalPaid > 0 && totalPaid < monthlyFee;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isFullyPaid
                                        ? Colors.green.shade50
                                        : isPartial
                                        ? Colors.orange.shade50
                                        : Colors.red.shade50,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        month,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isFullyPaid
                                              ? Colors.green
                                              : isPartial
                                              ? Colors.orange
                                              : Colors.red,
                                        ),
                                      ),
                                      Text(
                                        "${totalPaid.toStringAsFixed(0)} / $monthlyFee TL",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isFullyPaid
                                              ? Colors.green
                                              : isPartial
                                              ? Colors.orange
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...payments
                                    .map(
                                      (payment) => ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.teal.shade100,
                                          child: Icon(
                                            Icons.receipt,
                                            color: Colors.teal,
                                            size: 18,
                                          ),
                                        ),
                                        title: Text("${payment.amount} TL"),
                                        subtitle: Text(
                                          "${payment.payment_method} - ${_formatDate(payment.paid_date)}",
                                        ),
                                        trailing: payment.note.isNotEmpty
                                            ? Icon(
                                                Icons.note,
                                                color: Colors.grey,
                                                size: 18,
                                              )
                                            : null,
                                        onTap: () =>
                                            _showPaymentDetail(payment),
                                      ),
                                    )
                                    .toList(),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Öğrenci Yönetimi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadAllData();
                _applyFilters();
              },
              child: Column(
                children: [
                  _buildSearchBar(),
                  _buildFilterBar(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredStudents.isEmpty
                        ? const Center(child: Text("Öğrenci bulunamadı"))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = filteredStudents[index];
                              final status = _getPaymentStatus(
                                student.app,
                                selectedMonthFilter,
                              );
                              final color = _getPaymentColor(status);
                              final monthlyFee = _getStudentMonthlyFee(
                                student.app,
                              );
                              final paidAmount = _getStudentTotalPaid(
                                student.app,
                                selectedMonthFilter,
                              );

                              return _buildStudentCard(
                                student,
                                status,
                                color,
                                monthlyFee,
                                paidAmount,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        onChanged: _search,
        decoration: InputDecoration(
          hintText: "İsim veya soyisim ile ara...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: selectedGroupFilter,
            decoration: const InputDecoration(
              labelText: "Grup",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.group),
            ),
            items: groupNames
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (val) {
              setState(() => selectedGroupFilter = val!);
              _applyFilters();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedMonthFilter,
            decoration: const InputDecoration(
              labelText: "Ay",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_month),
            ),
            items: monthOptions.map((m) {
              final parts = m.split('-');
              final monthName = _getMonthName(int.parse(parts[1]));
              return DropdownMenuItem(
                value: m,
                child: Text("$monthName ${parts[0]}"),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => selectedMonthFilter = val!);
              _applyFilters();
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  "Tümü",
                  selectedPaymentFilter == "Tümü",
                  Colors.grey,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  "Ödeyenler",
                  selectedPaymentFilter == "Ödeyenler",
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  "Kısmi Ödeyenler",
                  selectedPaymentFilter == "Kısmi Ödeyenler",
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  "Ödemeyenler",
                  selectedPaymentFilter == "Ödemeyenler",
                  Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, Color color) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedPaymentFilter = selected ? label : "Tümü";
          _applyFilters();
        });
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildStudentCard(
    Users student,
    String status,
    Color color,
    double monthlyFee,
    double paidAmount,
  ) {
    final remainingDebt = monthlyFee - paidAmount;
    final isPartial = status == "partial";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PaymentScreen(student: student)),
          );
          if (result == true) {
            await _loadAllData();
            _applyFilters();
          }
        },
        onLongPress: () => _showPaymentHistory(student),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.2),
                    child: Text(
                      student.first_name[0].toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${student.first_name} ${student.last_name}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          student.email,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getPaymentText(status),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      Icons.group,
                      _getStudentGroupName(student.app),
                      Colors.grey.shade100,
                      Colors.grey.shade700,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoChip(
                      Icons.money,
                      "Aylık: ${monthlyFee.toStringAsFixed(0)} TL",
                      Colors.grey.shade100,
                      Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      Icons.payment,
                      "Ödenen: ${paidAmount.toStringAsFixed(0)} TL",
                      color.withOpacity(0.1),
                      color,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoChip(
                      Icons.trending_up,
                      "${monthlyFee > 0 ? ((paidAmount / monthlyFee) * 100).toStringAsFixed(0) : 0}%",
                      color.withOpacity(0.1),
                      color,
                    ),
                  ),
                ],
              ),
              if (isPartial && remainingDebt > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.orange.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Kalan Borç: ${remainingDebt.toStringAsFixed(2)} TL",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: monthlyFee > 0
                    ? (paidAmount / monthlyFee).clamp(0.0, 1.0)
                    : 0,
                backgroundColor: Colors.grey.shade200,
                color: color,
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
              const SizedBox(height: 8),
              Text(
                "Uzun basarak ödeme geçmişini görüntüleyin",
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String label,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
