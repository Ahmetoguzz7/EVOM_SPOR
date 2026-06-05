/*import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_payment_dekont.dart';

class StudentListScreen extends StatefulWidget {
  final List<Users> students;
  final List<Payment> allPayments;
  final List<Group> allGroups;
  final List<GroupStudent> allRelations;

  const StudentListScreen({
    Key? key,
    required this.students,
    required this.allPayments,
    required this.allGroups,
    required this.allRelations,
  }) : super(key: key);

  @override
  _StudentListScreenState createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String selectedGroupFilter = "Tümü";
  String selectedPaymentFilter = "Tümü";
  String selectedMonthFilter = "";
  String searchQuery = "";

  List<Users> filteredStudents = [];
  List<String> groupNames = [];
  List<String> monthOptions = [];

  bool isSendingNotifications = false;
  bool _isLoading = true;

  // 🔥 SAYAÇLAR
  int _paidCount = 0;
  int _partialCount = 0;
  int _unpaidCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _prepareFilters();
    _updateCounts();
    _applyFilters();
    _isLoading = false;
  }

  void _prepareFilters() {
    final groupIds = widget.students
        .expand((student) => _getStudentGroups(student.app))
        .toSet()
        .toList();

    groupNames = ["Tümü", ...groupIds.map((id) => _getGroupName(id))];

    final now = DateTime.now();
    monthOptions = [];
    for (int i = -6; i <= 6; i++) {
      final date = DateTime(now.year, now.month + i);
      monthOptions.add(DateFormat('yyyy-MM').format(date));
    }
    selectedMonthFilter = monthOptions[6];
    _totalCount = widget.students.length;
  }

  // 🔥 SAYAÇLARI GÜNCELLE
  void _updateCounts() {
    int paid = 0;
    int partial = 0;
    int unpaid = 0;

    for (var student in widget.students) {
      final status = _getPaymentStatus(student.app, selectedMonthFilter);
      switch (status) {
        case "paid":
          paid++;
          break;
        case "partial":
          partial++;
          break;
        case "unpaid":
          unpaid++;
          break;
      }
    }

    setState(() {
      _paidCount = paid;
      _partialCount = partial;
      _unpaidCount = unpaid;
    });
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

  List<String> _getStudentGroups(String studentId) {
    final relations = widget.allRelations
        .where((r) => r.student_id == studentId && r.is_active == "TRUE")
        .toList();
    return relations.map((r) => r.groups_id).toList();
  }

  String _getGroupName(String groupId) {
    if (groupId.isEmpty) return "Grup Yok";
    final group = widget.allGroups.firstWhere(
      (g) => g.groups_id == groupId,
      orElse: () => Group(
        groups_id: "",
        name: "Grup Yok",
        coach_id: "",
        branches_id: "",
        sports_id: "",
        schedule: "",
        capacity: "",
        monthly_fee: "",
        is_active: "",
      ),
    );
    return group.name.isEmpty ? "Grup Yok" : group.name;
  }

  String _getStudentGroupName(String studentId) {
    final groupIds = _getStudentGroups(studentId);
    if (groupIds.isEmpty) return "Grup Yok";
    return _getGroupName(groupIds.first);
  }

  double _getStudentMonthlyFee(String studentId) {
    final student = widget.students.firstWhere(
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
    return double.tryParse(student.amount) ?? 0;
  }

  double _getStudentTotalPaid(String studentId, String monthYear) {
    final parts = monthYear.split('-');
    if (parts.length != 2) return 0;

    final targetYear = int.parse(parts[0]);
    final targetMonth = int.parse(parts[1]);

    double total = 0;
    for (var p in widget.allPayments) {
      if (p.student_id != studentId) continue;
      if (p.status != "paid") continue;

      final dueDate = DateTime.tryParse(p.due_date);
      if (dueDate != null) {
        if (dueDate.year == targetYear && dueDate.month == targetMonth) {
          total += double.tryParse(p.amount) ?? 0;
        }
      }
    }
    return total;
  }

  String _getPaymentStatus(String studentId, String monthYear) {
    final monthlyFee = _getStudentMonthlyFee(studentId);
    final totalPaid = _getStudentTotalPaid(studentId, monthYear);

    if (monthlyFee == 0) return "unpaid";
    if (totalPaid >= monthlyFee) return "paid";
    if (totalPaid > 0) return "partial";
    return "unpaid";
  }

  Color _getPaymentColor(String status) {
    switch (status) {
      case "paid":
        return Colors.green;
      case "partial":
        return Colors.blue;
      case "unpaid":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentText(String status) {
    switch (status) {
      case "paid":
        return "Ödedi";
      case "partial":
        return "Kısmi Ödedi";
      case "unpaid":
        return "Ödemedi";
      default:
        return "Belirsiz";
    }
  }

  Future<void> _sendNotificationsToUnpaidStudents() async {
    final unpaidStudents = filteredStudents.where((student) {
      return _getPaymentStatus(student.app, selectedMonthFilter) == "unpaid";
    }).toList();

    if (unpaidStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bu ayda ödemeyen öğrenci bulunmuyor!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isSendingNotifications = true);

    int sentCount = 0;
    final parts = selectedMonthFilter.split('-');
    final year = parts[0];
    final monthNum = int.parse(parts[1]);
    final monthName = _getMonthName(monthNum);

    for (var student in unpaidStudents) {
      final monthlyFee = _getStudentMonthlyFee(student.app);

      final notifData = {
        "notifications_id":
            "NTF-${DateTime.now().millisecondsSinceEpoch}-${student.app}",
        "sender_id": "Admin",
        "recipient_id": student.app.toString(),
        "groups_id": "",
        "title": "💰 Ödeme Hatırlatması",
        "message":
            "Sayın ${student.first_name} ${student.last_name}, $monthName $year ayına ait $monthlyFee TL aidat ödemeniz henüz alınmamıştır.",
        "type": "payment_reminder",
        "is_read": "FALSE",
        "sent_at": DateTime.now().toIso8601String(),
      };

      final success = await GoogleSheetService.addNotification(notifData);
      if (success) sentCount++;
    }

    setState(() => isSendingNotifications = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ $sentCount öğrenciye ödeme hatırlatması gönderildi"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      filteredStudents = widget.students.where((student) {
        if (searchQuery.isNotEmpty) {
          final fullName = "${student.first_name} ${student.last_name}"
              .toLowerCase();
          if (!fullName.contains(searchQuery.toLowerCase())) return false;
        }

        if (selectedGroupFilter != "Tümü") {
          final studentGroups = _getStudentGroups(student.app);
          final groupId = widget.allGroups
              .firstWhere(
                (g) => g.name == selectedGroupFilter,
                orElse: () => Group(
                  groups_id: "",
                  name: "",
                  branches_id: '',
                  coach_id: '',
                  sports_id: '',
                  schedule: '',
                  capacity: '',
                  monthly_fee: '',
                  is_active: '',
                ),
              )
              .groups_id;
          if (!studentGroups.contains(groupId)) return false;
        }

        final status = _getPaymentStatus(student.app, selectedMonthFilter);

        if (selectedPaymentFilter != "Tümü") {
          if (selectedPaymentFilter == "Ödeyenler" && status != "paid")
            return false;
          if (selectedPaymentFilter == "Kısmi Ödeyenler" && status != "partial")
            return false;
          if (selectedPaymentFilter == "Ödemeyenler" && status != "unpaid")
            return false;
        }

        return true;
      }).toList();
    });
  }

  void _showPaymentHistory(Users student) {
    final history =
        widget.allPayments.where((p) => p.student_id == student.app).toList()
          ..sort((a, b) => b.paid_date.compareTo(a.paid_date));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
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
                child: history.isEmpty
                    ? const Center(child: Text("Henüz ödeme kaydı yok"))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final payment = history[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade100,
                              child: Icon(Icons.receipt, color: Colors.teal),
                            ),
                            title: Text("${payment.amount} TL"),
                            subtitle: Text(
                              "${payment.payment_method} - ${_formatDate(payment.paid_date)}",
                            ),
                            onTap: () => _showPaymentDetail(payment),
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
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Öğrenci Listesi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          if (_unpaidCount > 0)
            IconButton(
              icon: const Icon(Icons.notifications_active, color: Colors.white),
              onPressed: _sendNotificationsToUnpaidStudents,
              tooltip: "Ödemeyenlere bildirim gönder",
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          labelText: "İsim veya soyisim ile ara...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      searchQuery = "";
                                      _applyFilters();
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedGroupFilter,
                        decoration: const InputDecoration(
                          labelText: "Grup",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.group),
                        ),
                        items: groupNames
                            .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedGroupFilter = val!;
                            _applyFilters();
                            _updateCounts();
                          });
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
                          setState(() {
                            selectedMonthFilter = val!;
                            _applyFilters();
                            _updateCounts();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      // 🔥 SAYILI FİLTRE BUTONLARI
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterChip(
                            "Tümü",
                            _totalCount,
                            Colors.grey,
                            "Tümü",
                          ),
                          _buildFilterChip(
                            "Ödeyenler",
                            _paidCount,
                            Colors.green,
                            "Ödeyenler",
                          ),
                          _buildFilterChip(
                            "Kısmi Ödeyenler",
                            _partialCount,
                            Colors.blue,
                            "Kısmi Ödeyenler",
                          ),
                          _buildFilterChip(
                            "Ödemeyenler",
                            _unpaidCount,
                            Colors.red,
                            "Ödemeyenler",
                          ),
                        ],
                      ),
                      if (_unpaidCount > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "$_unpaidCount öğrenci bu ay ödeme yapmamış. Bildirim göndermek için sağ üstteki butonu kullanın.",
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (isSendingNotifications) const LinearProgressIndicator(),
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
                            final remainingDebt = monthlyFee - paidAmount;
                            final groupName = _getStudentGroupName(student.app);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: color, width: 2),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PaymentScreen(student: student),
                                    ),
                                  );
                                  _updateCounts();
                                  _applyFilters();
                                },
                                onLongPress: () => _showPaymentHistory(student),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: color.withOpacity(
                                              0.2,
                                            ),
                                            child: Text(
                                              student.first_name.isNotEmpty
                                                  ? student.first_name[0]
                                                        .toUpperCase()
                                                  : "?",
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.group,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              groupName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildInfoChip(
                                              Icons.money,
                                              "Aylık: ${monthlyFee.toStringAsFixed(0)} TL",
                                              Colors.grey.shade100,
                                              Colors.grey.shade700,
                                            ),
                                          ),
                                          Expanded(
                                            child: _buildInfoChip(
                                              Icons.payment,
                                              "Ödenen: ${paidAmount.toStringAsFixed(0)} TL",
                                              color.withOpacity(0.1),
                                              color,
                                            ),
                                          ),
                                          if (remainingDebt > 0 &&
                                              status != "paid")
                                            Expanded(
                                              child: _buildInfoChip(
                                                Icons.warning,
                                                "Kalan: ${remainingDebt.toStringAsFixed(0)} TL",
                                                Colors.orange.shade50,
                                                Colors.orange.shade700,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (monthlyFee > 0)
                                        LinearProgressIndicator(
                                          value: (paidAmount / monthlyFee)
                                              .clamp(0.0, 1.0),
                                          backgroundColor: Colors.grey.shade200,
                                          color: color,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          minHeight: 6,
                                        ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Uzun basarak ödeme geçmişini görüntüleyin",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // 🔥 SAYI GÖSTEREN FİLTRE BUTONU
  Widget _buildFilterChip(
    String label,
    int count,
    Color color,
    String filterValue,
  ) {
    bool isSelected = selectedPaymentFilter == filterValue;
    return FilterChip(
      label: Text("$label ($count)"),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedPaymentFilter = selected ? filterValue : "Tümü";
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
*/
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_payment_dekont.dart';

