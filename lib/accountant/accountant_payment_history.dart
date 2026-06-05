import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class PaymentReminderScreen extends StatefulWidget {
  final List<Users> students;
  final List<Payment> allPayments;

  const PaymentReminderScreen({
    Key? key,
    required this.students,
    required this.allPayments,
  }) : super(key: key);

  @override
  _PaymentReminderScreenState createState() => _PaymentReminderScreenState();
}

class _PaymentReminderScreenState extends State<PaymentReminderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Users> firstHalfStudents = [];
  List<Users> secondHalfStudents = [];

  // ARAMA İÇİN DEĞİŞKENLER
  List<Users> filteredFirstHalfStudents = [];
  List<Users> filteredSecondHalfStudents = [];
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;

  // Seçili ay (varsayılan olarak şu anki ay)
  DateTime _selectedDate = DateTime.now();

  // Cache için değişkenler
  Map<String, double> _feeCache = {};
  Map<String, double> _paidCache = {};
  Map<String, String> _statusCache = {};

  // BEYAZ TEMA RENKLERİ
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _surfaceLight = Color(0xFFF1F5F9);
  static const Color _accent = Color(0xFF0EA5E9);
  static const Color _success = Color(0xFF22C55E);
  static const Color _warning = Color(0xFFF97316);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDataAsync();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feeCache.clear();
    _paidCache.clear();
    _statusCache.clear();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Timer? _debounceTimer;

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _applyFilter();
      });
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      filteredFirstHalfStudents = List.from(firstHalfStudents);
      filteredSecondHalfStudents = List.from(secondHalfStudents);
    } else {
      filteredFirstHalfStudents = firstHalfStudents.where((student) {
        final fullName = "${student.first_name} ${student.last_name}"
            .toLowerCase();
        final firstName = student.first_name.toLowerCase();
        final lastName = student.last_name.toLowerCase();
        return fullName.contains(_searchQuery) ||
            firstName.contains(_searchQuery) ||
            lastName.contains(_searchQuery);
      }).toList();

      filteredSecondHalfStudents = secondHalfStudents.where((student) {
        final fullName = "${student.first_name} ${student.last_name}"
            .toLowerCase();
        final firstName = student.first_name.toLowerCase();
        final lastName = student.last_name.toLowerCase();
        return fullName.contains(_searchQuery) ||
            firstName.contains(_searchQuery) ||
            lastName.contains(_searchQuery);
      }).toList();
    }

    filteredFirstHalfStudents.sort((a, b) {
      final statusA = _getCachedStatus(a.app);
      final statusB = _getCachedStatus(b.app);
      if (statusA == "unpaid" && statusB != "unpaid") return -1;
      if (statusA != "unpaid" && statusB == "unpaid") return 1;
      if (statusA == "partial" && statusB == "unpaid") return 1;
      if (statusA == "unpaid" && statusB == "partial") return -1;
      return 0;
    });

    filteredSecondHalfStudents.sort((a, b) {
      final statusA = _getCachedStatus(a.app);
      final statusB = _getCachedStatus(b.app);
      if (statusA == "unpaid" && statusB != "unpaid") return -1;
      if (statusA != "unpaid" && statusB == "unpaid") return 1;
      if (statusA == "partial" && statusB == "unpaid") return 1;
      if (statusA == "unpaid" && statusB == "partial") return -1;
      return 0;
    });
  }

  void _loadDataAsync() {
    setState(() => isLoading = true);

    Future.microtask(() async {
      await _filterStudentsAsync();

      if (mounted) {
        setState(() => isLoading = false);
      }
    });
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Ay Seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month);
        _feeCache.clear();
        _paidCache.clear();
        _statusCache.clear();
        _searchQuery = "";
        _searchController.clear();
      });
      await _filterStudentsAsync();
    }
  }

  Future<void> _filterStudentsAsync() async {
    _feeCache.clear();
    _paidCache.clear();
    _statusCache.clear();

    final first = <Users>[];
    final second = <Users>[];

    for (var student in widget.students) {
      final status = _getPaymentStatusForMonth(student.app, _selectedDate);

      if (status == "unpaid" || status == "partial") {
        final date = _parseDateString(student.created_at);
        if (date != null) {
          if (date.day <= 14) {
            first.add(student);
          } else if (date.day >= 15) {
            second.add(student);
          }
        }
      }
    }

    await Future(() {
      first.sort((a, b) {
        final statusA = _getCachedStatusForMonth(a.app, _selectedDate);
        final statusB = _getCachedStatusForMonth(b.app, _selectedDate);
        if (statusA == "unpaid" && statusB != "unpaid") return -1;
        if (statusA != "unpaid" && statusB == "unpaid") return 1;
        if (statusA == "partial" && statusB == "unpaid") return 1;
        if (statusA == "unpaid" && statusB == "partial") return -1;
        return 0;
      });

      second.sort((a, b) {
        final statusA = _getCachedStatusForMonth(a.app, _selectedDate);
        final statusB = _getCachedStatusForMonth(b.app, _selectedDate);
        if (statusA == "unpaid" && statusB != "unpaid") return -1;
        if (statusA != "unpaid" && statusB == "unpaid") return 1;
        if (statusA == "partial" && statusB == "unpaid") return 1;
        if (statusA == "unpaid" && statusB == "partial") return -1;
        return 0;
      });
    });

    if (mounted) {
      setState(() {
        firstHalfStudents = first;
        secondHalfStudents = second;
        _applyFilter();
      });
    }
  }

  String _getPaymentStatusForMonth(String studentId, DateTime month) {
    final fee = _getStudentMonthlyFee(studentId);
    final paid = _getStudentTotalPaidForMonth(studentId, month);
    if (fee == 0) return "unknown";
    if (paid >= fee) return "paid";
    if (paid > 0) return "partial";
    return "unpaid";
  }

  double _getStudentTotalPaidForMonth(String studentId, DateTime month) {
    final targetYear = month.year;
    final targetMonth = month.month;

    double total = 0;
    for (var payment in widget.allPayments) {
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
      } catch (_) {}
    }
    return total;
  }

  String _getCachedStatusForMonth(String studentId, DateTime month) {
    final key = "$studentId-${month.year}-${month.month}";
    if (_statusCache.containsKey(key)) return _statusCache[key]!;
    final status = _getPaymentStatusForMonth(studentId, month);
    _statusCache[key] = status;
    return status;
  }

  double _getCachedPaidForMonth(String studentId, DateTime month) {
    final key = "$studentId-${month.year}-${month.month}";
    if (_paidCache.containsKey(key)) return _paidCache[key]!;
    final paid = _getStudentTotalPaidForMonth(studentId, month);
    _paidCache[key] = paid;
    return paid;
  }

  String _getCachedStatus(String studentId) {
    return _getCachedStatusForMonth(studentId, _selectedDate);
  }

  double _getCachedPaid(String studentId) {
    return _getCachedPaidForMonth(studentId, _selectedDate);
  }

  double _getCachedFee(String studentId) {
    if (_feeCache.containsKey(studentId)) return _feeCache[studentId]!;
    final fee = _getStudentMonthlyFee(studentId);
    _feeCache[studentId] = fee;
    return fee;
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

  String _getPaymentStatus(String studentId) {
    return _getPaymentStatusForMonth(studentId, _selectedDate);
  }

  Color _getPaymentColor(String status) => switch (status) {
    "paid" => _success,
    "partial" => _warning,
    "unpaid" => _danger,
    _ => _textSecondary,
  };

  String _getPaymentText(String status) => switch (status) {
    "paid" => "Ödedi",
    "partial" => "Kısmi",
    "unpaid" => "Ödemedi",
    _ => "?",
  };

  IconData _getPaymentIcon(String status) => switch (status) {
    "paid" => Icons.check_circle_rounded,
    "partial" => Icons.hourglass_top_rounded,
    "unpaid" => Icons.cancel_rounded,
    _ => Icons.help_outline,
  };

  Future<void> _sendReminder(Users student) async {
    final fee = _getCachedFee(student.app);
    final monthName = _getMonthName(_selectedDate.month);
    final year = _selectedDate.year;

    final success = await GoogleSheetService.addNotification({
      "notifications_id":
          "NTF-${DateTime.now().millisecondsSinceEpoch}-${student.app}",
      "sender_id": "Admin",
      "recipient_id": student.app,
      "groups_id": "",
      "title": "💰 Ödeme Hatırlatma Paneli",
      "message":
          "Sayın ${student.first_name} ${student.last_name}, $monthName $year ayına ait $fee TL ödemeniz alınmamıştır.",
      "type": "payment_reminder",
      "is_read": "FALSE",
      "sent_at": DateTime.now().toIso8601String(),
    });

    _showSnack(
      success
          ? "${student.first_name} ${student.last_name}'e hatırlatma gönderildi"
          : "Gönderim başarısız!",
      success ? _success : _danger,
    );
  }

  Future<void> _sendReminderToAll(
    List<Users> students,
    String groupName,
  ) async {
    final unpaid = students
        .where((s) => _getCachedStatus(s.app) == "unpaid")
        .toList();
    if (unpaid.isEmpty) {
      _showSnack("$groupName grubunda ödemeyen öğrenci yok!", _warning);
      return;
    }

    int sent = 0;
    final monthName = _getMonthName(_selectedDate.month);
    final year = _selectedDate.year;

    for (var s in unpaid) {
      final fee = _getCachedFee(s.app);
      final success = await GoogleSheetService.addNotification({
        "notifications_id":
            "NTF-${DateTime.now().millisecondsSinceEpoch}-${s.app}",
        "sender_id": "Admin",
        "recipient_id": s.app,
        "groups_id": "",
        "title": "💰 Ödeme Hatırlatma Paneli",
        "message":
            "Sayın ${s.first_name} ${s.last_name}, $monthName $year ayına ait $fee TL ödemeniz alınmamıştır.",
        "type": "payment_reminder",
        "is_read": "FALSE",
        "sent_at": DateTime.now().toIso8601String(),
      });
      if (success) sent++;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    _showSnack(
      "✅ $groupName grubunda $sent öğrenciye hatırlatma gönderildi",
      _success,
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getMonthName(int month) => [
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
  ][month - 1];

  String _formatDate(String dateStr) {
    final parsed = _parseDateString(dateStr);
    return parsed != null
        ? DateFormat('dd/MM/yyyy').format(parsed)
        : "Belirsiz";
  }

  Widget _buildStudentCard(Users s, bool isFirstHalf) {
    final status = _getCachedStatus(s.app);
    final color = _getPaymentColor(status);
    final fee = _getCachedFee(s.app);
    final paid = _getCachedPaid(s.app);
    final pct = fee > 0 ? (paid / fee).clamp(0.0, 1.0) : 0.0;
    final regDate = _parseDateString(s.created_at);
    final dayGroup = regDate != null
        ? (regDate.day <= 14 ? "İlk 14 Gün" : "İkinci 15 Gün")
        : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      s.first_name.isNotEmpty
                          ? s.first_name[0].toUpperCase()
                          : "?",
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${s.first_name} ${s.last_name}",
                        style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 10,
                            color: _textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(s.created_at),
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (dayGroup.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (isFirstHalf ? _accent : _warning)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                dayGroup,
                                style: TextStyle(
                                  color: isFirstHalf ? _accent : _warning,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getPaymentIcon(status), color: color, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        _getPaymentText(status),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: _surfaceLight,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _miniStat(
                      "Aidat",
                      "${fee.toStringAsFixed(0)}₺",
                      _textSecondary,
                    ),
                    const SizedBox(width: 6),
                    _miniStat("Ödenen", "${paid.toStringAsFixed(0)}₺", color),
                    if (fee - paid > 0 && status != "paid") ...[
                      const SizedBox(width: 6),
                      _miniStat(
                        "Kalan",
                        "${(fee - paid).toStringAsFixed(0)}₺",
                        _warning,
                      ),
                    ],
                    const Spacer(),
                    if (status == "unpaid")
                      GestureDetector(
                        onTap: () => _sendReminder(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_active,
                                size: 10,
                                color: Colors.white,
                              ),
                              SizedBox(width: 3),
                              Text(
                                "Hatırlat",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      "${(pct * 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: _border,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _buildList(
    List<Users> students,
    String title,
    Color titleColor,
    bool isFirstHalf,
  ) {
    if (students.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: _textSecondary),
              const SizedBox(height: 12),
              Text(
                "Aranan kriterde öğrenci bulunamadı",
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                "\"$_searchQuery\" için sonuç yok",
                style: TextStyle(color: _textSecondary, fontSize: 11),
              ),
            ],
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: _success.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              "🎉 Bu ayda ödemeyen öğrenci yok!",
              style: TextStyle(
                color: _success,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Tüm öğrenciler ödemelerini yapmış",
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final unpaidCount = students
        .where((s) => _getCachedStatus(s.app) == "unpaid")
        .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: titleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "$title (${students.length})",
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              if (unpaidCount > 0)
                GestureDetector(
                  onTap: () => _sendReminderToAll(students, title),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_active,
                          size: 11,
                          color: _accent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          "Tümüne ($unpaidCount)",
                          style: TextStyle(
                            color: _accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: students.length,
          itemBuilder: (_, i) => _buildStudentCard(students[i], isFirstHalf),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthName = _getMonthName(_selectedDate.month);
    final year = _selectedDate.year;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _textPrimary),
          onPressed: () {
            Navigator.of(context).pop();
          },
          tooltip: "Geri",
        ),
        title: Row(
          children: [
            const Expanded(
              child: Text(
                "Ödeme Hatırlatma",
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: _selectMonth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: _accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "$monthName $year",
                      style: TextStyle(
                        color: _accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 14, color: _accent),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(65),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: _surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Ara",
                      hintStyle: TextStyle(color: _textSecondary, fontSize: 12),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _accent,
                        size: 16,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: _textSecondary,
                                size: 14,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = "";
                                  _applyFilter();
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    style: TextStyle(color: _textPrimary, fontSize: 12),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: _accent,
                labelColor: _accent,
                unselectedLabelColor: _textSecondary,
                labelStyle: const TextStyle(fontSize: 11),
                tabs: const [
                  Tab(text: "1-14", icon: Icon(Icons.calendar_today, size: 14)),
                  Tab(
                    text: "15-31",
                    icon: Icon(Icons.calendar_month, size: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: _buildList(
                    filteredFirstHalfStudents,
                    "İlk 14 Gün",
                    _accent,
                    true,
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: _buildList(
                    filteredSecondHalfStudents,
                    "İkinci 15 Gün",
                    _warning,
                    false,
                  ),
                ),
              ],
            ),
    );
  }
}
