import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_payment_dekont.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

// =========================================================================
// 🔥 ISOLATE'DE ÇALIŞACAK FONKSİYONLAR
// =========================================================================

/// Öğrenci filtreleme paketi
class StudentFilterPackage {
  final List<Users> allStudents;
  final String searchQuery;
  final String selectedGroupFilter;
  final String selectedPaymentFilter;
  final String selectedMonthFilter;
  final Map<String, String> groupNameCache;
  final Map<String, double> feeCache;
  final Map<String, double> paidCache;
  final Map<String, String> statusCache;

  StudentFilterPackage({
    required this.allStudents,
    required this.searchQuery,
    required this.selectedGroupFilter,
    required this.selectedPaymentFilter,
    required this.selectedMonthFilter,
    required this.groupNameCache,
    required this.feeCache,
    required this.paidCache,
    required this.statusCache,
  });
}

/// Filtreleme sonucu
class StudentFilterResult {
  final List<Users> filteredStudents;
  final int paidCount;
  final int partialCount;
  final int unpaidCount;

  StudentFilterResult({
    required this.filteredStudents,
    required this.paidCount,
    required this.partialCount,
    required this.unpaidCount,
  });
}

/// 🔥 ISOLATE FONKSİYONU - Tüm ağır hesaplamalar burada
Future<StudentFilterResult> _filterStudentsInIsolate(
  StudentFilterPackage package,
) async {
  final allStudents = package.allStudents;
  final searchQuery = package.searchQuery.toLowerCase();
  final selectedGroupFilter = package.selectedGroupFilter;
  final selectedPaymentFilter = package.selectedPaymentFilter;
  final selectedMonthFilter = package.selectedMonthFilter;

  // Geçici hesaplama değişkenleri
  final Map<String, String> groupNameCache = {};
  final Map<String, double> feeCache = {};
  final Map<String, double> paidCache = {};
  final Map<String, String> statusCache = {};

  int paidCount = 0;
  int partialCount = 0;
  int unpaidCount = 0;

  final filtered = <Users>[];

  for (final student in allStudents) {
    // Sadece student rolü
    if (student.role.toLowerCase() != 'student') continue;

    // 1. İsim arama filtresi
    if (searchQuery.isNotEmpty) {
      final fullName = "${student.first_name} ${student.last_name}"
          .toLowerCase();
      if (!fullName.contains(searchQuery) &&
          !student.email.toLowerCase().contains(searchQuery) &&
          !student.phone.contains(searchQuery)) {
        continue;
      }
    }

    // 2. Grup filtresi için grup adını bul
    String groupName = "";
    if (selectedGroupFilter != "Tümü") {
      groupName = _getGroupNameFast(student.app, groupNameCache);
      if (groupName != selectedGroupFilter) continue;
    }

    // 3. Ödeme durumunu hesapla
    final monthYear = selectedMonthFilter;
    final status = _getPaymentStatusFast(
      studentId: student.app,
      student: student,
      monthYear: monthYear,
      statusCache: statusCache,
      feeCache: feeCache,
      paidCache: paidCache,
    );

    // Kayıt öncesi ay ise atla
    if (status == "registered_after") continue;

    // 4. Ödeme durumu filtresi
    if (selectedPaymentFilter != "Tümü") {
      if (selectedPaymentFilter == "Ödeyenler" && status != "paid") continue;
      if (selectedPaymentFilter == "Ödemeyenler" && status != "unpaid")
        continue;
      if (selectedPaymentFilter == "Kısmi Ödeyenler" && status != "partial")
        continue;
    }

    // Sayısal özetleri güncelle
    switch (status) {
      case "paid":
        paidCount++;
        break;
      case "partial":
        partialCount++;
        break;
      case "unpaid":
        unpaidCount++;
        break;
    }

    filtered.add(student);
  }

  return StudentFilterResult(
    filteredStudents: filtered,
    paidCount: paidCount,
    partialCount: partialCount,
    unpaidCount: unpaidCount,
  );
}

// Yardımcı fonksiyonlar (Isolate içinde kullanılacak)
String _getGroupNameFast(String studentId, Map<String, String> cache) {
  if (cache.containsKey(studentId)) return cache[studentId]!;
  // Not: Burada allGroups ve allRelations'a erişemeyiz, main'den gelecek
  // Bu yüzden groupNameCache main'den paket ile gelmeli
  return cache[studentId] ?? "Grup Yok";
}

