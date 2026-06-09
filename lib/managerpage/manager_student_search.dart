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

  int _paidCount = 0;
  int _partialCount = 0;
  int _unpaidCount = 0;

  // 🔥 CACHE MEKANİZMASI
  final Map<String, double> _feeCache = {};
  final Map<String, double> _paidCache = {};
  final Map<String, String> _statusCache = {};
  final Map<String, String> _groupNameCache = {};

  // 🔥 MODERN BEYAZ TEMA
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _surfaceLight = Color(0xFFF1F5F9);
  static const Color _accent = Color(0xFF0EA5E9);
  static const Color _accentDark = Color(0xFF0284C7);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _green = Color(0xFF22C55E);
  static const Color _orange = Color(0xFFF97316);
  static const Color _red = Color(0xFFEF4444);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadAllDataParallel(); // 🔥 PARALEL VERSİYON
  }

  @override
  void dispose() {
    _feeCache.clear();
    _paidCache.clear();
    _statusCache.clear();
    _groupNameCache.clear();
    super.dispose();
  }

  // 🚀 PARALEL VERİ YÜKLEME (HIZLI!)
  void _loadAllDataParallel() {
    setState(() => isLoading = true);

    Future.microtask(() async {
      final stopwatch = Stopwatch()..start();

      _feeCache.clear();
      _paidCache.clear();
      _statusCache.clear();
      _groupNameCache.clear();

      try {
        // 🔥 TÜM VERİLERİ PARALEL OLARAK ÇEK (4 işlem aynı anda!)
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

        stopwatch.stop();
        print(
          "⏱️ StudentSearchScreen verileri PARALEL olarak ${stopwatch.elapsedMilliseconds}ms'de yüklendi",
        );

        _prepareFilters();
        _updateCounts();
        _applyFilters();

        if (mounted) setState(() => isLoading = false);
      } catch (e) {
        print("❌ StudentSearchScreen yükleme hatası: $e");
        if (mounted) setState(() => isLoading = false);
      }
    });
  }

  // Eski metod (geriye dönük uyumluluk için)
  void _loadAllData() {
    _loadAllDataParallel();
  }

  void _prepareFilters() {
    groupNames = ["Tümü", ...allGroups.map((g) => g.name).toSet()];
    final now = DateTime.now();
    monthOptions.clear();
    for (int i = -6; i <= 6; i++) {
      monthOptions.add(
        DateFormat('yyyy-MM').format(DateTime(now.year, now.month + i)),
      );
    }
    selectedMonthFilter = monthOptions[6];
  }

  String _getCachedGroupName(String studentId) {
    if (_groupNameCache.containsKey(studentId))
      return _groupNameCache[studentId]!;
    final name = _getStudentGroupName(studentId);
    _groupNameCache[studentId] = name;
    return name;
  }

  double _getCachedFee(String studentId) {
    if (_feeCache.containsKey(studentId)) return _feeCache[studentId]!;
    final fee = _getStudentMonthlyFee(studentId);
    _feeCache[studentId] = fee;
    return fee;
  }

  double _getCachedPaid(String studentId) {
    if (_paidCache.containsKey(studentId)) return _paidCache[studentId]!;
    final paid = _getStudentTotalPaid(studentId, selectedMonthFilter);
    _paidCache[studentId] = paid;
    return paid;
  }

  String _getCachedStatus(String studentId) {
    if (_statusCache.containsKey(studentId)) return _statusCache[studentId]!;
    final status = _getPaymentStatus(studentId, selectedMonthFilter);
    _statusCache[studentId] = status;
    return status;
  }

  void _updateCounts() {
    int paid = 0, partial = 0, unpaid = 0;
    _paidCache.clear();
    _statusCache.clear();

    for (var s in allStudents) {
      if (selectedGroupFilter != "Tümü" &&
          _getCachedGroupName(s.app) != selectedGroupFilter)
        continue;
      final status = _getCachedStatus(s.app);
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

  String _getMonthName(int m) => [
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
  ][m - 1];

  // 🔥 YENİ - Doğrudan grup adını bul
  String _getStudentGroupName(String studentId) {
    // Öğrencinin grup ilişkilerini bul
    final studentRelations = allRelations
        .where(
          (r) =>
              r.student_id == studentId && r.is_active.toUpperCase() == "TRUE",
        )
        .toList();

    if (studentRelations.isEmpty) {
      print("Öğrenci $studentId için aktif grup ilişkisi bulunamadı");
      return "Grup Yok";
    }

    // İlk aktif grubun ID'sini al
    final groupId = studentRelations.first.groups_id;

    // Grup bilgisini bul
    final group = allGroups.firstWhere(
      (g) => g.groups_id == groupId,
      orElse: () {
        print("Grup ID $groupId için grup bulunamadı");
        return Group(
          groups_id: "",
          name: "Grup Yok",
          coach_id: "",
          branches_id: "",
          sports_id: "",
          schedule: "",
          capacity: "",
          monthly_fee: "",
          is_active: "",
        );
      },
    );

    print("Öğrenci: $studentId -> Grup: ${group.name} (ID: $groupId)");
    return group.name.isEmpty ? "Grup Yok" : group.name;
  }

  double _getStudentMonthlyFee(String id) {
    final s = allStudents.firstWhere(
      (s) => s.app == id,
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
    return double.tryParse(s.amount) ?? 0;
  }

  double _getStudentTotalPaid(String id, String monthYear) {
    final parts = monthYear.split('-');
    if (parts.length != 2) return 0;
    final yr = int.parse(parts[0]);
    final mo = int.parse(parts[1]);
    double total = 0;
    for (var p in allPayments) {
      if (p.student_id != id) continue;
      final st = p.status.toString().toUpperCase();
      if (st != "PAID" && st != "TRUE") continue;
      try {
        final d = DateTime.parse(p.paid_date.split('T')[0]);
        if (d.year == yr && d.month == mo)
          total += double.tryParse(p.amount) ?? 0;
      } catch (_) {}
    }
    return total;
  }

  String _getPaymentStatus(String id, String monthYear) {
    final fee = _getStudentMonthlyFee(id);
    final paid = _getStudentTotalPaid(id, monthYear);
    if (fee == 0) return "unknown";
    if (paid >= fee) return "paid";
    if (paid > 0) return "partial";
    return "unpaid";
  }

  Color _statusColor(String s) => s == "paid"
      ? _green
      : s == "partial"
      ? _orange
      : _red;
  String _statusLabel(String s) => s == "paid"
      ? "Ödedi"
      : s == "partial"
      ? "Kısmi"
      : "Ödemedi";
  IconData _statusIcon(String s) => s == "paid"
      ? Icons.check_circle_rounded
      : s == "partial"
      ? Icons.timelapse_rounded
      : Icons.cancel_rounded;

  void _applyFilters() {
    setState(() {
      filteredStudents = allStudents.where((s) {
        if (searchQuery.isNotEmpty &&
            !"${s.first_name} ${s.last_name}".toLowerCase().contains(
              searchQuery.toLowerCase(),
            ))
          return false;
        if (selectedGroupFilter != "Tümü" &&
            _getCachedGroupName(s.app) != selectedGroupFilter)
          return false;
        if (selectedPaymentFilter != "Tümü") {
          final st = _getCachedStatus(s.app);
          if (selectedPaymentFilter == "Ödeyenler" && st != "paid")
            return false;
          if (selectedPaymentFilter == "Ödemeyenler" && st != "unpaid")
            return false;
          if (selectedPaymentFilter == "Kısmi Ödeyenler" && st != "partial")
            return false;
        }
        return true;
      }).toList();
    });
  }

  String _formatDate(String d) {
    if (d.isEmpty) return "—";
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(d.split('T')[0]));
    } catch (_) {
      return d;
    }
  }

  void _showPaymentDetail(Payment p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.receipt_long, color: _accent, size: 26),
            ),
            const SizedBox(width: 14),
            const Text(
              "Ödeme Detayı",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dRow("Tutar", "${p.amount} TL", _green),
            _dRow("Yöntem", p.payment_method, _accent),
            _dRow("Tarih", _formatDate(p.paid_date), _orange),
            if (p.note.isNotEmpty) _dRow("Not", p.note, _textSecondary),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: _accent.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              "Kapat",
              style: TextStyle(color: _accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dRow(String label, String value, Color valueColor) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(
            label,
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );

  void _showPaymentHistory(Users student) {
    Map<String, List<Payment>> byMonth = {};
    for (var p in allPayments.where((p) => p.student_id == student.app)) {
      final st = p.status.toString().toUpperCase();
      if (st != "PAID" && st != "TRUE") continue;
      try {
        final d = DateTime.parse(p.paid_date.split('T')[0]);
        (byMonth["${_getMonthName(d.month)} ${d.year}"] ??= []).add(p);
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (_, sc) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          student.first_name.isNotEmpty
                              ? student.first_name[0].toUpperCase()
                              : "?",
                          style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${student.first_name} ${student.last_name}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Ödeme Geçmişi",
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: _textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: _border, height: 1),
              Expanded(
                child: byMonth.isEmpty
                    ? const Center(
                        child: Text(
                          "Henüz ödeme kaydı yok",
                          style: TextStyle(color: _textSecondary),
                        ),
                      )
                    : ListView(
                        controller: sc,
                        padding: const EdgeInsets.all(16),
                        children: byMonth.entries.map((e) {
                          final fee = _getCachedFee(student.app);
                          final total = e.value.fold<double>(
                            0,
                            (s, p) => s + (double.tryParse(p.amount) ?? 0),
                          );
                          final color = total >= fee
                              ? _green
                              : total > 0
                              ? _orange
                              : _red;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: _surfaceLight,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(18),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        e.key,
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "${total.toStringAsFixed(0)} / ${fee.toStringAsFixed(0)} ₺",
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...e.value.map(
                                  (p) => ListTile(
                                    dense: true,
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _accent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.receipt_long,
                                        color: _accent,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      "${p.amount} ₺",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "${p.payment_method} · ${_formatDate(p.paid_date)}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _textSecondary,
                                      ),
                                    ),
                                    onTap: () => _showPaymentDetail(p),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parts = selectedMonthFilter.split('-');
    final monthName = parts.length == 2
        ? _getMonthName(int.parse(parts[1]))
        : "";
    final year = parts.isNotEmpty ? parts[0] : "";
    final total = _paidCount + _partialCount + _unpaidCount;
    final paidPct = total > 0 ? _paidCount / total : 0.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Öğrenci Ödeme Sayfası",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "$monthName $year · $total öğrenci",
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _accent),
            onPressed: () => _loadAllDataParallel(), // 🔥 Paralel versiyon
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              onRefresh: () async =>
                  _loadAllDataParallel(), // 🔥 Paralel versiyon
              color: _accent,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // ÖZET KARTI
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "$monthName $year",
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          "Ödeme Durumu Özeti",
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: paidPct >= 0.7
                                            ? _green
                                            : paidPct >= 0.4
                                            ? _orange
                                            : _red,
                                        width: 4,
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "${(paidPct * 100).toStringAsFixed(0)}%",
                                            style: TextStyle(
                                              color: paidPct >= 0.7
                                                  ? _green
                                                  : paidPct >= 0.4
                                                  ? _orange
                                                  : _red,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const Text(
                                            "ödendi",
                                            style: TextStyle(
                                              color: _textSecondary,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: paidPct,
                                  backgroundColor: _border,
                                  valueColor: const AlwaysStoppedAnimation(
                                    _green,
                                  ),
                                  minHeight: 10,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  _statCard(
                                    "Ödeyenler",
                                    _paidCount,
                                    _green,
                                    Icons.check_circle_rounded,
                                    "Ödeyenler",
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    "Kısmi",
                                    _partialCount,
                                    _orange,
                                    Icons.timelapse_rounded,
                                    "Kısmi Ödeyenler",
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    "Ödemeyenler",
                                    _unpaidCount,
                                    _red,
                                    Icons.cancel_rounded,
                                    "Ödemeyenler",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // FİLTRELER
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  style: const TextStyle(color: _textPrimary),
                                  decoration: InputDecoration(
                                    hintText: "Öğrenci ara...",
                                    hintStyle: TextStyle(color: _textSecondary),
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: _textSecondary,
                                    ),
                                    suffixIcon: searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(
                                              Icons.clear,
                                              color: _textSecondary,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                searchQuery = "";
                                                _applyFilters();
                                              });
                                            },
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 16,
                                    ),
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      searchQuery = v;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _dropdown(
                                      value: selectedGroupFilter,
                                      items: groupNames,
                                      icon: Icons.group_rounded,
                                      onChanged: (v) {
                                        setState(
                                          () => selectedGroupFilter = v!,
                                        );
                                        _updateCounts();
                                        _applyFilters();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _dropdown(
                                      value: selectedMonthFilter,
                                      items: monthOptions,
                                      icon: Icons.calendar_month_rounded,
                                      displayMap: (m) {
                                        final p = m.split('-');
                                        return "${_getMonthName(int.parse(p[1]))} ${p[0]}";
                                      },
                                      onChanged: (v) {
                                        setState(
                                          () => selectedMonthFilter = v!,
                                        );
                                        _updateCounts();
                                        _applyFilters();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (selectedPaymentFilter != "Tümü")
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              children: [
                                const Text(
                                  "Filtre:",
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedPaymentFilter = "Tümü";
                                      _applyFilters();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _accent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          selectedPaymentFilter,
                                          style: TextStyle(
                                            color: _accent,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.close,
                                          color: _accent,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  "${filteredStudents.length} öğrenci",
                                  style: TextStyle(
                                    color: _accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  filteredStudents.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  color: _textTertiary,
                                  size: 56,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Öğrenci bulunamadı",
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((_, i) {
                              final s = filteredStudents[i];
                              final status = _getCachedStatus(s.app);
                              final color = _statusColor(status);
                              final fee = _getCachedFee(s.app);
                              final paid = _getCachedPaid(s.app);
                              final pct = fee > 0
                                  ? (paid / fee).clamp(0.0, 1.0)
                                  : 0.0;
                              final group = _getCachedGroupName(s.app);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PaymentScreen(student: s),
                                        ),
                                      );
                                      if (result == true)
                                        await Future.delayed(Duration.zero);
                                    },
                                    onLongPress: () => _showPaymentHistory(s),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 52,
                                                height: 52,
                                                decoration: BoxDecoration(
                                                  color: color.withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    s.first_name.isNotEmpty
                                                        ? s.first_name[0]
                                                              .toUpperCase()
                                                        : "?",
                                                    style: TextStyle(
                                                      color: color,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 22,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "${s.first_name} ${s.last_name}",
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        color: _textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.group_rounded,
                                                          size: 12,
                                                          color: _textSecondary,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          group,
                                                          style: TextStyle(
                                                            color:
                                                                _textSecondary,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: color.withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _statusIcon(status),
                                                      color: color,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _statusLabel(status),
                                                      style: TextStyle(
                                                        color: color,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: _surfaceLight,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    _chip(
                                                      "Aidat",
                                                      "${fee.toStringAsFixed(0)} ₺",
                                                      _textSecondary,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _chip(
                                                      "Ödenen",
                                                      "${paid.toStringAsFixed(0)} ₺",
                                                      color,
                                                    ),
                                                    if (fee - paid > 0 &&
                                                        status != "paid") ...[
                                                      const SizedBox(width: 8),
                                                      _chip(
                                                        "Kalan",
                                                        "${(fee - paid).toStringAsFixed(0)} ₺",
                                                        _orange,
                                                      ),
                                                    ],
                                                    const Spacer(),
                                                    Text(
                                                      "${(pct * 100).toStringAsFixed(0)}%",
                                                      style: TextStyle(
                                                        color: color,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  child: LinearProgressIndicator(
                                                    value: pct,
                                                    backgroundColor: _border,
                                                    valueColor:
                                                        AlwaysStoppedAnimation(
                                                          color,
                                                        ),
                                                    minHeight: 6,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }, childCount: filteredStudents.length),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(
    String label,
    int count,
    Color color,
    IconData icon,
    String filterValue,
  ) {
    final sel = selectedPaymentFilter == filterValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedPaymentFilter = sel ? "Tümü" : filterValue;
            _applyFilters();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.1) : _surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? color : _border, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: sel ? color : _textSecondary, size: 22),
              const SizedBox(height: 6),
              Text(
                "$count",
                style: TextStyle(
                  color: sel ? color : _textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: sel ? color : _textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayMap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: _surface,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _textSecondary,
            size: 20,
          ),
          items: items.map((item) {
            final display = displayMap != null ? displayMap(item) : item;
            return DropdownMenuItem(
              value: item,
              child: Row(
                children: [
                  Icon(icon, color: _accent, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      display,
                      style: const TextStyle(color: _textPrimary, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
