/*
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final Users currentUser;

  const TakeAttendanceScreen({super.key, required this.currentUser});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  late Future<Map<String, dynamic>> _dataFuture;

  // Veri listeleri
  List<Group> allGroups = [];
  List<Users> allUsers = [];
  List<GroupStudent> allRelations = [];
  List<Attendance> allAttendances = [];

  // Seçili grup ve öğrenciler
  Group? selectedGroup;
  List<Users> studentsInGroup = [];

  // Yoklama verileri
  Map<String, bool> attendanceMap = {};
  Map<String, String> noteMap = {};
  Map<String, bool> existingRecordMap = {};

  // Tarih ve UI durumları
  DateTime selectedDate = DateTime.now();
  bool isSaving = false;
  bool _hasUnsavedChanges = false;

  // Arama ve Filtreleme
  String searchQuery = "";
  String selectedFilter = "Tümü";
  final List<String> filterOptions = ["Tümü", "Gelenler", "Gelmeyenler"];

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadAllData();
  }

  // =========================================================================
  // VERİ YÜKLEME
  // =========================================================================
  Future<Map<String, dynamic>> _loadAllData() async {
    try {
      final results = await Future.wait([
        GoogleSheetService.getGroupsCached(),
        GoogleSheetService.getUsersCached(),
        GoogleSheetService.getGroupStudentsCached(),
        GoogleSheetService.getAttendancesCached(),
      ]);

      final groups = results[0] as List<Group>;
      final users = results[1] as List<Users>;
      final relations = results[2] as List<GroupStudent>;

      final rawAttendances = results[3] as List<Attendance>;
      final attendances = rawAttendances
          .map((att) => _cleanAttendanceDate(att))
          .toList();

      return {
        'groups': groups,
        'users': users,
        'relations': relations,
        'attendances': attendances,
      };
    } catch (e) {
      _showSnackBar("Veriler yüklenirken hata oluştu", isError: true);
      return {
        'groups': <Group>[],
        'users': <Users>[],
        'relations': <GroupStudent>[],
        'attendances': <Attendance>[],
      };
    }
  }

  Attendance _cleanAttendanceDate(Attendance att) {
    String cleanDate = att.attendance_date;
    if (cleanDate.contains('T')) {
      cleanDate = cleanDate.split('T')[0];
    }

    String cleanStatus = att.status ?? "";
    if (cleanStatus.isNotEmpty) {
      cleanStatus = cleanStatus.toUpperCase();
      if (cleanStatus == "TRUE" || cleanStatus == "1" || cleanStatus == "YES") {
        cleanStatus = "TRUE";
      } else {
        cleanStatus = "FALSE";
      }
    }

    return Attendance(
      attendances_id: att.attendances_id,
      groups_id: att.groups_id,
      student_id: att.student_id,
      taken_by: att.taken_by,
      attendance_date: cleanDate,
      status: cleanStatus,
      note: att.note,
    );
  }

  // =========================================================================
  // GRUP SEÇİMİ
  // =========================================================================
  void _onGroupSelected(Group? group) {
    if (group == null) return;

    final students = allUsers.where((u) {
      return allRelations.any(
        (rel) =>
            rel.groups_id == group.groups_id &&
            rel.student_id == u.app &&
            rel.is_active.toString().toUpperCase() == "TRUE",
      );
    }).toList();

    setState(() {
      selectedGroup = group;
      studentsInGroup = students;
      searchQuery = "";
      selectedFilter = "Tümü";
      _hasUnsavedChanges = false;
    });

    _loadAttendanceForDate(selectedDate);
  }

  // =========================================================================
  // TARİHE GÖRE YOKLAMA YÜKLE
  // =========================================================================
  void _loadAttendanceForDate(DateTime date) {
    if (selectedGroup == null) return;

    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    final dateAttendances = allAttendances.where((a) {
      return a.groups_id == selectedGroup!.groups_id &&
          a.attendance_date == formattedDate;
    }).toList();

    final Map<String, bool> tempAttendance = {};
    final Map<String, String> tempNotes = {};
    final Map<String, bool> tempExisting = {};

    for (var student in studentsInGroup) {
      final existing = dateAttendances.firstWhere(
        (a) => a.student_id == student.app,
        orElse: () => Attendance(
          attendances_id: "",
          groups_id: "",
          student_id: "",
          taken_by: "",
          attendance_date: "",
          status: "",
          note: "",
        ),
      );

      bool isPresent = false;
      if (existing.status != null && existing.status.isNotEmpty) {
        final statusStr = existing.status.toString().toUpperCase();
        isPresent =
            (statusStr == "TRUE" || statusStr == "1" || statusStr == "YES");
      }

      tempAttendance[student.app] = isPresent;
      tempNotes[student.app] = existing.note ?? "";
      tempExisting[student.app] = existing.attendances_id.isNotEmpty;
    }

    setState(() {
      attendanceMap = tempAttendance;
      noteMap = tempNotes;
      existingRecordMap = tempExisting;
      _hasUnsavedChanges = false;
    });
  }

  // =========================================================================
  // FİLTRELENMİŞ ÖĞRENCİ LİSTESİ
  // =========================================================================
  List<Users> get _filteredStudents {
    var list = studentsInGroup;

    if (searchQuery.isNotEmpty) {
      list = list.where((student) {
        return student.first_name.toLowerCase().contains(
              searchQuery.toLowerCase(),
            ) ||
            student.last_name.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    if (selectedFilter == "Gelenler") {
      list = list
          .where((student) => attendanceMap[student.app] == true)
          .toList();
    } else if (selectedFilter == "Gelmeyenler") {
      list = list
          .where((student) => attendanceMap[student.app] == false)
          .toList();
    }

    return list;
  }

  // =========================================================================
  // YARDIMCI FONKSİYONLAR
  // =========================================================================
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _hasAnyExistingRecord() {
    return existingRecordMap.values.any((v) => v == true);
  }

  String _getStatusText() {
    if (_isToday(selectedDate)) {
      return "Bugünkü Yoklama";
    } else if (_hasAnyExistingRecord()) {
      return "Geçmiş Yoklama (Düzenlenebilir)";
    } else {
      return "Yeni Yoklama Alınacak";
    }
  }

  Color _getStatusColor() {
    if (_isToday(selectedDate)) {
      return Colors.green;
    } else if (_hasAnyExistingRecord()) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  int get presentCount => attendanceMap.values.where((v) => v == true).length;
  int get absentCount => attendanceMap.values.where((v) => v == false).length;
  int get totalCount => studentsInGroup.length;
  double get presentPercentage =>
      totalCount > 0 ? (presentCount / totalCount) * 100 : 0;

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =========================================================================
  // TARİH SEÇİMİ
  // =========================================================================
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        searchQuery = "";
        selectedFilter = "Tümü";
        _hasUnsavedChanges = false;
      });
      _loadAttendanceForDate(picked);
    }
  }

  // =========================================================================
  // YOKLAMA KAYDETME (ARKA PLANDA)
  // =========================================================================
  Future<void> _saveInBackground() async {
    if (selectedGroup == null) return;

    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    int successCount = 0;

    for (var student in studentsInGroup) {
      final isPresent = attendanceMap[student.app] ?? false;
      final note = noteMap[student.app] ?? "";

      final attendance = Attendance(
        attendances_id: "",
        groups_id: selectedGroup!.groups_id,
        student_id: student.app,
        taken_by: widget.currentUser.app,
        attendance_date: formattedDate,
        status: isPresent ? "TRUE" : "FALSE",
        note: note,
      );

      bool success = await GoogleSheetService.saveAttendance(attendance);
      if (success) successCount++;
    }

    final freshAttendances = await GoogleSheetService.getAttendancesCached(
      forceRefresh: true,
    );
    allAttendances = freshAttendances
        .map((att) => _cleanAttendanceDate(att))
        .toList();

    if (mounted) {
      _showSnackBar("✅ $successCount öğrencinin yoklaması kaydedildi");
    }
  }

  Future<void> _saveAttendance() async {
    if (selectedGroup == null) {
      _showSnackBar("Lütfen bir grup seçin", isError: true);
      return;
    }

    if (!_isToday(selectedDate) && _hasAnyExistingRecord()) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text("Geçmiş Yoklamayı Düzenle"),
            ],
          ),
          content: const Text(
            "Bu tarih için daha önce yoklama alınmış. Yapacağınız değişiklikler mevcut yoklamanın üzerine yazılacak.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text("Güncelle"),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => isSaving = true);
    await _saveInBackground();
    setState(() => isSaving = false);
    _hasUnsavedChanges = false;
  }

  // =========================================================================
  // ÇIKIŞ DİYALOĞU
  // =========================================================================
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges || selectedGroup == null) return true;

    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
            SizedBox(height: 12),
            Text(
              "Kaydedilmemiş Değişiklikler",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Yoklamayı kaydetmeden çıkmak istiyor musunuz?"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatChip(
                    "Toplam",
                    totalCount,
                    Icons.people,
                    Colors.blue,
                  ),
                  _buildStatChip(
                    "Gelen",
                    presentCount,
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildStatChip(
                    "Gelmeyen",
                    absentCount,
                    Icons.cancel,
                    Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Kaydetmeden Çık"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, null);
              _saveInBackground().then((_) {
                if (mounted) Navigator.pop(context);
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text("Kaydet ve Çık"),
          ),
        ],
      ),
    );

    if (shouldSave == null) return false;
    return shouldSave;
  }

  Widget _buildStatChip(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  // =========================================================================
  // NOT DİYALOĞU
  // =========================================================================
  void _showNoteDialog(String studentId, String studentName) {
    final controller = TextEditingController(text: noteMap[studentId] ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("$studentName - Not Ekle"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Devamsızlık notu veya açıklama...",
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
              setState(() {
                noteMap[studentId] = controller.text;
                _hasUnsavedChanges = true;
              });
              Navigator.pop(ctx);
              _showSnackBar("Not kaydedildi");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // UI BİLEŞENLERİ
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (mounted && shouldPop) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            "Yoklama Yönetimi",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Ana sayfayı yeniden başlatmadan geri dön
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _selectDate,
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text("Hata: ${snapshot.error}"),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _dataFuture = _loadAllData();
                        });
                      },
                      child: const Text("Tekrar Dene"),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            allGroups = data['groups'] ?? [];
            allUsers = data['users'] ?? [];
            allRelations = data['relations'] ?? [];
            allAttendances = data['attendances'] ?? [];

            return Column(
              children: [
                _buildStatusBar(),
                _buildStatsCard(),
                _buildGroupSelector(),
                _buildSearchAndFilter(),
                Expanded(
                  child: selectedGroup == null
                      ? _buildEmptyState(
                          Icons.group_off,
                          "Grup Seçilmedi",
                          "Lütfen bir grup seçin",
                        )
                      : studentsInGroup.isEmpty
                      ? _buildEmptyState(
                          Icons.people_outline,
                          "Öğrenci Yok",
                          "Bu grupta aktif öğrenci bulunmuyor",
                        )
                      : _filteredStudents.isEmpty
                      ? _buildEmptyState(
                          Icons.search_off,
                          "Öğrenci Bulunamadı",
                          "Arama kriterlerinize uygun öğrenci yok",
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = _filteredStudents[index];
                            final isPresent =
                                attendanceMap[student.app] ?? false;
                            final hasNote =
                                noteMap[student.app]?.isNotEmpty ?? false;
                            return _buildStudentCard(
                              student,
                              isPresent,
                              hasNote,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: selectedGroup != null && studentsInGroup.isNotEmpty
            ? _buildBottomButton()
            : null,
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.indigo),
          SizedBox(height: 16),
          Text("Veriler yükleniyor..."),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            "Toplam",
            totalCount.toString(),
            Icons.people,
            Colors.white,
          ),
          _buildStatItem(
            "Gelen",
            presentCount.toString(),
            Icons.check_circle,
            Colors.green.shade300,
          ),
          _buildStatItem(
            "Gelmeyen",
            absentCount.toString(),
            Icons.cancel,
            Colors.red.shade300,
          ),
          _buildStatItem(
            "Katılım",
            "${presentPercentage.toStringAsFixed(0)}%",
            Icons.trending_up,
            Colors.orange.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
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

  Widget _buildStatusBar() {
    final dateStr = DateFormat('dd/MM/yyyy').format(selectedDate);
    final statusText = _getStatusText();
    final statusColor = _getStatusColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            _isToday(selectedDate) ? Icons.today : Icons.calendar_month,
            size: 18,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Text(
            "$dateStr • $statusText",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: statusColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
          onChanged: _onGroupSelected,
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
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
                onChanged: (value) => setState(() => searchQuery = value),
                decoration: InputDecoration(
                  hintText: "Öğrenci ara...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: selectedFilter,
              items: filterOptions.map((filter) {
                return DropdownMenuItem(
                  value: filter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          filter == "Tümü"
                              ? Icons.list_alt
                              : filter == "Gelenler"
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 16,
                          color: filter == "Tümü"
                              ? Colors.blue
                              : filter == "Gelenler"
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(filter),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedFilter = value!),
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list, color: Colors.indigo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Users student, bool isPresent, bool hasNote) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  student.first_name.isNotEmpty
                      ? student.first_name[0].toUpperCase()
                      : "?",
                  style: TextStyle(
                    color: isPresent
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            title: Text(
              "${student.first_name} ${student.last_name}",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: hasNote
                ? Text(
                    noteMap[student.app] ?? "",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.indigo.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.note_alt,
                    color: hasNote ? Colors.indigo : Colors.grey.shade400,
                    size: 22,
                  ),
                  onPressed: () => _showNoteDialog(
                    student.app,
                    "${student.first_name} ${student.last_name}",
                  ),
                ),
                Switch(
                  value: isPresent,
                  onChanged: (val) {
                    setState(() {
                      attendanceMap[student.app] = val;
                      _hasUnsavedChanges = true;
                    });
                  },
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                ),
              ],
            ),
          ),
          if (hasNote)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note, size: 16, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        noteMap[student.app] ?? "",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: isSaving ? null : _saveAttendance,
          icon: isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save),
          label: Text(
            isSaving ? "Kaydediliyor..." : "Yoklamayı Kaydet",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
*/
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final Users currentUser;

  const TakeAttendanceScreen({super.key, required this.currentUser});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  late Future<Map<String, dynamic>> _dataFuture;

  // Veri listeleri
  List<Group> allGroups = [];
  List<Users> allUsers = [];
  List<GroupStudent> allRelations = [];
  List<Attendance> allAttendances = [];

  // Seçili grup ve öğrenciler
  Group? selectedGroup;
  List<Users> studentsInGroup = [];

  // Yoklama verileri
  Map<String, bool> attendanceMap = {};
  Map<String, String> noteMap = {};
  Map<String, bool> existingRecordMap = {};

  // Tarih ve UI durumları
  DateTime selectedDate = DateTime.now();
  bool isSaving = false;
  bool _hasUnsavedChanges = false;

  // Arama ve Filtreleme
  String searchQuery = "";
  String selectedFilter = "Tümü";
  final List<String> filterOptions = ["Tümü", "Gelenler", "Gelmeyenler"];

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadAllData();
  }

  // 🔥 Varsayılan Avatar (İsmin ilk harfi)
  Widget _buildDefaultAvatar(Users user, double size) {
    String initial = user.first_name.isNotEmpty
        ? user.first_name[0].toUpperCase()
        : "?";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.indigo.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade700,
          ),
        ),
      ),
    );
  }

  // 🔥 Profil Fotoğrafı (Kare)
  Widget _buildProfileImage(String? imageUrl, double size, Users user) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              color: Colors.grey.shade200,
              child: Center(
                child: SizedBox(
                  width: size * 0.3,
                  height: size * 0.3,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar(user, size);
          },
        ),
      );
    } else {
      return _buildDefaultAvatar(user, size);
    }
  }

  // =========================================================================
  // VERİ YÜKLEME
  // =========================================================================
  Future<Map<String, dynamic>> _loadAllData() async {
    try {
      final results = await Future.wait([
        GoogleSheetService.getGroupsCached(),
        GoogleSheetService.getUsersCached(),
        GoogleSheetService.getGroupStudentsCached(),
        GoogleSheetService.getAttendancesCached(),
      ]);

      final groups = results[0] as List<Group>;
      final users = results[1] as List<Users>;
      final relations = results[2] as List<GroupStudent>;

      final rawAttendances = results[3] as List<Attendance>;
      final attendances = rawAttendances
          .map((att) => _cleanAttendanceDate(att))
          .toList();

      return {
        'groups': groups,
        'users': users,
        'relations': relations,
        'attendances': attendances,
      };
    } catch (e) {
      _showSnackBar("Veriler yüklenirken hata oluştu", isError: true);
      return {
        'groups': <Group>[],
        'users': <Users>[],
        'relations': <GroupStudent>[],
        'attendances': <Attendance>[],
      };
    }
  }

  Attendance _cleanAttendanceDate(Attendance att) {
    String cleanDate = att.attendance_date;
    if (cleanDate.contains('T')) {
      cleanDate = cleanDate.split('T')[0];
    }

    String cleanStatus = att.status ?? "";
    if (cleanStatus.isNotEmpty) {
      cleanStatus = cleanStatus.toUpperCase();
      if (cleanStatus == "TRUE" || cleanStatus == "1" || cleanStatus == "YES") {
        cleanStatus = "TRUE";
      } else {
        cleanStatus = "FALSE";
      }
    }

    return Attendance(
      attendances_id: att.attendances_id,
      groups_id: att.groups_id,
      student_id: att.student_id,
      taken_by: att.taken_by,
      attendance_date: cleanDate,
      status: cleanStatus,
      note: att.note,
    );
  }

  // =========================================================================
  // GRUP SEÇİMİ
  // =========================================================================
  void _onGroupSelected(Group? group) {
    if (group == null) return;

    final students = allUsers.where((u) {
      return allRelations.any(
        (rel) =>
            rel.groups_id == group.groups_id &&
            rel.student_id == u.app &&
            rel.is_active.toString().toUpperCase() == "TRUE",
      );
    }).toList();

    setState(() {
      selectedGroup = group;
      studentsInGroup = students;
      searchQuery = "";
      selectedFilter = "Tümü";
      _hasUnsavedChanges = false;
    });

    _loadAttendanceForDate(selectedDate);
  }

  // =========================================================================
  // TARİHE GÖRE YOKLAMA YÜKLE
  // =========================================================================
  void _loadAttendanceForDate(DateTime date) {
    if (selectedGroup == null) return;

    final formattedDate = DateFormat('yyyy-MM-dd').format(date);

    final dateAttendances = allAttendances.where((a) {
      return a.groups_id == selectedGroup!.groups_id &&
          a.attendance_date == formattedDate;
    }).toList();

    final Map<String, bool> tempAttendance = {};
    final Map<String, String> tempNotes = {};
    final Map<String, bool> tempExisting = {};

    for (var student in studentsInGroup) {
      final existing = dateAttendances.firstWhere(
        (a) => a.student_id == student.app,
        orElse: () => Attendance(
          attendances_id: "",
          groups_id: "",
          student_id: "",
          taken_by: "",
          attendance_date: "",
          status: "",
          note: "",
        ),
      );

      bool isPresent = false;
      if (existing.status != null && existing.status.isNotEmpty) {
        final statusStr = existing.status.toString().toUpperCase();
        isPresent =
            (statusStr == "TRUE" || statusStr == "1" || statusStr == "YES");
      }

      tempAttendance[student.app] = isPresent;
      tempNotes[student.app] = existing.note ?? "";
      tempExisting[student.app] = existing.attendances_id.isNotEmpty;
    }

    setState(() {
      attendanceMap = tempAttendance;
      noteMap = tempNotes;
      existingRecordMap = tempExisting;
      _hasUnsavedChanges = false;
    });
  }

  // =========================================================================
  // FİLTRELENMİŞ ÖĞRENCİ LİSTESİ
  // =========================================================================
  List<Users> get _filteredStudents {
    var list = studentsInGroup;

    if (searchQuery.isNotEmpty) {
      list = list.where((student) {
        return student.first_name.toLowerCase().contains(
              searchQuery.toLowerCase(),
            ) ||
            student.last_name.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    if (selectedFilter == "Gelenler") {
      list = list
          .where((student) => attendanceMap[student.app] == true)
          .toList();
    } else if (selectedFilter == "Gelmeyenler") {
      list = list
          .where((student) => attendanceMap[student.app] == false)
          .toList();
    }

    return list;
  }

  // =========================================================================
  // YARDIMCI FONKSİYONLAR
  // =========================================================================
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _hasAnyExistingRecord() {
    return existingRecordMap.values.any((v) => v == true);
  }

  String _getStatusText() {
    if (_isToday(selectedDate)) {
      return "Bugünkü Yoklama";
    } else if (_hasAnyExistingRecord()) {
      return "Geçmiş Yoklama (Düzenlenebilir)";
    } else {
      return "Yeni Yoklama Alınacak";
    }
  }

  Color _getStatusColor() {
    if (_isToday(selectedDate)) {
      return Colors.green;
    } else if (_hasAnyExistingRecord()) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  int get presentCount => attendanceMap.values.where((v) => v == true).length;
  int get absentCount => attendanceMap.values.where((v) => v == false).length;
  int get totalCount => studentsInGroup.length;
  double get presentPercentage =>
      totalCount > 0 ? (presentCount / totalCount) * 100 : 0;

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =========================================================================
  // TARİH SEÇİMİ
  // =========================================================================
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        searchQuery = "";
        selectedFilter = "Tümü";
        _hasUnsavedChanges = false;
      });
      _loadAttendanceForDate(picked);
    }
  }

  // =========================================================================
  // YOKLAMA KAYDETME (ARKA PLANDA)
  // =========================================================================
  Future<void> _saveInBackground() async {
    if (selectedGroup == null) return;

    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    int successCount = 0;

    for (var student in studentsInGroup) {
      final isPresent = attendanceMap[student.app] ?? false;
      final note = noteMap[student.app] ?? "";

      final attendance = Attendance(
        attendances_id: "",
        groups_id: selectedGroup!.groups_id,
        student_id: student.app,
        taken_by: widget.currentUser.app,
        attendance_date: formattedDate,
        status: isPresent ? "TRUE" : "FALSE",
        note: note,
      );

      bool success = await GoogleSheetService.saveAttendance(attendance);
      if (success) successCount++;
    }

    final freshAttendances = await GoogleSheetService.getAttendancesCached(
      forceRefresh: true,
    );
    allAttendances = freshAttendances
        .map((att) => _cleanAttendanceDate(att))
        .toList();

    if (mounted) {
      _showSnackBar("✅ $successCount öğrencinin yoklaması kaydedildi");
    }
  }

  Future<void> _saveAttendance() async {
    if (selectedGroup == null) {
      _showSnackBar("Lütfen bir grup seçin", isError: true);
      return;
    }

    if (!_isToday(selectedDate) && _hasAnyExistingRecord()) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text("Geçmiş Yoklamayı Düzenle"),
            ],
          ),
          content: const Text(
            "Bu tarih için daha önce yoklama alınmış. Yapacağınız değişiklikler mevcut yoklamanın üzerine yazılacak.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text("Güncelle"),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => isSaving = true);
    await _saveInBackground();
    setState(() => isSaving = false);
    _hasUnsavedChanges = false;
  }

  // =========================================================================
  // ÇIKIŞ DİYALOĞU
  // =========================================================================
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges || selectedGroup == null) return true;

    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
            SizedBox(height: 12),
            Text(
              "Kaydedilmemiş Değişiklikler",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Yoklamayı kaydetmeden çıkmak istiyor musunuz?"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatChip(
                    "Toplam",
                    totalCount,
                    Icons.people,
                    Colors.blue,
                  ),
                  _buildStatChip(
                    "Gelen",
                    presentCount,
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildStatChip(
                    "Gelmeyen",
                    absentCount,
                    Icons.cancel,
                    Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Kaydetmeden Çık"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, null);
              _saveInBackground().then((_) {
                if (mounted) Navigator.pop(context);
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text("Kaydet ve Çık"),
          ),
        ],
      ),
    );

    if (shouldSave == null) return false;
    return shouldSave;
  }

  Widget _buildStatChip(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  // =========================================================================
  // NOT DİYALOĞU
  // =========================================================================
  void _showNoteDialog(String studentId, String studentName) {
    final controller = TextEditingController(text: noteMap[studentId] ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("$studentName - Not Ekle"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Devamsızlık notu veya açıklama...",
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
              setState(() {
                noteMap[studentId] = controller.text;
                _hasUnsavedChanges = true;
              });
              Navigator.pop(ctx);
              _showSnackBar("Not kaydedildi");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // UI BİLEŞENLERİ
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (mounted && shouldPop) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            "Yoklama Yönetimi",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _selectDate,
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text("Hata: ${snapshot.error}"),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _dataFuture = _loadAllData();
                        });
                      },
                      child: const Text("Tekrar Dene"),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            allGroups = data['groups'] ?? [];
            allUsers = data['users'] ?? [];
            allRelations = data['relations'] ?? [];
            allAttendances = data['attendances'] ?? [];

            return Column(
              children: [
                _buildStatusBar(),
                _buildStatsCard(),
                _buildGroupSelector(),
                _buildSearchAndFilter(),
                Expanded(
                  child: selectedGroup == null
                      ? _buildEmptyState(
                          Icons.group_off,
                          "Grup Seçilmedi",
                          "Lütfen bir grup seçin",
                        )
                      : studentsInGroup.isEmpty
                      ? _buildEmptyState(
                          Icons.people_outline,
                          "Öğrenci Yok",
                          "Bu grupta aktif öğrenci bulunmuyor",
                        )
                      : _filteredStudents.isEmpty
                      ? _buildEmptyState(
                          Icons.search_off,
                          "Öğrenci Bulunamadı",
                          "Arama kriterlerinize uygun öğrenci yok",
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = _filteredStudents[index];
                            final isPresent =
                                attendanceMap[student.app] ?? false;
                            final hasNote =
                                noteMap[student.app]?.isNotEmpty ?? false;
                            return _buildStudentCard(
                              student,
                              isPresent,
                              hasNote,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: selectedGroup != null && studentsInGroup.isNotEmpty
            ? _buildBottomButton()
            : null,
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.indigo),
          SizedBox(height: 16),
          Text("Veriler yükleniyor..."),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            "Toplam",
            totalCount.toString(),
            Icons.people,
            Colors.white,
          ),
          _buildStatItem(
            "Gelen",
            presentCount.toString(),
            Icons.check_circle,
            Colors.green.shade300,
          ),
          _buildStatItem(
            "Gelmeyen",
            absentCount.toString(),
            Icons.cancel,
            Colors.red.shade300,
          ),
          _buildStatItem(
            "Katılım",
            "${presentPercentage.toStringAsFixed(0)}%",
            Icons.trending_up,
            Colors.orange.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
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

  Widget _buildStatusBar() {
    final dateStr = DateFormat('dd/MM/yyyy').format(selectedDate);
    final statusText = _getStatusText();
    final statusColor = _getStatusColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            _isToday(selectedDate) ? Icons.today : Icons.calendar_month,
            size: 18,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Text(
            "$dateStr • $statusText",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: statusColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
          onChanged: _onGroupSelected,
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
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
                onChanged: (value) => setState(() => searchQuery = value),
                decoration: InputDecoration(
                  hintText: "Öğrenci ara...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: selectedFilter,
              items: filterOptions.map((filter) {
                return DropdownMenuItem(
                  value: filter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          filter == "Tümü"
                              ? Icons.list_alt
                              : filter == "Gelenler"
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 16,
                          color: filter == "Tümü"
                              ? Colors.blue
                              : filter == "Gelenler"
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(filter),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedFilter = value!),
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list, color: Colors.indigo),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 DÜZENLENEN ÖĞRENCİ KARTI (FOTOĞRAF EKLENDİ)
  Widget _buildStudentCard(Users student, bool isPresent, bool hasNote) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: _buildProfileImage(student.profile_photo_url, 50, student),
            title: Text(
              "${student.first_name} ${student.last_name}",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: hasNote
                ? Text(
                    noteMap[student.app] ?? "",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.indigo.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.note_alt,
                    color: hasNote ? Colors.indigo : Colors.grey.shade400,
                    size: 22,
                  ),
                  onPressed: () => _showNoteDialog(
                    student.app,
                    "${student.first_name} ${student.last_name}",
                  ),
                ),
                Switch(
                  value: isPresent,
                  onChanged: (val) {
                    setState(() {
                      attendanceMap[student.app] = val;
                      _hasUnsavedChanges = true;
                    });
                  },
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                ),
              ],
            ),
          ),
          if (hasNote)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note, size: 16, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        noteMap[student.app] ?? "",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: isSaving ? null : _saveAttendance,
          icon: isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save),
          label: Text(
            isSaving ? "Kaydediliyor..." : "Yoklamayı Kaydet",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
