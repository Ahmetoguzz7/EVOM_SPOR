import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:url_launcher/url_launcher.dart'; // 🔥 TELEFON ARAMA İÇİN EKLENDİ

class PaymentReminderScreen extends StatefulWidget {
  const PaymentReminderScreen({Key? key}) : super(key: key);

  @override
  _PaymentReminderScreenState createState() => _PaymentReminderScreenState();
}

class _PaymentReminderScreenState extends State<PaymentReminderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 🔥 VERİLER ARTIK WIDGET'TAN DEĞİL, API'DEN GELİYOR
  List<Users> allStudents = [];
  List<Payment> allPayments = [];
  List<Group> allGroups = [];
  List<GroupStudent> allGroupStudents = [];

  List<Users> firstHalfStudents = [];
  List<Users> secondHalfStudents = [];

  List<Users> filteredFirstHalfStudents = [];
  List<Users> filteredSecondHalfStudents = [];

  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Grup filtresi
  String _selectedGroupFilter = "Tümü";
  List<String> _groupFilterOptions = ["Tümü"];

  bool isLoading = true;
  DateTime _selectedDate = DateTime.now();

  Map<String, double> _feeCache = {};
  Map<String, double> _paidCache = {};
  Map<String, String> _statusCache = {};
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
    _loadAllData();
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
  // 🔥 TELEFON ARAMA FONKSİYONU
  // =========================================================================
  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _showSnack("Telefon numarası bulunamadı!", _danger);
      return;
    }

    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showSnack("Arama yapılamıyor!", _danger);
    }
  }

  // =========================================================================
  // 🚀 TÜM VERİLERİ PARALEL OLARAK ÇEK
  // =========================================================================
  void _loadAllData() {
    setState(() => isLoading = true);

    Future.microtask(() async {
      final stopwatch = Stopwatch()..start();

      _feeCache.clear();
      _paidCache.clear();
      _statusCache.clear();
      _studentGroupCache.clear();

      try {
        print("🟢 PaymentReminderScreen veriler yükleniyor...");

        final results = await Future.wait([
          GoogleSheetService.getStudentsOnlyCached(),
          GoogleSheetService.getPaymentsCached(),
          GoogleSheetService.getGroupsCached(),
          GoogleSheetService.getGroupStudentsCached(),
        ]);

        allStudents = results[0] as List<Users>;
        allPayments = results[1] as List<Payment>;
        allGroups = results[2] as List<Group>;
        allGroupStudents = results[3] as List<GroupStudent>;

        stopwatch.stop();
        print(
          "⏱️ PaymentReminderScreen verileri ${stopwatch.elapsedMilliseconds}ms'de yüklendi",
        );
        print(
          "📊 Öğrenci: ${allStudents.length}, Grup: ${allGroups.length}, İlişki: ${allGroupStudents.length}",
        );

        _buildGroupFilterOptions();
        await _filterStudentsAsync();

        if (mounted) setState(() => isLoading = false);
      } catch (e, stackTrace) {
        print("❌ PaymentReminderScreen yükleme hatası: $e");
        print(stackTrace);
        if (mounted) setState(() => isLoading = false);
      }
    });
  }

  // =========================================================================
  // GRUP CACHE
  // =========================================================================
  void _loadGroupCache() {
    _studentGroupCache.clear();

    print("=== GRUP CACHE YENİLENİYOR ===");
    print("Toplam öğrenci: ${allStudents.length}");
    print("Toplam groupStudent: ${allGroupStudents.length}");
    print("Toplam grup: ${allGroups.length}");

    for (var student in allStudents) {
      if (student.role.trim().toLowerCase() != "student") continue;
      if (student.is_active.toString().toUpperCase() != "TRUE") continue;

      final groupRelations = allGroupStudents.where((gs) {
        if (gs.student_id != student.app) return false;
        final active = gs.is_active.toString().toUpperCase();
        return active == "TRUE";
      }).toList();

      if (groupRelations.isNotEmpty) {
        final groupId = groupRelations.first.groups_id;
        final group = allGroups.firstWhere(
          (g) => g.groups_id == groupId,
          orElse: () => Group(
            groups_id: "",
            name: "Grup Yok",
            is_active: "",
            branches_id: '',
            coach_id: '',
            sports_id: '',
            schedule: '',
            capacity: '',
            monthly_fee: '',
          ),
        );
        _studentGroupCache[student.app] = group.name.isNotEmpty
            ? group.name
            : "Grup Yok";
        print("✅ ${student.first_name} ${student.last_name} -> ${group.name}");
      } else {
        _studentGroupCache[student.app] = "Grup Yok";
      }
    }

    print("✅ Grup cache oluşturuldu: ${_studentGroupCache.length} öğrenci");
  }

  // =========================================================================
  // GRUP FİLTRE SEÇENEKLERİ OLUŞTUR
  // =========================================================================
  void _buildGroupFilterOptions() {
    final groupNames = allGroups
        .map((g) => g.name)
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    groupNames.sort();
    _groupFilterOptions = ["Tümü", ...groupNames];
    print("📋 Grup filtre seçenekleri: ${_groupFilterOptions.length}");
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
    if (_searchQuery.isEmpty && _selectedGroupFilter == "Tümü") {
      filteredFirstHalfStudents = List.from(firstHalfStudents);
      filteredSecondHalfStudents = List.from(secondHalfStudents);
      return;
    }

    bool matchesFilter(Users s) {
      final name = "${s.first_name} ${s.last_name}".toLowerCase();
      final group = _getStudentGroup(s.app);

      if (_selectedGroupFilter != "Tümü" && group != _selectedGroupFilter) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        return name.contains(_searchQuery) ||
            group.toLowerCase().contains(_searchQuery);
      }

      return true;
    }

    filteredFirstHalfStudents = firstHalfStudents.where(matchesFilter).toList();
    filteredSecondHalfStudents = secondHalfStudents
        .where(matchesFilter)
        .toList();
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
        _selectedGroupFilter = "Tümü";
      });
      await _filterStudentsAsync();
    }
  }

  // =========================================================================
  // SADECE "unpaid" VE SADECE STUDENT ROLÜ
  // =========================================================================
  Future<void> _filterStudentsAsync() async {
    _feeCache.clear();
    _paidCache.clear();
    _statusCache.clear();

    _loadGroupCache();

    final first = <Users>[];
    final second = <Users>[];

    for (var student in allStudents) {
      if (student.is_active.toString().toUpperCase() != "TRUE") continue;

      final role = student.role.toString().trim().toLowerCase();
      if (role != "student") continue;

      final status = _getPaymentStatusForMonth(student.app, _selectedDate);

      if (status != "unpaid") continue;

      final date = _parseDateString(student.created_at);
      if (date == null) continue;

      if (date.day <= 14) {
        first.add(student);
      } else {
        second.add(student);
      }
    }

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

    print(
      "📊 Ödemeyen öğrenciler: 1-14: ${first.length}, 15-31: ${second.length}",
    );
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
    for (var payment in allPayments) {
      if (payment.student_id != studentId) continue;
      final status = payment.status.toString().toUpperCase();
      if (status != "PAID" && status != "TRUE") continue;
      try {
        String dateStr = payment.due_date;
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
    return double.tryParse(student.amount) ?? 0;
  }

  // =========================================================================
  // BİLDİRİM GÖNDERİMİ
  // =========================================================================
  Future<void> _sendReminder(Users student) async {
    if (student.role.trim().toLowerCase() != "student") {
      _showSnack("❌ Sadece öğrencilere hatırlatma gönderilebilir!", _danger);
      return;
    }

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

  Future<void> _sendReminderToAll(
    List<Users> students,
    String groupLabel,
  ) async {
    final onlyStudents = students
        .where((s) => s.role.trim().toLowerCase() == "student")
        .toList();

    if (onlyStudents.isEmpty) {
      _showSnack("Gönderilecek öğrenci yok!", _warning);
      return;
    }

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
          "$groupLabel grubundaki ${onlyStudents.length} öğrenciye hatırlatma gönderilecek. Devam?",
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

    for (var s in onlyStudents) {
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

    _showSnack(
      "✅ $sent / ${onlyStudents.length} öğrenciye hatırlatma gönderildi",
      sent == onlyStudents.length ? _success : _warning,
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
  // KART TASARIMI (TELEFON NUMARASI EKLENDİ)
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  // 🔥 TELEFON NUMARASI SATIRI EKLENDİ
                  if (s.phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _makePhoneCall(s.phone),
                      child: Row(
                        children: [
                          Icon(Icons.phone, size: 10, color: _accent),
                          const SizedBox(width: 3),
                          Text(
                            s.phone,
                            style: TextStyle(
                              color: _accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
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

  Widget _buildList(List<Users> students, String title, Color titleColor) {
    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _searchQuery.isNotEmpty || _selectedGroupFilter != "Tümü"
                  ? const Icon(
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
                _searchQuery.isNotEmpty || _selectedGroupFilter != "Tümü"
                    ? "Filtreyle eşleşen öğrenci yok"
                    : "Bu grupta ödemeyen öğrenci yok! 🎉",
                style: TextStyle(
                  color:
                      _searchQuery.isNotEmpty || _selectedGroupFilter != "Tümü"
                      ? _textSecondary
                      : _success,
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _accent),
            onPressed: () => _loadAllData(),
          ),
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
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              onRefresh: () async => _loadAllData(),
              color: _accent,
              child: Column(
                children: [
                  Container(
                    color: _surface,
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _border),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: "İsim veya grup ara...",
                                    hintStyle: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 11,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: _accent,
                                      size: 15,
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.clear_rounded,
                                              color: _textSecondary,
                                              size: 13,
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
                                      horizontal: 6,
                                      vertical: 8,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedGroupFilter,
                                    isExpanded: true,
                                    isDense: true,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: _textSecondary,
                                      size: 16,
                                    ),
                                    dropdownColor: _surface,
                                    items: _groupFilterOptions.map((name) {
                                      return DropdownMenuItem(
                                        value: name,
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            color: name == _selectedGroupFilter
                                                ? _accent
                                                : _textPrimary,
                                            fontSize: 11,
                                            fontWeight:
                                                name == _selectedGroupFilter
                                                ? FontWeight.w700
                                                : FontWeight.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedGroupFilter = val;
                                          _applyFilter();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _statChip(
                              Icons.warning_amber_rounded,
                              "Ödemeyen: $totalUnpaid",
                              _danger,
                            ),
                            const SizedBox(width: 6),
                            if (_searchQuery.isNotEmpty ||
                                _selectedGroupFilter != "Tümü")
                              _statChip(
                                Icons.filter_list_rounded,
                                "Filtre: $filteredTotal",
                                _accent,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
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
                                  const Icon(
                                    Icons.looks_one_outlined,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text("1-14 Gün"),
                                  const SizedBox(width: 4),
                                  _tabBadge(
                                    _searchQuery.isNotEmpty ||
                                            _selectedGroupFilter != "Tümü"
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
                                  const Icon(
                                    Icons.looks_two_outlined,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text("15-31 Gün"),
                                  const SizedBox(width: 4),
                                  _tabBadge(
                                    _searchQuery.isNotEmpty ||
                                            _selectedGroupFilter != "Tümü"
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
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                          child: _buildList(
                            filteredFirstHalfStudents,
                            "1-14 Kayıt Grubu",
                            _accent,
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                          child: _buildList(
                            filteredSecondHalfStudents,
                            "15-31 Kayıt Grubu",
                            _warning,
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
