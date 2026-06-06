import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class PaymentReminderScreen extends StatefulWidget {
  final List<Users> students;
  final List<Payment> allPayments;
  final List<Group> groups;
  final List<GroupStudent> groupStudents;

  const PaymentReminderScreen({
    Key? key,
    required this.students,
    required this.allPayments,
    required this.groups,
    required this.groupStudents,
  }) : super(key: key);

  @override
  _PaymentReminderScreenState createState() => _PaymentReminderScreenState();
}

class _PaymentReminderScreenState extends State<PaymentReminderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Users> firstHalfStudents = [];
  List<Users> secondHalfStudents = [];

  List<Users> filteredFirstHalfStudents = [];
  List<Users> filteredSecondHalfStudents = [];
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;
  DateTime _selectedDate = DateTime.now();

  Map<String, double> _feeCache = {};
  Map<String, double> _paidCache = {};
  Map<String, String> _statusCache = {};

  // FIX: Öğrencinin TÜM gruplarını tutar (virgülle ayrılmış)
  Map<String, String> _studentGroupCache = {};

  static const Color _bg = Color(0xFFF1F5F9);
  static const Color _surface = Colors.white;
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
    _loadGroupCache();
    _loadDataAsync();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feeCache.clear();
    _paidCache.clear();
    _statusCache.clear();
    _studentGroupCache.clear();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // =========================================================================
  // FIX: Öğrencinin TÜM aktif gruplarını virgülle birleştir
  // =========================================================================
  void _loadGroupCache() {
    for (var student in widget.students) {
      final groupRelations = widget.groupStudents
          .where(
            (gs) =>
                gs.student_id == student.app &&
                gs.is_active.toString().toUpperCase() == "TRUE",
          )
          .toList();

      if (groupRelations.isNotEmpty) {
        final groupNames = groupRelations
            .map((rel) {
              final group = widget.groups.firstWhere(
                (g) => g.groups_id == rel.groups_id,
                orElse: () => Group(
                  groups_id: "",
                  name: "",
                  is_active: "",
                  branches_id: '',
                  coach_id: '',
                  sports_id: '',
                  schedule: '',
                  capacity: '',
                  monthly_fee: '',
                ),
              );
              return group.name;
            })
            .where((name) => name.isNotEmpty)
            .toList();

        _studentGroupCache[student.app] = groupNames.isNotEmpty
            ? groupNames.join(", ")
            : "Grup Yok";
      } else {
        _studentGroupCache[student.app] = "Grup Yok";
      }
    }
  }

  String _getStudentGroup(String studentId) =>
      _studentGroupCache[studentId] ?? "Grup Yok";

  Timer? _debounceTimer;

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
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
      filteredFirstHalfStudents = firstHalfStudents.where((s) {
        final name = "${s.first_name} ${s.last_name}".toLowerCase();
        final group = _getStudentGroup(s.app).toLowerCase();
        return name.contains(_searchQuery) || group.contains(_searchQuery);
      }).toList();

      filteredSecondHalfStudents = secondHalfStudents.where((s) {
        final name = "${s.first_name} ${s.last_name}".toLowerCase();
        final group = _getStudentGroup(s.app).toLowerCase();
        return name.contains(_searchQuery) || group.contains(_searchQuery);
      }).toList();
    }
  }

  void _loadDataAsync() {
    setState(() => isLoading = true);
    Future.microtask(() async {
      await _filterStudentsAsync();
      if (mounted) setState(() => isLoading = false);
    });
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

  String _getMonthShort(int month) {
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
    if (picked != null) {
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

  // =========================================================================
  // FIX: Sadece "unpaid" olanları filtrele — partial ve paid dahil değil
  // =========================================================================
  Future<void> _filterStudentsAsync() async {
    _feeCache.clear();
    _paidCache.clear();
    _statusCache.clear();

    final first = <Users>[];
    final second = <Users>[];

    for (var student in widget.students) {
      // Aktif olmayan öğrencileri atla
      if (student.is_active.toString().toUpperCase() != "TRUE") continue;

      final status = _getPaymentStatusForMonth(student.app, _selectedDate);

      // FIX: Sadece tamamen ödemeyenler (unpaid) — partial, paid, unknown dahil değil
      if (status != "unpaid") continue;

      final date = _parseDateString(student.created_at);
      if (date == null) continue;

      if (date.day <= 14) {
        first.add(student);
      } else {
        second.add(student);
      }
    }

    // İsme göre sırala
    first.sort(
      (a, b) => "${a.first_name} ${a.last_name}".compareTo(
        "${b.first_name} ${b.last_name}",
      ),
    );
    second.sort(
      (a, b) => "${a.first_name} ${a.last_name}".compareTo(
        "${b.first_name} ${b.last_name}",
      ),
    );

    if (mounted) {
      setState(() {
        firstHalfStudents = first;
        secondHalfStudents = second;
        _applyFilter();
      });
    }
  }

  // =========================================================================
  // ÖDEME DURUM HESABI
  // =========================================================================
  String _getPaymentStatusForMonth(String studentId, DateTime month) {
    final fee = _getStudentMonthlyFee(studentId);
    final paid = _getStudentTotalPaidForMonth(studentId, month);
    if (fee == 0) return "unknown";
    if (paid >= fee) return "paid";
    if (paid > 0) return "partial";
    return "unpaid";
  }

  double _getStudentTotalPaidForMonth(String studentId, DateTime month) {
    double total = 0;
    for (var payment in widget.allPayments) {
      if (payment.student_id != studentId) continue;
      final status = payment.status.toString().toUpperCase();
      if (status != "PAID" && status != "TRUE") continue;
      try {
        String dateStr = payment.due_date; // due_date ile eşleştir
        if (dateStr.isEmpty) dateStr = payment.paid_date;
        if (dateStr.contains('T')) dateStr = dateStr.split('T')[0];
        final parts = dateStr.split('-');
        if (parts.length >= 2) {
          final y = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          if (y == month.year && m == month.month) {
            total += double.tryParse(payment.amount) ?? 0;
          }
        }
      } catch (_) {}
    }
    return total;
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

  // =========================================================================
  // BİLDİRİM GÖNDERİMİ
  // =========================================================================
  Future<void> _sendReminder(Users student) async {
    final fee = _getCachedFee(student.app);
    final monthName = _getMonthNameTurkish(_selectedDate.month);
    final year = _selectedDate.year;

    final message =
        "Sayın ${student.first_name} ${student.last_name}, $monthName $year ayına ait ${fee.toStringAsFixed(0)} TL ödemeniz alınmamıştır.";

    final success = await GoogleSheetService.addNotification({
      "notifications_id":
          "NTF-${DateTime.now().millisecondsSinceEpoch}-${student.app}",
      "sender_id": "Admin",
      "recipient_id": student.app,
      "groups_id": "",
      "title": "💰 Ödeme Hatırlatma",
      "message": message,
      "type": "payment_reminder",
      "is_read": "FALSE",
      "sent_at": DateTime.now().toIso8601String(),
    });

    _showSnack(
      success
          ? "✅ ${student.first_name} ${student.last_name} - Hatırlatma gönderildi"
          : "❌ Gönderim başarısız!",
      success ? _success : _danger,
    );
  }

  // FIX: Tümüne gönder — sadece listedeki (zaten unpaid olan) öğrencilere gönder
  // Gönderilen kişi sayısını doğru göster
  Future<void> _sendReminderToAll(
    List<Users> students,
    String groupLabel,
  ) async {
    if (students.isEmpty) {
      _showSnack("Gönderilecek öğrenci yok!", _warning);
      return;
    }

    // Onay dialog'u
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: _accent),
            SizedBox(width: 8),
            Text("Toplu Hatırlatma", style: TextStyle(fontSize: 15)),
          ],
        ),
        content: Text(
          "$groupLabel grubundaki ${students.length} öğrenciye hatırlatma gönderilecek. Devam?",
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Gönder", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    int sent = 0;
    final monthName = _getMonthNameTurkish(_selectedDate.month);
    final year = _selectedDate.year;

    for (var s in students) {
      final fee = _getCachedFee(s.app);
      final message =
          "Sayın ${s.first_name} ${s.last_name}, $monthName $year ayına ait ${fee.toStringAsFixed(0)} TL ödemeniz alınmamıştır.";

      final success = await GoogleSheetService.addNotification({
        "notifications_id":
            "NTF-${DateTime.now().millisecondsSinceEpoch}-${s.app}",
        "sender_id": "Admin",
        "recipient_id": s.app,
        "groups_id": "",
        "title": "💰 Ödeme Hatırlatma",
        "message": message,
        "type": "payment_reminder",
        "is_read": "FALSE",
        "sent_at": DateTime.now().toIso8601String(),
      });
      if (success) sent++;
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // FIX: Doğru kişi sayısını göster — students.length (unpaid listesi)
    _showSnack(
      "✅ $sent / ${students.length} öğrenciye hatırlatma gönderildi",
      sent == students.length ? _success : _warning,
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final parsed = _parseDateString(dateStr);
    return parsed != null
        ? DateFormat('dd/MM/yyyy', 'tr_TR').format(parsed)
        : "—";
  }

  // =========================================================================
  // KART TASARIMI — taşmalar giderildi
  // =========================================================================
  Widget _buildStudentCard(Users s) {
    final fee = _getCachedFee(s.app);
    final groupName = _getStudentGroup(s.app);
    final regDate = _parseDateString(s.created_at);
    final dayLabel = regDate != null
        ? (regDate.day <= 14 ? "1-14" : "15-31")
        : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  s.first_name.isNotEmpty ? s.first_name[0].toUpperCase() : "?",
                  style: const TextStyle(
                    color: _danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Ad + Grup + Tarih — FIX: Expanded ile taşma önlendi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İsim satırı
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${s.first_name} ${s.last_name}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (dayLabel.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _danger.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _danger.withOpacity(0.2)),
                          ),
                          child: Text(
                            dayLabel,
                            style: const TextStyle(
                              color: _danger,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Grup adı — FIX: Flexible ile uzun grup adı taşmaz
                  Row(
                    children: [
                      const Icon(
                        Icons.group_outlined,
                        size: 10,
                        color: _textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          groupName,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Kayıt tarihi
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 10,
                        color: _textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatDate(s.created_at),
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Aidat + Hatırlat — FIX: Column ile dikey hizala, taşma yok
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${fee.toStringAsFixed(0)} ₺",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _danger,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _sendReminder(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                        SizedBox(width: 3),
                        Text(
                          "Hatırlat",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // LİSTE WIDGET
  // =========================================================================
  Widget _buildList(List<Users> students, String title, Color titleColor) {
    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _searchQuery.isNotEmpty
                  ? Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: _textSecondary,
                    )
                  : const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 56,
                      color: _success,
                    ),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty
                    ? "\"$_searchQuery\" için sonuç yok"
                    : "Bu grupta ödemeyen öğrenci yok! 🎉",
                style: TextStyle(
                  color: _searchQuery.isNotEmpty ? _textSecondary : _success,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık + Tümüne Gönder
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: titleColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: titleColor.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: titleColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${students.length} kişi",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              // FIX: Tümüne gönder — doğru kişi sayısıyla
              GestureDetector(
                onTap: () => _sendReminderToAll(students, title),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        size: 11,
                        color: _accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Tümüne (${students.length})",
                        style: const TextStyle(
                          color: _accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
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
          itemBuilder: (_, i) => _buildStudentCard(students[i]),
        ),
      ],
    );
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final monthName = _getMonthShort(_selectedDate.month);
    final year = _selectedDate.year;

    // FIX: Gerçek unpaid sayıları (filtrelenmiş değil, toplam)
    final totalUnpaid = firstHalfStudents.length + secondHalfStudents.length;
    final filteredTotal =
        filteredFirstHalfStudents.length + filteredSecondHalfStudents.length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: _textPrimary,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Ödeme Hatırlatma",
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          // Ay seçici
          GestureDetector(
            onTap: _selectMonth,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 13,
                    color: _accent,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "$monthName $year",
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: _accent,
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              // Arama
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "İsim veya grup ara...",
                      hintStyle: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _accent,
                        size: 16,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
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
                        horizontal: 8,
                        vertical: 9,
                      ),
                    ),
                    style: const TextStyle(color: _textPrimary, fontSize: 12),
                  ),
                ),
              ),

              // Özet bant
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Row(
                  children: [
                    // FIX: Toplam ödemeyen (gerçek sayı)
                    _statChip(
                      Icons.warning_amber_rounded,
                      "Ödemeyen: $totalUnpaid",
                      _danger,
                    ),
                    const SizedBox(width: 6),
                    if (_searchQuery.isNotEmpty)
                      _statChip(
                        Icons.filter_list_rounded,
                        "Filtre: $filteredTotal",
                        _accent,
                      ),
                  ],
                ),
              ),

              // Tab bar
              TabBar(
                controller: _tabController,
                indicatorColor: _accent,
                indicatorWeight: 2,
                labelColor: _accent,
                unselectedLabelColor: _textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.looks_one_outlined, size: 14),
                        const SizedBox(width: 4),
                        const Text("1-14 Gün"),
                        const SizedBox(width: 4),
                        _tabBadge(
                          _searchQuery.isNotEmpty
                              ? filteredFirstHalfStudents.length
                              : firstHalfStudents.length,
                          _accent,
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.looks_two_outlined, size: 14),
                        const SizedBox(width: 4),
                        const Text("15-31 Gün"),
                        const SizedBox(width: 4),
                        _tabBadge(
                          _searchQuery.isNotEmpty
                              ? filteredSecondHalfStudents.length
                              : secondHalfStudents.length,
                          _warning,
                        ),
                      ],
                    ),
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
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  child: _buildList(
                    filteredFirstHalfStudents,
                    "1-14 Kayıt Grubu",
                    _accent,
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  child: _buildList(
                    filteredSecondHalfStudents,
                    "15-31 Kayıt Grubu",
                    _warning,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "$count",
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