class StudentListScreen extends StatefulWidget {
  final List<Users> students;
  final List<Payment> allPayments;
  final List<Group> allGroups;
  final List<GroupStudent> allRelations;

  const StudentListScreen({
    Key? key,
    required this.students,
    required this.allPayments,
    required this.allGroups,
    required this.allRelations,
  }) : super(key: key);

  @override
  _StudentListScreenState createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String selectedGroupFilter = "Tümü";
  String selectedPaymentFilter = "Tümü";
  String selectedMonthFilter = "";
  String searchQuery = "";

  List<Users> filteredStudents = [];
  List<String> groupNames = [];
  List<String> monthOptions = [];

  bool isSendingNotifications = false;
  bool _isLoading = true;

  // SAYAÇLAR
  int _paidCount = 0;
  int _partialCount = 0;
  int _unpaidCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _prepareFilters();
    _updateCounts();
    _applyFilters();
    _isLoading = false;
  }

  void _prepareFilters() {
    final groupIds = widget.students
        .expand((student) => _getStudentGroups(student.app))
        .toSet()
        .toList();

    groupNames = ["Tümü", ...groupIds.map((id) => _getGroupName(id))];

    final now = DateTime.now();
    monthOptions = [];
    for (int i = -6; i <= 6; i++) {
      final date = DateTime(now.year, now.month + i);
      monthOptions.add(DateFormat('yyyy-MM').format(date));
    }
    selectedMonthFilter = monthOptions[6];
    _totalCount = widget.students.length;
  }

  void _updateCounts() {
    int paid = 0;
    int partial = 0;
    int unpaid = 0;

    for (var student in widget.students) {
      final status = _getPaymentStatus(student.app, selectedMonthFilter);
      switch (status) {
        case "paid":
          paid++;
          break;
        case "partial":
          partial++;
          break;
        case "unpaid":
          unpaid++;
          break;
      }
    }

    setState(() {
      _paidCount = paid;
      _partialCount = partial;
      _unpaidCount = unpaid;
    });
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

  List<String> _getStudentGroups(String studentId) {
    final relations = widget.allRelations
        .where((r) => r.student_id == studentId && r.is_active == "TRUE")
        .toList();
    return relations.map((r) => r.groups_id).toList();
  }

  String _getGroupName(String groupId) {
    if (groupId.isEmpty) return "Grup Yok";
    final group = widget.allGroups.firstWhere(
      (g) => g.groups_id == groupId,
      orElse: () => Group(
        groups_id: "",
        name: "Grup Yok",
        coach_id: "",
        branches_id: "",
        sports_id: "",
        schedule: "",
        capacity: "",
        monthly_fee: "",
        is_active: "",
      ),
    );
    return group.name.isEmpty ? "Grup Yok" : group.name;
  }

  String _getStudentGroupName(String studentId) {
    final groupIds = _getStudentGroups(studentId);
    if (groupIds.isEmpty) return "Grup Yok";
    return _getGroupName(groupIds.first);
  }

  double _getStudentMonthlyFee(String studentId) {
    final student = widget.students.firstWhere(
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
    return double.tryParse(student.amount) ?? 0;
  }

  double _getStudentTotalPaid(String studentId, String monthYear) {
    final parts = monthYear.split('-');
    if (parts.length != 2) return 0;

    final targetYear = int.parse(parts[0]);
    final targetMonth = int.parse(parts[1]);

    double total = 0;
    for (var p in widget.allPayments) {
      if (p.student_id != studentId) continue;
      if (p.status != "paid") continue;

      final dueDate = DateTime.tryParse(p.due_date);
      if (dueDate != null) {
        if (dueDate.year == targetYear && dueDate.month == targetMonth) {
          total += double.tryParse(p.amount) ?? 0;
        }
      }
    }
    return total;
  }

  String _getPaymentStatus(String studentId, String monthYear) {
    final monthlyFee = _getStudentMonthlyFee(studentId);
    final totalPaid = _getStudentTotalPaid(studentId, monthYear);

    if (monthlyFee == 0) return "unpaid";
    if (totalPaid >= monthlyFee) return "paid";
    if (totalPaid > 0) return "partial";
    return "unpaid";
  }

  Color _getPaymentColor(String status) {
    switch (status) {
      case "paid":
        return Colors.green;
      case "partial":
        return Colors.blue;
      case "unpaid":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentText(String status) {
    switch (status) {
      case "paid":
        return "Ödedi";
      case "partial":
        return "Kısmi Ödedi";
      case "unpaid":
        return "Ödemedi";
      default:
        return "Belirsiz";
    }
  }

  Future<void> _sendNotificationsToUnpaidStudents() async {
    final unpaidStudents = filteredStudents.where((student) {
      return _getPaymentStatus(student.app, selectedMonthFilter) == "unpaid";
    }).toList();

    if (unpaidStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bu ayda ödemeyen öğrenci bulunmuyor!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isSendingNotifications = true);

    int sentCount = 0;
    final parts = selectedMonthFilter.split('-');
    final year = parts[0];
    final monthNum = int.parse(parts[1]);
    final monthName = _getMonthName(monthNum);

    for (var student in unpaidStudents) {
      final monthlyFee = _getStudentMonthlyFee(student.app);

      final notifData = {
        "notifications_id":
            "NTF-${DateTime.now().millisecondsSinceEpoch}-${student.app}",
        "sender_id": "Admin",
        "recipient_id": student.app.toString(),
        "groups_id": "",
        "title": "💰 Ödeme Hatırlatması",
        "message":
            "Sayın ${student.first_name} ${student.last_name}, $monthName $year ayına ait $monthlyFee TL aidat ödemeniz henüz alınmamıştır.",
        "type": "payment_reminder",
        "is_read": "FALSE",
        "sent_at": DateTime.now().toIso8601String(),
      };

      final success = await GoogleSheetService.addNotification(notifData);
      if (success) sentCount++;
    }

    setState(() => isSendingNotifications = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ $sentCount öğrenciye ödeme hatırlatması gönderildi"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      filteredStudents = widget.students.where((student) {
        if (searchQuery.isNotEmpty) {
          final fullName = "${student.first_name} ${student.last_name}"
              .toLowerCase();
          if (!fullName.contains(searchQuery.toLowerCase())) return false;
        }

        if (selectedGroupFilter != "Tümü") {
          final studentGroups = _getStudentGroups(student.app);
          final groupId = widget.allGroups
              .firstWhere(
                (g) => g.name == selectedGroupFilter,
                orElse: () => Group(
                  groups_id: "",
                  name: "",
                  branches_id: '',
                  coach_id: '',
                  sports_id: '',
                  schedule: '',
                  capacity: '',
                  monthly_fee: '',
                  is_active: '',
                ),
              )
              .groups_id;
          if (!studentGroups.contains(groupId)) return false;
        }

        final status = _getPaymentStatus(student.app, selectedMonthFilter);

        if (selectedPaymentFilter != "Tümü") {
          if (selectedPaymentFilter == "Ödeyenler" && status != "paid")
            return false;
          if (selectedPaymentFilter == "Kısmi Ödeyenler" && status != "partial")
            return false;
          if (selectedPaymentFilter == "Ödemeyenler" && status != "unpaid")
            return false;
        }

        return true;
      }).toList();
    });
  }

  void _showPaymentHistory(Users student) {
    final history =
        widget.allPayments.where((p) => p.student_id == student.app).toList()
          ..sort((a, b) => b.paid_date.compareTo(a.paid_date));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
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
                child: history.isEmpty
                    ? const Center(child: Text("Henüz ödeme kaydı yok"))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final payment = history[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade100,
                              child: Icon(Icons.receipt, color: Colors.teal),
                            ),
                            title: Text("${payment.amount} TL"),
                            subtitle: Text(
                              "${payment.payment_method} - ${_formatDate(payment.paid_date)}",
                            ),
                            onTap: () => _showPaymentDetail(payment),
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
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ay ismini al
    final monthParts = selectedMonthFilter.split('-');
    final currentMonthName = _getMonthName(int.parse(monthParts[1]));
    final currentYear = monthParts[0];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Öğrenci Listesi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          if (_unpaidCount > 0)
            IconButton(
              icon: const Icon(Icons.notifications_active, color: Colors.white),
              onPressed: _sendNotificationsToUnpaidStudents,
              tooltip: "Ödemeyenlere bildirim gönder",
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Arama çubuğu
                      TextField(
                        decoration: InputDecoration(
                          labelText: "İsim veya soyisim ile ara...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      searchQuery = "";
                                      _applyFilters();
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Grup filtresi
                      DropdownButtonFormField<String>(
                        value: selectedGroupFilter,
                        decoration: const InputDecoration(
                          labelText: "Grup",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.group),
                        ),
                        items: groupNames
                            .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedGroupFilter = val!;
                            _applyFilters();
                            _updateCounts();
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Ay filtresi
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
                          setState(() {
                            selectedMonthFilter = val!;
                            _applyFilters();
                            _updateCounts();
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // 🔥 YENİ: GELİŞMİŞ FİLTRE BUTONLARI
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.pie_chart,
                                    size: 18,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "$currentMonthName $currentYear Ödeme Durumu",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildStatCard(
                                  icon: Icons.check_circle,
                                  label: "Ödeyenler",
                                  count: _paidCount,
                                  color: Colors.green,
                                  filterValue: "Ödeyenler",
                                ),
                                const SizedBox(width: 8),
                                _buildStatCard(
                                  icon: Icons.remove_circle,
                                  label: "Kısmi Ödeyenler",
                                  count: _partialCount,
                                  color: Colors.blue,
                                  filterValue: "Kısmi Ödeyenler",
                                ),
                                const SizedBox(width: 8),
                                _buildStatCard(
                                  icon: Icons.cancel,
                                  label: "Ödemeyenler",
                                  count: _unpaidCount,
                                  color: Colors.red,
                                  filterValue: "Ödemeyenler",
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (_unpaidCount > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "$_unpaidCount öğrenci bu ay ödeme yapmamış. Bildirim göndermek için sağ üstteki butonu kullanın.",
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (isSendingNotifications) const LinearProgressIndicator(),
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
                            final remainingDebt = monthlyFee - paidAmount;
                            final groupName = _getStudentGroupName(student.app);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: color, width: 2),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PaymentScreen(student: student),
                                    ),
                                  );
                                  _updateCounts();
                                  _applyFilters();
                                },
                                onLongPress: () => _showPaymentHistory(student),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: color.withOpacity(
                                              0.2,
                                            ),
                                            child: Text(
                                              student.first_name.isNotEmpty
                                                  ? student.first_name[0]
                                                        .toUpperCase()
                                                  : "?",
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.group,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              groupName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildInfoChip(
                                              Icons.money,
                                              "Aylık: ${monthlyFee.toStringAsFixed(0)} TL",
                                              Colors.grey.shade100,
                                              Colors.grey.shade700,
                                            ),
                                          ),
                                          Expanded(
                                            child: _buildInfoChip(
                                              Icons.payment,
                                              "Ödenen: ${paidAmount.toStringAsFixed(0)} TL",
                                              color.withOpacity(0.1),
                                              color,
                                            ),
                                          ),
                                          if (remainingDebt > 0 &&
                                              status != "paid")
                                            Expanded(
                                              child: _buildInfoChip(
                                                Icons.warning,
                                                "Kalan: ${remainingDebt.toStringAsFixed(0)} TL",
                                                Colors.orange.shade50,
                                                Colors.orange.shade700,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (monthlyFee > 0)
                                        LinearProgressIndicator(
                                          value: (paidAmount / monthlyFee)
                                              .clamp(0.0, 1.0),
                                          backgroundColor: Colors.grey.shade200,
                                          color: color,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          minHeight: 6,
                                        ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Uzun basarak ödeme geçmişini görüntüleyin",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // 🔥 YENİ: İSTATİSTİK KARTI (Filtre butonu)
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required String filterValue,
  }) {
    final isSelected = selectedPaymentFilter == filterValue;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedPaymentFilter = isSelected ? "Tümü" : filterValue;
            _applyFilters();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected ? color : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : Colors.grey.shade500,
                ),
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
