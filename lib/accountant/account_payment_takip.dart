// debt_alert_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/managerpage/manager_payment_dekont.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class DebtAlertScreen extends StatefulWidget {
  final List<Users> students;
  final List<Payment> allPayments;
  final List<Group> allGroups;
  final List<GroupStudent> allRelations;

  const DebtAlertScreen({
    Key? key,
    required this.students,
    required this.allPayments,
    required this.allGroups,
    required this.allRelations,
  }) : super(key: key);

  @override
  State<DebtAlertScreen> createState() => _DebtAlertScreenState();
}

class _DebtAlertScreenState extends State<DebtAlertScreen> {
  String _selectedFilter = "current_month_10days";
  String _searchQuery = "";

  late List<AlertStudent> _alertStudents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlertData();
  }

  Future<void> _loadAlertData() async {
    setState(() => _isLoading = true);

    final allAlerts = <AlertStudent>[];
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // 🔥 AYLAR LİSTESİ (Son 6 ay + Bu ay + Gelecek 1 ay)
    final monthsToCheck = [
      DateTime(currentYear, currentMonth - 2),
      DateTime(currentYear, currentMonth - 1),
      DateTime(currentYear, currentMonth), // Bu ay
      DateTime(currentYear, currentMonth + 1),
    ];

    for (var student in widget.students) {
      final monthlyFee = double.tryParse(student.amount) ?? 0;
      if (monthlyFee == 0) continue;

      // 🔥 HER AY İÇİN KONTROL
      for (var monthDate in monthsToCheck) {
        final monthKey =
            "${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}";
        final monthName = _getMonthName(monthDate.month);
        final yearStr = monthDate.year.toString();

        // Ayın başından itibaren kaç gün geçti?
        final today = DateTime.now();
        final daysPassed = today.day;

        // AYIN BAŞINDAN İTİBAREN 10 GÜN GEÇTİ Mİ?
        final isAfter10Days = daysPassed >= 10;

        // Bu ay mı kontrol ettiğimiz?
        final isCurrentMonth =
            monthDate.year == currentYear && monthDate.month == currentMonth;

        // Sadece içinde bulunduğumuz ay için 10 gün kontrolü yap
        if (!isCurrentMonth && isAfter10Days) continue;

        final paidAmount = _getTotalPaidForMonth(student.app, monthKey);
        final remainingDebt = monthlyFee - paidAmount;
        final hasDebt = remainingDebt > 0;

        // Eğer geçmiş aylardan borç varsa veya bu ay 10 gün geçtiyse ve ödenmediyse
        final shouldShow =
            (monthDate.year < currentYear || monthDate.month < currentMonth)
            ? hasDebt // Geçmiş aylar: borç varsa göster
            : (isCurrentMonth &&
                  isAfter10Days &&
                  hasDebt); // Bu ay: 10 gün geçtiyse ve ödenmediyse göster

        if (shouldShow) {
          allAlerts.add(
            AlertStudent(
              student: student,
              monthlyFee: monthlyFee,
              monthKey: monthKey,
              monthName: monthName,
              year: yearStr,
              remainingDebt: remainingDebt,
              paidAmount: paidAmount,
              groupName: _getStudentGroupName(student.app),
            ),
          );
        }
      }
    }

    // Filtreye göre sırala
    _applyFilterToAlerts(allAlerts);

    setState(() => _isLoading = false);
  }

  void _applyFilterToAlerts(List<AlertStudent> allAlerts) {
    switch (_selectedFilter) {
      case "current_month_10days":
        // Bu ay ve 10 gün geçmiş ödemeyenler
        _alertStudents =
            allAlerts
                .where(
                  (a) =>
                      a.monthKey == _getCurrentMonthKey() &&
                      a.remainingDebt > 0,
                )
                .toList()
              ..sort((a, b) => b.remainingDebt.compareTo(a.remainingDebt));
        break;
      case "last_month_debt":
        // Geçen aydan borçlular
        final lastMonth = _getLastMonthKey();
        _alertStudents =
            allAlerts
                .where((a) => a.monthKey == lastMonth && a.remainingDebt > 0)
                .toList()
              ..sort((a, b) => b.remainingDebt.compareTo(a.remainingDebt));
        break;
      case "all_unpaid":
        // Tüm ödenmemiş borçlar
        _alertStudents = allAlerts.where((a) => a.remainingDebt > 0).toList()
          ..sort((a, b) => b.remainingDebt.compareTo(a.remainingDebt));
        break;
      default:
        _alertStudents = allAlerts;
        break;
    }
  }

  // 🔥 FİLTRELENMİŞ VE ARANMIŞ LİSTE
  List<AlertStudent> get _filteredAndSearchedList {
    var list = _alertStudents;

    if (_searchQuery.isNotEmpty) {
      list = list.where((alert) {
        final fullName =
            "${alert.student.first_name} ${alert.student.last_name}"
                .toLowerCase();
        return fullName.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return list;
  }

  String _getCurrentMonthKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  String _getLastMonthKey() {
    final now = DateTime.now();
    final lastMonth = now.month == 1 ? 12 : now.month - 1;
    final year = now.month == 1 ? now.year - 1 : now.year;
    return "${year}-${lastMonth.toString().padLeft(2, '0')}";
  }

  double _getTotalPaidForMonth(String studentId, String monthYear) {
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

  String _getStudentGroupName(String studentId) {
    final relations = widget.allRelations
        .where((r) => r.student_id == studentId && r.is_active == "TRUE")
        .toList();
    if (relations.isEmpty) return "Grup Yok";
    final group = widget.allGroups.firstWhere(
      (g) => g.groups_id == relations.first.groups_id,
      orElse: () => Group(
        groups_id: "",
        name: "Grup Yok",
        coach_id: '',
        branches_id: '',
        sports_id: '',
        schedule: '',
        capacity: '',
        monthly_fee: '',
        is_active: '',
      ),
    );
    return group.name;
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

  Future<void> _sendReminderToSelected(List<AlertStudent> students) async {
    int count = 0;
    for (var alert in students) {
      final notifData = {
        "notifications_id":
            "NTF-${DateTime.now().millisecondsSinceEpoch}-${alert.student.app}",
        "sender_id": "Admin",
        "recipient_id": alert.student.app.toString(),
        "groups_id": "",
        "title": "💰 Ödeme Hatırlatması",
        "message":
            "Sayın ${alert.student.first_name} ${alert.student.last_name}, ${alert.monthName} ${alert.year} ayına ait ${alert.remainingDebt.toStringAsFixed(0)} TL aidat ödemeniz bulunmaktadır.",
        "type": "payment_reminder",
        "is_read": "FALSE",
        "sent_at": DateTime.now().toIso8601String(),
      };
      final success = await GoogleSheetService.addNotification(notifData);
      if (success) count++;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ $count öğrenciye hatırlatma gönderildi"),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysPassed = now.day;
    final isAfter10Days = daysPassed >= 10;
    final currentMonthName = _getMonthName(now.month);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "⚠️ Borç Uyarıları",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        actions: [
          if (_alertStudents.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.notifications_active),
              onPressed: () =>
                  _sendReminderToSelected(_filteredAndSearchedList),
              tooltip: "Listedekilere hatırlatma gönder",
            ),
        ],
      ),
      body: Column(
        children: [
          // Filtreleme Kartı
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isAfter10Days)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: Colors.orange.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "⚠️ Ayın başından itibaren henüz 10 gün geçmedi! ($daysPassed/10 gün)\n"
                            "Ödemeyenler listesi 10. günden sonra görünecektir.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Text(
                  "Filtre Seç",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip(
                      "📅 Bu Ay (10 Gün Geçince)",
                      "current_month_10days",
                      Colors.orange,
                      true,
                    ),
                    _buildFilterChip(
                      "📆 Geçen Aydan Borçlular",
                      "last_month_debt",
                      Colors.blue,
                      true,
                    ),
                    _buildFilterChip(
                      "📋 Tüm Gecikmiş Borçlar",
                      "all_unpaid",
                      Colors.purple,
                      true,
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(),

                // 🔥 ARAMA KUTUSU
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "🔍 Öğrenci ara (isim veya soyisim)...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = "";
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // İstatistik
          if (_filteredAndSearchedList.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepOrange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.people, color: Colors.deepOrange.shade700),
                  const SizedBox(width: 12),
                  Text(
                    "${_filteredAndSearchedList.length} öğrenci",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange.shade700,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.trending_up, color: Colors.deepOrange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    "Toplam Borç: ${_totalDebt().toStringAsFixed(0)} TL",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange.shade700,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Liste
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.deepOrange),
                  )
                : _filteredAndSearchedList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? "🔍 '$_searchQuery' ile eşleşen öğrenci bulunamadı"
                              : "Harika! 🎉\nBu filtreye uygun borçlu öğrenci yok.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredAndSearchedList.length,
                    itemBuilder: (context, index) {
                      final alert = _filteredAndSearchedList[index];
                      return _buildAlertCard(alert);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  double _totalDebt() {
    return _filteredAndSearchedList.fold(
      0.0,
      (sum, a) => sum + a.remainingDebt,
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    Color color,
    bool isEnabled,
  ) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: isEnabled
          ? (selected) {
              setState(() {
                _selectedFilter = value;
                _loadAlertData();
              });
            }
          : null,
      backgroundColor: Colors.grey.shade100,
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: _selectedFilter == value
            ? color
            : (isEnabled ? Colors.grey.shade700 : Colors.grey.shade400),
        fontWeight: _selectedFilter == value
            ? FontWeight.bold
            : FontWeight.normal,
      ),
    );
  }

  Widget _buildAlertCard(AlertStudent alert) {
    Color accentColor = Colors.deepOrange;

    if (alert.monthKey == _getCurrentMonthKey() && alert.remainingDebt > 0) {
      accentColor = Colors.orange;
    } else if (alert.remainingDebt > 0) {
      accentColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentScreen(student: alert.student),
            ),
          ).then((_) => _loadAlertData());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: accentColor.withOpacity(0.2),
                    child: Text(
                      alert.student.first_name[0].toUpperCase(),
                      style: TextStyle(
                        color: accentColor,
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
                          "${alert.student.first_name} ${alert.student.last_name}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "${alert.groupName} • ${alert.monthName} ${alert.year}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 🔥 DÖNEM ETİKETİ
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      alert.monthKey == _getCurrentMonthKey()
                          ? "BU AY (10 GÜN)"
                          : "GEÇMİŞ AY",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
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
                    child: _buildDebtInfo("📆 Dönem", alert.monthName, true),
                  ),
                  Expanded(
                    child: _buildDebtInfo(
                      "💰 Ödenen",
                      "${alert.paidAmount.toStringAsFixed(0)} TL",
                      alert.paidAmount > 0,
                    ),
                  ),
                  Expanded(
                    child: _buildDebtInfo(
                      "⚠️ Kalan",
                      "${alert.remainingDebt.toStringAsFixed(0)} TL",
                      alert.remainingDebt > 0,
                      isTotal: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (alert.paidAmount / alert.monthlyFee).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
              const SizedBox(height: 8),
              Text(
                "📍 Ödeme almak için tıkla",
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebtInfo(
    String label,
    String value,
    bool hasDebt, {
    bool isTotal = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: hasDebt ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: hasDebt ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

// Model sınıfı
class AlertStudent {
  final Users student;
  final double monthlyFee;
  final String monthKey;
  final String monthName;
  final String year;
  final double remainingDebt;
  final double paidAmount;
  final String groupName;

  AlertStudent({
    required this.student,
    required this.monthlyFee,
    required this.monthKey,
    required this.monthName,
    required this.year,
    required this.remainingDebt,
    required this.paidAmount,
    required this.groupName,
  });
}
