// lib/managerpage/manager_student_attendance.dart
/*import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final Users currentUser;
  const TakeAttendanceScreen({super.key, required this.currentUser});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  final AppRepository _repo = AppRepository();
  final OfflineAttendanceService _offlineService = OfflineAttendanceService();

  String _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();

  List<Group> allGroups = [];
  Group? selectedGroup;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initOfflineService();
    _loadGroups();
  }

  Future<void> _initOfflineService() async {
    await _offlineService.init();
    _offlineService.onSyncComplete.listen((attendances) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  Future<void> _loadGroups() async {
    if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }
    if (mounted) {
      setState(() {
        allGroups = _repo.allGroups;
      });
    }
  }

  String _getDateTurkish(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();
      });
    }
  }

  Future<Map<String, dynamic>> _loadAttendanceData() async {
    if (selectedGroup == null) {
      return {'students': [], 'yoklamaListesi': []};
    }

    final allUsers = _repo.allUsers;
    final allRelations = _repo.allGroupStudents;
    final allPayments = _repo.allPayments;

    final groupRelations = allRelations
        .where(
          (rel) =>
              rel.groups_id == selectedGroup!.groups_id &&
              rel.is_active.toString().toUpperCase().trim() == "TRUE",
        )
        .toList();

    final studentIds = groupRelations.map((rel) => rel.student_id).toList();
    final students = allUsers
        .where(
          (user) =>
              studentIds.contains(user.app) &&
              user.role.toLowerCase() == "student",
        )
        .toList();

    final localAttendances = await _offlineService.getLocalAttendances(
      selectedGroup!.groups_id,
      selectedDate,
    );

    // Borç kontrolü - GÜVENLİ VERSİYON
    final selectedMonth = DateTime(selectedDate.year, selectedDate.month);
    final Map<String, bool> paymentStatus = {};

    for (var student in students) {
      final monthlyFee = double.tryParse(student.amount) ?? 0;
      if (monthlyFee == 0) {
        paymentStatus[student.app] = true;
        continue;
      }

      double paidThisMonth = 0;

      for (var payment in allPayments) {
        try {
          if (payment.student_id != student.app) continue; // ← DÜZELT

          final status = payment.status.toString().toUpperCase();
          if (status != "TRUE" && status != "PAID") continue;

          final paymentDateStr = payment.paid_date; // ← DÜZELT
          if (paymentDateStr == null || paymentDateStr.isEmpty) continue;

          String datePart = paymentDateStr;
          if (datePart.contains('T')) {
            datePart = datePart.split('T')[0];
          }

          final paidDate = DateTime.parse(datePart);
          if (paidDate.year == selectedMonth.year &&
              paidDate.month == selectedMonth.month) {
            paidThisMonth += double.tryParse(payment.amount) ?? 0;
          }
        } catch (e) {
          continue;
        }
      }
      paymentStatus[student.app] = paidThisMonth >= monthlyFee;
    }

    final List<Map<String, dynamic>> yoklamaListesi = [];
    for (var ogrenci in students) {
      final localAtt = localAttendances.firstWhere(
        (att) => att.student_id == ogrenci.app,
        orElse: () => Attendance(
          attendances_id: "",
          groups_id: "",
          student_id: "",
          taken_by: "",
          attendance_date: "",
          status: "FALSE",
          note: "",
        ),
      );

      final statusStr = localAtt.status.toString().toUpperCase().trim();
      final isPresent = (statusStr == "TRUE" || statusStr == "1");
      final hasPaid = paymentStatus[ogrenci.app] ?? false;

      yoklamaListesi.add({
        "student": ogrenci,
        "is_present": isPresent,
        "has_paid": hasPaid,
        "note": localAtt.note,
        "has_attendance": localAtt.attendances_id.isNotEmpty,
        "attendance_id": localAtt.attendances_id,
      });
    }

    return {
      'students': students,
      'yoklamaListesi': yoklamaListesi,
      'hasSaved': localAttendances.isNotEmpty,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedGroup?.name ?? "Yoklama Paneli",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              _getDateTurkish(selectedDate),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null && picked != selectedDate) {
                setState(() {
                  selectedDate = picked;
                  _refreshData();
                });
              }
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Group>(
                hint: const Text("Grup Seçiniz"),
                value: selectedGroup,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.indigo),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text("-- Grup Seçiniz --"),
                  ),
                  ...allGroups.map(
                    (g) => DropdownMenuItem(value: g, child: Text(g.name)),
                  ),
                ],
                onChanged: (group) {
                  setState(() {
                    selectedGroup = group;
                    _refreshData();
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: selectedGroup == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text("Lütfen bir grup seçin"),
                      ],
                    ),
                  )
                : FutureBuilder<Map<String, dynamic>>(
                    key: ValueKey(_refreshKey),
                    future: _loadAttendanceData(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.indigo,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text("Veriler yüklenirken hata oluştu"),
                        );
                      }
                      final list =
                          snapshot.data?['yoklamaListesi']
                              as List<Map<String, dynamic>>? ??
                          [];
                      return _YoklamaWidget(
                        key: ValueKey('yoklama_widget_${_refreshKey}'),
                        yoklamaListesi: list,
                        selectedGroup: selectedGroup!,
                        currentUser: widget.currentUser,
                        selectedDate: selectedDate,
                        onSaveComplete: _refreshData,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAM TASARIMLI YOKLAMA WIDGET
// ============================================================================
class _YoklamaWidget extends StatefulWidget {
  final List<Map<String, dynamic>> yoklamaListesi;
  final Group selectedGroup;
  final Users currentUser;
  final DateTime selectedDate;
  final VoidCallback onSaveComplete;

  const _YoklamaWidget({
    super.key,
    required this.yoklamaListesi,
    required this.selectedGroup,
    required this.currentUser,
    required this.selectedDate,
    required this.onSaveComplete,
  });

  @override
  State<_YoklamaWidget> createState() => _YoklamaWidgetState();
}

class _YoklamaWidgetState extends State<_YoklamaWidget> {
  final AppRepository _repo = AppRepository();
  final LocalStorageService _localStorage = LocalStorageService();
  final OfflineAttendanceService _offlineService = OfflineAttendanceService();

  late List<Map<String, dynamic>> _yoklamaListesi;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String _searchQuery = "";
  String _selectedFilter = "Tümü";
  final List<String> _filterOptions = ["Tümü", "Gelenler", "Gelmeyenler"];
  bool _showSuccess = false;
  String? _lastSaveMessage;

  @override
  void initState() {
    super.initState();
    _yoklamaListesi = List.from(widget.yoklamaListesi);
    _localStorage.init();
    _offlineService.init();
  }

  void _updateAttendance(int index, bool value) {
    setState(() {
      _yoklamaListesi[index]["is_present"] = value;
      _hasUnsavedChanges = true;
    });
  }

  void _updateNote(int index, String note) {
    setState(() {
      _yoklamaListesi[index]["note"] = note;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _saveAttendance() async {
    if (!_hasUnsavedChanges || _isSaving) return;

    setState(() {
      _isSaving = true;
      _showSuccess = false;
    });

    final formattedDate =
        "${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}";

    for (var item in _yoklamaListesi) {
      final student = item["student"] as Users;
      final attRecord = Attendance(
        attendances_id: item["attendance_id"]?.isNotEmpty == true
            ? item["attendance_id"]
            : "local_${DateTime.now().millisecondsSinceEpoch}_${student.app}",
        groups_id: widget.selectedGroup.groups_id,
        student_id: student.app,
        taken_by: widget.currentUser.app,
        attendance_date: "${formattedDate}T00:00:00.000Z",
        status: item["is_present"] == true ? "TRUE" : "FALSE",
        note: item["note"] ?? "",
      );

      _repo.allAttendances.removeWhere(
        (a) =>
            a.student_id == student.app &&
            a.groups_id == widget.selectedGroup.groups_id &&
            a.attendance_date.startsWith(formattedDate),
      );
      _repo.allAttendances.add(attRecord);
    }

    await _localStorage.saveAttendances(_repo.allAttendances);
    await _offlineService.saveAttendanceBatch(
      _yoklamaListesi,
      widget.selectedDate,
      widget.selectedGroup,
      widget.currentUser,
    );
    await _repo.refreshSingleTable('attendances');

    setState(() {
      _isSaving = false;
      _hasUnsavedChanges = false;
      _lastSaveMessage =
          "✅ ${_yoklamaListesi.length} öğrencinin yoklaması kaydedildi!";
      _showSuccess = true;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSuccess = false);
    });

    widget.onSaveComplete();
  }

  void _showNoteDialog(int index, Users student) {
    final controller = TextEditingController(
      text: _yoklamaListesi[index]["note"] ?? "",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("${student.first_name} ${student.last_name}"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Not ekle...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () {
              _updateNote(index, controller.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Not kaydedildi"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  String _formatDateFromString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  int _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return 0;
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildDefaultAvatar(Users student, double size) {
    String initial = student.first_name.isNotEmpty
        ? student.first_name[0].toUpperCase()
        : "?";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(String? imageUrl, double size, Users student) {
    return imageUrl != null && imageUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildDefaultAvatar(student, size),
            ),
          )
        : _buildDefaultAvatar(student, size);
  }

  List<Map<String, dynamic>> get _filteredList {
    var list = _yoklamaListesi;
    if (_searchQuery.isNotEmpty) {
      list = list.where((item) {
        final ogrenci = item["student"] as Users;
        return ogrenci.first_name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            ogrenci.last_name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
      }).toList();
    }
    if (_selectedFilter == "Gelenler") {
      list = list.where((item) => item["is_present"] == true).toList();
    } else if (_selectedFilter == "Gelmeyenler") {
      list = list.where((item) => item["is_present"] == false).toList();
    }
    return list;
  }

  int get presentCount =>
      _yoklamaListesi.where((item) => item["is_present"] == true).length;
  int get absentCount =>
      _yoklamaListesi.where((item) => item["is_present"] == false).length;
  int get totalCount => _yoklamaListesi.length;
  double get presentPercentage =>
      totalCount > 0 ? (presentCount / totalCount) * 100 : 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // İSTATİSTİK KARTLARI
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("Toplam", totalCount, Icons.people, Colors.white),
              _statItem(
                "Gelen",
                presentCount,
                Icons.check_circle,
                Colors.green.shade300,
              ),
              _statItem(
                "Gelmeyen",
                absentCount,
                Icons.cancel,
                Colors.red.shade300,
              ),
              _statItem(
                "Katılım",
                "${presentPercentage.toStringAsFixed(0)}%",
                Icons.trending_up,
                Colors.orange.shade300,
              ),
            ],
          ),
        ),

        // BAŞARI MESAJI
        if (_showSuccess && _lastSaveMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _lastSaveMessage!,
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ARAMA VE FİLTRE
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Öğrenci ara...",
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    icon: const Icon(Icons.filter_list, size: 18),
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    items: _filterOptions
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedFilter = value!),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ÖĞRENCİ LİSTESİ
        Expanded(
          child: _filteredList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Öğrenci bulunamadı",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  itemCount: _filteredList.length,
                  itemBuilder: (context, index) {
                    final item = _filteredList[index];
                    final originalIndex = _yoklamaListesi.indexOf(item);
                    final ogrenci = item["student"] as Users;
                    final isPresent = item["is_present"] == true;
                    final hasNote = (item["note"] ?? "").isNotEmpty;
                    final hasDebt = item["has_paid"] == false;
                    return _buildStudentCard(
                      ogrenci,
                      isPresent,
                      hasNote,
                      hasDebt,
                      originalIndex,
                    );
                  },
                ),
        ),

        // KAYDET BUTONU
        if (_hasUnsavedChanges)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAttendance,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 20),
                label: Text(
                  _isSaving ? "Kaydediliyor..." : "Yoklamayı Kaydet",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _statItem(String title, dynamic value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildStudentCard(
    Users student,
    bool isPresent,
    bool hasNote,
    bool hasDebt,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPresent
              ? Colors.green.withOpacity(0.5)
              : Colors.red.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isPresent
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // PROFİL FOTOĞRAFI
            _buildProfileImage(student.profile_photo_url, 55, student),
            const SizedBox(width: 12),

            // ÖĞRENCİ BİLGİLERİ
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${student.first_name} ${student.last_name}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // BORÇ UYARISI
                      if (hasDebt)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Tooltip(
                            message:
                                "Bu öğrencinin bu ay için ödenmemiş borcu var!",
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // YAŞ
                  if (student.b_date.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          size: 12,
                          color: Colors.orange.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${_calculateAge(student.b_date)} yaş",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  // TELEFON
                  if (student.phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 12,
                            color: Colors.green.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            student.phone,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // NOT
                  if (hasNote)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.note_outlined,
                            size: 12,
                            color: Colors.indigo.shade400,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _yoklamaListesi[index]["note"] ?? "",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.indigo.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // AKSİYONLAR (Switch + Butonlar)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // YOKLAMA SWITCH
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: isPresent,
                    onChanged: (val) => _updateAttendance(index, val),
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                    inactiveTrackColor: Colors.red.shade100,
                  ),
                ),
                const SizedBox(height: 6),
                // TELEFON ARAMA + NOT BUTONLARI
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (student.phone.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final url = Uri.parse("tel:${student.phone}");
                          if (await canLaunchUrl(url)) await launchUrl(url);
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.call,
                            color: Colors.green,
                            size: 16,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showNoteDialog(index, student),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: hasNote
                              ? Colors.indigo.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.note_alt_outlined,
                          color: hasNote ? Colors.indigo : Colors.grey,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
*/ // lib/managerpage/manager_student_attendance.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/local/local_storage_service.dart';
import 'package:EVOM_SPOR/managerpage/manager_offline/offline_attendance_service.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final Users currentUser;
  const TakeAttendanceScreen({super.key, required this.currentUser});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  final AppRepository _repo = AppRepository();
  final OfflineAttendanceService _offlineService = OfflineAttendanceService();

  String _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();

  List<Group> allGroups = [];
  Group? selectedGroup;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initOfflineService();
    _loadGroups();
  }

  Future<void> _initOfflineService() async {
    await _offlineService.init();
    _offlineService.onSyncComplete.listen((attendances) {
      if (mounted) {
        print("🔄 Senkronizasyon tamamlandı, UI güncelleniyor...");
        _refreshData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("☁️ Veriler bulut ile senkronize edildi!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _loadGroups() async {
    if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }
    if (mounted) {
      setState(() {
        allGroups = _repo.allGroups;
      });
    }
  }

  String _getDateTurkish(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();
      });
    }
  }

  Future<void> _syncGroupAttendanceInBackground() async {
    if (selectedGroup == null) return;
    try {
      print(
        "☁️ Arka Plan: Seçilen ${selectedGroup!.name} grubu için günlük yoklamalar tazelemeye alınıyor...",
      );
      await _repo.refreshSingleTable('attendances');
      _refreshData();
    } catch (e) {
      print(
        "⚠️ Arka Plan Hatası: İnternet olmadığı için günlük yoklama eşitlemesi atlandı, lokale güveniliyor.",
      );
    }
  }

  Future<Map<String, dynamic>> _loadAttendanceData() async {
    if (selectedGroup == null) {
      return {'students': [], 'yoklamaListesi': []};
    }

    final allUsers = _repo.allUsers;
    final allRelations = _repo.allGroupStudents;
    final allPayments = _repo.allPayments;

    final groupRelations = allRelations
        .where(
          (rel) =>
              rel.groups_id == selectedGroup!.groups_id &&
              rel.is_active.toString().toUpperCase().trim() == "TRUE",
        )
        .toList();

    final studentIds = groupRelations.map((rel) => rel.student_id).toList();
    final students = allUsers
        .where(
          (user) =>
              studentIds.contains(user.app) &&
              user.role.toLowerCase() == "student",
        )
        .toList();

    final localAttendances = await _offlineService.getLocalAttendances(
      selectedGroup!.groups_id,
      selectedDate,
    );

    final selectedMonth = DateTime(selectedDate.year, selectedDate.month);
    final Map<String, bool> paymentStatus = {};

    for (var student in students) {
      final monthlyFee = double.tryParse(student.amount) ?? 0;
      if (monthlyFee == 0) {
        paymentStatus[student.app] = true;
        continue;
      }

      double paidThisMonth = 0;
      for (var payment in allPayments) {
        try {
          if (payment.student_id != student.app) continue;

          final status = payment.status.toString().toUpperCase();
          if (status != "TRUE" && status != "PAID") continue;

          final paymentDateStr = payment.paid_date;
          if (paymentDateStr == null || paymentDateStr.isEmpty) continue;

          String datePart = paymentDateStr;
          if (datePart.contains('T')) {
            datePart = datePart.split('T')[0];
          }

          final paidDate = DateTime.parse(datePart);
          if (paidDate.year == selectedMonth.year &&
              paidDate.month == selectedMonth.month) {
            paidThisMonth += double.tryParse(payment.amount) ?? 0;
          }
        } catch (e) {
          continue;
        }
      }
      paymentStatus[student.app] = paidThisMonth >= monthlyFee;
    }

    final List<Map<String, dynamic>> yoklamaListesi = [];
    for (var ogrenci in students) {
      final localAtt = localAttendances.firstWhere(
        (att) => att.student_id == ogrenci.app,
        orElse: () => Attendance(
          attendances_id: "",
          groups_id: "",
          student_id: "",
          taken_by: "",
          attendance_date: "",
          status: "FALSE",
          note: "",
        ),
      );

      final statusStr = localAtt.status.toString().toUpperCase().trim();
      final isPresent = (statusStr == "TRUE" || statusStr == "1");
      final hasPaid = paymentStatus[ogrenci.app] ?? false;

      yoklamaListesi.add({
        "student": ogrenci,
        "is_present": isPresent,
        "has_paid": hasPaid,
        "note": localAtt.note,
        "has_attendance": localAtt.attendances_id.isNotEmpty,
        "attendance_id": localAtt.attendances_id,
      });
    }

    return {
      'students': students,
      'yoklamaListesi': yoklamaListesi,
      'hasSaved': localAttendances.isNotEmpty,
    };
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Tarih Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked != null && picked != selectedDate) {
      if (mounted) {
        setState(() {
          selectedDate = picked;
          _refreshKey = DateTime.now().millisecondsSinceEpoch.toString();
        });
        unawaited(_syncGroupAttendanceInBackground());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedGroup?.name ?? "Yoklama Paneli",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              _getDateTurkish(selectedDate),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: "Tarih Seç",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: "Yenile",
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Group>(
                hint: const Text("Grup Seçiniz"),
                value: selectedGroup,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.indigo),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text("-- Grup Seçiniz --"),
                  ),
                  ...allGroups.map(
                    (g) => DropdownMenuItem(value: g, child: Text(g.name)),
                  ),
                ],
                onChanged: (group) {
                  setState(() {
                    selectedGroup = group;
                    _refreshKey = DateTime.now().millisecondsSinceEpoch
                        .toString();
                  });
                  unawaited(_syncGroupAttendanceInBackground());
                },
              ),
            ),
          ),
          Expanded(
            child: selectedGroup == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text("Lütfen bir grup seçin"),
                      ],
                    ),
                  )
                : FutureBuilder<Map<String, dynamic>>(
                    key: ValueKey(_refreshKey),
                    future: _loadAttendanceData(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.indigo,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text("Veriler yüklenirken hata oluştu"),
                        );
                      }
                      final list =
                          snapshot.data?['yoklamaListesi']
                              as List<Map<String, dynamic>>? ??
                          [];
                      return _YoklamaWidget(
                        key: ValueKey('yoklama_widget_${_refreshKey}'),
                        yoklamaListesi: list,
                        selectedGroup: selectedGroup!,
                        currentUser: widget.currentUser,
                        selectedDate: selectedDate,
                        onSaveComplete: _refreshData,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// YOKLAMA WIDGET
// ============================================================================
class _YoklamaWidget extends StatefulWidget {
  final List<Map<String, dynamic>> yoklamaListesi;
  final Group selectedGroup;
  final Users currentUser;
  final DateTime selectedDate;
  final VoidCallback onSaveComplete;

  const _YoklamaWidget({
    super.key,
    required this.yoklamaListesi,
    required this.selectedGroup,
    required this.currentUser,
    required this.selectedDate,
    required this.onSaveComplete,
  });

  @override
  State<_YoklamaWidget> createState() => _YoklamaWidgetState();
}

class _YoklamaWidgetState extends State<_YoklamaWidget> {
  final AppRepository _repo = AppRepository();
  final LocalStorageService _localStorage = LocalStorageService();
  final OfflineAttendanceService _offlineService = OfflineAttendanceService();

  late List<Map<String, dynamic>> _yoklamaListesi;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String _searchQuery = "";
  String _selectedFilter = "Tümü";
  final List<String> _filterOptions = ["Tümü", "Gelenler", "Gelmeyenler"];
  bool _showSuccess = false;
  String? _lastSaveMessage;
  Timer? _successTimer;

  @override
  void initState() {
    super.initState();
    _yoklamaListesi = List.from(widget.yoklamaListesi);
    _localStorage.init();
    _offlineService.init();

    // 🔥 SENKRONİZASYON TAMAMLANDIĞINDA UI GÜNCELLE
    _offlineService.onSyncComplete.listen((attendances) {
      if (mounted) {
        print("🔄 Senkronizasyon tamamlandı, UI güncelleniyor...");
        _refreshData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("☁️ Veriler bulut ile senkronize edildi!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _refreshData() {
    setState(() {
      // UI'ı yenile
    });
  }

  void _updateAttendance(int index, bool value) {
    setState(() {
      _yoklamaListesi[index]["is_present"] = value;
      _hasUnsavedChanges = true;
    });
  }

  void _updateNote(int index, String note) {
    setState(() {
      _yoklamaListesi[index]["note"] = note;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _saveAttendance() async {
    if (!_hasUnsavedChanges || _isSaving) return;
    if (!mounted) return;

    setState(() {
      _isSaving = true;
      _showSuccess = false;
    });

    final formattedDate =
        "${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}";

    // 🔥 TÜM ÖĞRENCİLERİ KAYDET
    final List<Map<String, dynamic>> allItems = [];

    for (var item in _yoklamaListesi) {
      final student = item["student"] as Users;
      final isPresent = item["is_present"] == true;
      final note = item["note"] ?? "";

      // Önce _repo.allAttendances içinde mevcut kaydı ara
      final existingIndex = _repo.allAttendances.indexWhere(
        (a) =>
            a.student_id == student.app &&
            a.groups_id == widget.selectedGroup.groups_id &&
            a.attendance_date.startsWith(formattedDate),
      );

      String attendanceId;
      if (existingIndex != -1) {
        attendanceId = _repo.allAttendances[existingIndex].attendances_id;
      } else if (item["attendance_id"] != null &&
          item["attendance_id"].toString().isNotEmpty) {
        attendanceId = item["attendance_id"].toString();
      } else {
        attendanceId =
            "local_${DateTime.now().millisecondsSinceEpoch}_${student.app}";
      }

      final attRecord = Attendance(
        attendances_id: attendanceId,
        groups_id: widget.selectedGroup.groups_id,
        student_id: student.app,
        taken_by: widget.currentUser.app,
        attendance_date: formattedDate,
        status: isPresent ? "TRUE" : "FALSE",
        note: note,
      );

      // Eski kaydı kaldır ve yenisini ekle (ID korunarak)
      _repo.allAttendances.removeWhere(
        (a) =>
            a.student_id == student.app &&
            a.groups_id == widget.selectedGroup.groups_id &&
            a.attendance_date.startsWith(formattedDate),
      );
      _repo.allAttendances.add(attRecord);

      allItems.add({
        "student": student,
        "is_present": isPresent,
        "note": note,
        "attendance_id": attendanceId,
      });
    }

    await _localStorage.saveAttendances(_repo.allAttendances);

    print("🔥 Tüm öğrenciler kaydedildi: ${allItems.length} öğrenci");

    // 🔥 OFFLINE SERVİSE GÖNDER
    final result = await _offlineService.saveAttendanceBatch(
      allItems,
      widget.selectedDate,
      widget.selectedGroup,
      widget.currentUser,
    );

    print("🔥 OfflineService sonucu: $result");

    await _repo.refreshSingleTable('attendances');

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _hasUnsavedChanges = false;
      _lastSaveMessage =
          "✅ ${allItems.length} öğrencinin yoklaması kaydedildi!";
      _showSuccess = true;
    });

    // 🔥 Timer ile mesajı kapat
    _successTimer?.cancel();
    _successTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSuccess = false;
        });
      }
    });

    if (mounted) {
      widget.onSaveComplete();
    }
  }

  void _showNoteDialog(int index, Users student) {
    final controller = TextEditingController(
      text: _yoklamaListesi[index]["note"] ?? "",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("${student.first_name} ${student.last_name}"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Not ekle...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () {
              _updateNote(index, controller.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Not kaydedildi"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  String _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return "0";
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age.toString();
    } catch (e) {
      return "0";
    }
  }

  Widget _buildProfileImage(String? imageUrl, double size, Users student) {
    return imageUrl != null && imageUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildDefaultAvatar(student, size),
            ),
          )
        : _buildDefaultAvatar(student, size);
  }

  Widget _buildDefaultAvatar(Users student, double size) {
    String initial = student.first_name.isNotEmpty
        ? student.first_name[0].toUpperCase()
        : "?";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredList {
    var list = _yoklamaListesi;
    if (_searchQuery.isNotEmpty) {
      list = list.where((item) {
        final ogrenci = item["student"] as Users;
        return ogrenci.first_name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            ogrenci.last_name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
      }).toList();
    }
    if (_selectedFilter == "Gelenler") {
      list = list.where((item) => item["is_present"] == true).toList();
    } else if (_selectedFilter == "Gelmeyenler") {
      list = list.where((item) => item["is_present"] == false).toList();
    }
    return list;
  }

  int get presentCount =>
      _yoklamaListesi.where((item) => item["is_present"] == true).length;
  int get absentCount =>
      _yoklamaListesi.where((item) => item["is_present"] == false).length;
  int get totalCount => _yoklamaListesi.length;
  double get presentPercentage =>
      totalCount > 0 ? (presentCount / totalCount) * 100 : 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("Toplam", totalCount, Icons.people, Colors.white),
              _statItem(
                "Gelen",
                presentCount,
                Icons.check_circle,
                Colors.green.shade300,
              ),
              _statItem(
                "Gelmeyen",
                absentCount,
                Icons.cancel,
                Colors.red.shade300,
              ),
              _statItem(
                "Katılım",
                "${presentPercentage.toStringAsFixed(0)}%",
                Icons.trending_up,
                Colors.orange.shade300,
              ),
            ],
          ),
        ),
        if (_showSuccess && _lastSaveMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _lastSaveMessage!,
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Öğrenci ara...",
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    icon: const Icon(Icons.filter_list, size: 18),
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    items: _filterOptions
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedFilter = value!),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Öğrenci bulunamadı",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  itemCount: _filteredList.length,
                  itemBuilder: (context, index) {
                    final item = _filteredList[index];
                    return _buildStudentCard(
                      item["student"] as Users,
                      item["is_present"] == true,
                      (item["note"] ?? "").isNotEmpty,
                      item["has_paid"] == false,
                      _yoklamaListesi.indexOf(item),
                    );
                  },
                ),
        ),
        if (_hasUnsavedChanges)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAttendance,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 20),
                label: Text(
                  _isSaving ? "Kaydediliyor..." : "Yoklamayı Kaydet",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _statItem(String title, dynamic value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildStudentCard(
    Users student,
    bool isPresent,
    bool hasNote,
    bool hasDebt,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPresent
              ? Colors.green.withOpacity(0.5)
              : Colors.red.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isPresent
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _buildProfileImage(student.profile_photo_url, 55, student),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${student.first_name} ${student.last_name}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasDebt)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Tooltip(
                            message:
                                "Bu öğrencinin bu ay için ödenmemiş borcu var!",
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (student.b_date.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          size: 12,
                          color: Colors.orange.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${_calculateAge(student.b_date)} yaş",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  if (student.phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 12,
                            color: Colors.green.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            student.phone,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasNote)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.note_outlined,
                            size: 12,
                            color: Colors.indigo.shade400,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _yoklamaListesi[index]["note"] ?? "",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.indigo.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: isPresent,
                    onChanged: (val) => _updateAttendance(index, val),
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                    inactiveTrackColor: Colors.red.shade100,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (student.phone.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final url = Uri.parse("tel:${student.phone}");
                          if (await canLaunchUrl(url)) await launchUrl(url);
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.call,
                            color: Colors.green,
                            size: 16,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showNoteDialog(index, student),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: hasNote
                              ? Colors.indigo.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.note_alt_outlined,
                          color: hasNote ? Colors.indigo : Colors.grey,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }
}