String _getPaymentStatusFast({
  required String studentId,
  required Users student,
  required String monthYear,
  required Map<String, String> statusCache,
  required Map<String, double> feeCache,
  required Map<String, double> paidCache,
}) {
  final cacheKey = "${studentId}_$monthYear";
  if (statusCache.containsKey(cacheKey)) return statusCache[cacheKey]!;

  // Kayıt tarihi kontrolü
  final regYear = _getRegistrationYearFast(student);
  final regMonth = _getRegistrationMonthFast(student);
  final parts = monthYear.split('-');
  final yr = int.parse(parts[0]);
  final mo = int.parse(parts[1]);

  if (yr < regYear || (yr == regYear && mo < regMonth)) {
    statusCache[cacheKey] = "registered_after";
    return "registered_after";
  }

  // Fee ve Paid hesaplama (bu kısım karmaşık, ana thread'de yapılacak)
  // Isolate'de tam hesaplama yapmak için tüm payment ve relation verileri de lazım
  // O yüzden bu kısmı ana thread'de yapıp cache'leyeceğiz
  statusCache[cacheKey] = "unknown";
  return "unknown";
}

int _getRegistrationYearFast(Users student) {
  final dateStr = student.created_at;
  if (dateStr.isEmpty) return DateTime.now().year;
  try {
    if (dateStr.contains('T')) return DateTime.parse(dateStr).year;
    if (dateStr.contains('-') && dateStr.length >= 10) {
      return int.parse(dateStr.substring(0, 4));
    }
    return DateTime.now().year;
  } catch (_) {
    return DateTime.now().year;
  }
}

int _getRegistrationMonthFast(Users student) {
  final dateStr = student.created_at;
  if (dateStr.isEmpty) return 1;
  try {
    if (dateStr.contains('T')) return DateTime.parse(dateStr).month;
    if (dateStr.contains('-') && dateStr.length >= 7) {
      return int.parse(dateStr.substring(5, 7));
    }
    return 1;
  } catch (_) {
    return 1;
  }
}

// =========================================================================
// 🔥 ANA SAYFA - REPOSITORY + ISOLATE İLE HIZLANDIRILMIŞ
// =========================================================================

class StudentSearchScreen extends StatefulWidget {
  final Users? currentUser;
  const StudentSearchScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  _StudentSearchScreenState createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  final AppRepository _repo = AppRepository();

  List<Users> filteredStudents = [];
  Timer? _searchDebounce;
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

  // Cache'ler
  final Map<String, String> _groupNameCache = {};
  final Map<String, double> _feeCache = {};
  final Map<String, double> _paidCache = {};
  final Map<String, String> _statusCache = {};

  // Modern tema renkleri
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
    _initialize();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _groupNameCache.clear();
    _feeCache.clear();
    _paidCache.clear();
    _statusCache.clear();
    super.dispose();
  }

  // =========================================================================
  // 🔥 BAŞLANGIÇ YÜKLEMESİ
  // =========================================================================
  Future<void> _initialize() async {
    setState(() => isLoading = true);

    // Repository zaten yüklü değilse yükle
    if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }

    _prepareFilters();
    await _applyFiltersAndCalculate();

    setState(() => isLoading = false);
  }

  void _prepareFilters() {
    groupNames = ["Tümü", ..._repo.allGroups.map((g) => g.name).toSet()];

    final now = DateTime.now();
    monthOptions.clear();
    for (int i = -6; i <= 6; i++) {
      monthOptions.add(
        DateFormat('yyyy-MM').format(DateTime(now.year, now.month + i)),
      );
    }
    selectedMonthFilter = monthOptions[6];
  }

  // =========================================================================
  // 🔥 ÖĞRENCİ GRUP ADI (RAM'den anında)
  // =========================================================================
  String _getStudentGroupName(String studentId) {
    if (_groupNameCache.containsKey(studentId)) {
      return _groupNameCache[studentId]!;
    }

    final relations = _repo.getGroupStudentsByStudentId(studentId);
    final activeRelations = relations.where(
      (r) => r.is_active.toUpperCase() == "TRUE",
    );

    if (activeRelations.isEmpty) {
      _groupNameCache[studentId] = "Grup Yok";
      return "Grup Yok";
    }

    final groupId = activeRelations.first.groups_id;
    final group = _repo.getGroupById(groupId);

    final name = group?.name ?? "Grup Yok";
    _groupNameCache[studentId] = name;
    return name;
  }

  // =========================================================================
  // 🔥 AYLIK ÜCRET (RAM'den anında)
  // =========================================================================
  double _getStudentMonthlyFee(String studentId) {
    if (_feeCache.containsKey(studentId)) {
      return _feeCache[studentId]!;
    }

    final student = _repo.getUserById(studentId);
    final fee = double.tryParse(student?.amount ?? "0") ?? 0;
    _feeCache[studentId] = fee;
    return fee;
  }

  // =========================================================================
  // 🔥 ÖDENEN TUTAR
  // =========================================================================
  double _getStudentTotalPaid(String studentId, String monthYear) {
    final cacheKey = "${studentId}_$monthYear";
    if (_paidCache.containsKey(cacheKey)) {
      return _paidCache[cacheKey]!;
    }

    final parts = monthYear.split('-');
    if (parts.length != 2) return 0;
    final yr = int.parse(parts[0]);
    final mo = int.parse(parts[1]);

    final student = _repo.getUserById(studentId);
    if (student == null) return 0;

    // Kayıt tarihinden önceki ay kontrolü
    final regYear = _getRegistrationYear(student);
    final regMonth = _getRegistrationMonth(student);

    if (yr < regYear || (yr == regYear && mo < regMonth)) {
      _paidCache[cacheKey] = 0;
      return 0;
    }

    double total = 0;
    final payments = _repo.getPaymentsByStudentId(studentId);

    for (var p in payments) {
      final st = p.status.toString().toUpperCase();
      if (st != "PAID" && st != "TRUE") continue;

      try {
        final paidDate = DateTime.parse(p.paid_date.split('T')[0]);
        if (paidDate.year == yr && paidDate.month == mo) {
          total += double.tryParse(p.amount) ?? 0;
        }
      } catch (_) {}
    }

    _paidCache[cacheKey] = total;
    return total;
  }

  // =========================================================================
  // 🔥 ÖDEME DURUMU
  // =========================================================================
  String _getPaymentStatus(String studentId, String monthYear) {
    final cacheKey = "${studentId}_$monthYear";
    if (_statusCache.containsKey(cacheKey)) {
      return _statusCache[cacheKey]!;
    }

    final student = _repo.getUserById(studentId);
    if (student == null) return "unknown";

    final regYear = _getRegistrationYear(student);
    final regMonth = _getRegistrationMonth(student);
    final parts = monthYear.split('-');
    final yr = int.parse(parts[0]);
    final mo = int.parse(parts[1]);

    if (yr < regYear || (yr == regYear && mo < regMonth)) {
      _statusCache[cacheKey] = "registered_after";
      return "registered_after";
    }

    final fee = _getStudentMonthlyFee(studentId);
    final paid = _getStudentTotalPaid(studentId, monthYear);

    if (fee == 0) return "unknown";
    if (paid >= fee) return "paid";
    if (paid > 0) return "partial";
    return "unpaid";
  }

  int _getRegistrationYear(Users student) {
    final dateStr = student.created_at;
    if (dateStr.isEmpty) return DateTime.now().year;
    try {
      if (dateStr.contains('T')) return DateTime.parse(dateStr).year;
      if (dateStr.contains('-') && dateStr.length >= 10) {
        return int.parse(dateStr.substring(0, 4));
      }
      return DateTime.now().year;
    } catch (_) {
      return DateTime.now().year;
    }
  }

  int _getRegistrationMonth(Users student) {
    final dateStr = student.created_at;
    if (dateStr.isEmpty) return 1;
    try {
      if (dateStr.contains('T')) return DateTime.parse(dateStr).month;
      if (dateStr.contains('-') && dateStr.length >= 7) {
        return int.parse(dateStr.substring(5, 7));
      }
      return 1;
    } catch (_) {
      return 1;
    }
  }

  // =========================================================================
  // 🔥 FİLTRE UYGULA (Cache temizleme ile)
  // =========================================================================
  Future<void> _applyFiltersAndCalculate() async {
    // Filtre değişince cache'leri temizle
    _paidCache.clear();
    _statusCache.clear();

    final students = _repo.allUsers
        .where((u) => u.role.toLowerCase() == 'student')
        .toList();

    int paid = 0, partial = 0, unpaid = 0;
    final filtered = <Users>[];

    for (final student in students) {
      // İsim arama filtresi
      if (searchQuery.isNotEmpty) {
        final fullName = "${student.first_name} ${student.last_name}"
            .toLowerCase();
        if (!fullName.contains(searchQuery.toLowerCase()) &&
            !student.email.toLowerCase().contains(searchQuery.toLowerCase()) &&
            !student.phone.contains(searchQuery)) {
          continue;
        }
      }

      // Grup filtresi
      if (selectedGroupFilter != "Tümü") {
        final groupName = _getStudentGroupName(student.app);
        if (groupName != selectedGroupFilter) continue;
      }

      // Ödeme durumu
      final status = _getPaymentStatus(student.app, selectedMonthFilter);

      // Kayıt öncesi ayı atla
      if (status == "registered_after") continue;

      // Ödeme durumu filtresi
      if (selectedPaymentFilter != "Tümü") {
        if (selectedPaymentFilter == "Ödeyenler" && status != "paid") continue;
        if (selectedPaymentFilter == "Ödemeyenler" && status != "unpaid")
          continue;
        if (selectedPaymentFilter == "Kısmi Ödeyenler" && status != "partial")
          continue;
      }

      // Sayısal özet
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

      filtered.add(student);
    }

    setState(() {
      filteredStudents = filtered;
      _paidCount = paid;
      _partialCount = partial;
      _unpaidCount = unpaid;
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        searchQuery = value;
      });
      _applyFiltersAndCalculate();
    });
  }

  void _onGroupFilterChanged(String? value) {
    setState(() {
      selectedGroupFilter = value ?? "Tümü";
    });
    _applyFiltersAndCalculate();
  }

  void _onMonthFilterChanged(String? value) {
    setState(() {
      selectedMonthFilter = value ?? monthOptions[6];
    });
    _applyFiltersAndCalculate();
  }

  void _onPaymentFilterChanged(String filterValue) {
    setState(() {
      selectedPaymentFilter = selectedPaymentFilter == filterValue
          ? "Tümü"
          : filterValue;
    });
    _applyFiltersAndCalculate();
  }

  void _refreshData() async {
    setState(() => isLoading = true);
    _groupNameCache.clear();
    _feeCache.clear();
    _paidCache.clear();
    _statusCache.clear();
    await _repo.refreshAllData();
    await _applyFiltersAndCalculate();
    if (mounted) setState(() => isLoading = false);
  }

  // =========================================================================
  // 🔥 YARDIMCI FONKSİYONLAR (UI)
  // =========================================================================
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

  String _formatDate(String d) {
    if (d.isEmpty) return "—";
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(d.split('T')[0]));
    } catch (_) {
      return d;
    }
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
    final payments = _repo.getPaymentsByStudentId(student.app);

    for (var p in payments) {
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
                          final fee = _getStudentMonthlyFee(student.app);
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

  // =========================================================================
  // 🔥 UI BUILD
  // =========================================================================
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
            onPressed: _refreshData,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              onRefresh: () async {
                _refreshData();
              },
              color: _accent,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Özet kartı
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

                        // Filtreler
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
                                                _applyFiltersAndCalculate();
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
                                  onChanged: _onSearchChanged,
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
                                      onChanged: _onGroupFilterChanged,
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
                                      onChanged: _onMonthFilterChanged,
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
                                  onTap: () => _onPaymentFilterChanged(
                                    selectedPaymentFilter,
                                  ),
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
                              final status = _getPaymentStatus(
                                s.app,
                                selectedMonthFilter,
                              );
                              final color = _statusColor(status);
                              final fee = _getStudentMonthlyFee(s.app);
                              final paid = _getStudentTotalPaid(
                                s.app,
                                selectedMonthFilter,
                              );
                              final pct = fee > 0
                                  ? (paid / fee).clamp(0.0, 1.0)
                                  : 0.0;
                              final group = _getStudentGroupName(s.app);

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
                                      if (result == true) {
                                        _groupNameCache.clear();
                                        _feeCache.clear();
                                        _paidCache.clear();
                                        _statusCache.clear();
                                        await _applyFiltersAndCalculate();
                                      }
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
        onTap: () => _onPaymentFilterChanged(filterValue),
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
