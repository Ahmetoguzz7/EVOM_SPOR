import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final Users currentUser;
  const TakeAttendanceScreen({super.key, required this.currentUser});
  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  final AppRepository _repo = AppRepository();

  List<Group> allGroups = [];
  List<Users> allUsers = [];
  List<GroupStudent> allRelations = [];
  List<Attendance> allAttendances = [];

  Group? selectedGroup;
  List<Users> studentsInGroup = [];

  Map<String, bool> attendanceMap = {};
  Map<String, String> noteMap = {};
  Map<String, bool> existingRecordMap = {};

  DateTime selectedDate = DateTime.now();
  bool isSaving = false;
  bool _hasUnsavedChanges = false;

  String searchQuery = "";
  String selectedFilter = "Tümü";
  final List<String> filterOptions = ["Tümü", "Gelenler", "Gelmeyenler"];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!_repo.isLoaded) {
      await _repo.loadAllData();
    }
    setState(() {
      allGroups = _repo.allGroups;
      allUsers = _repo.allUsers;
      allRelations = _repo.allGroupStudents;
      allAttendances = _repo.allAttendances;
    });
  }

  String _formatDateTurkish(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
    return formatter.format(date);
  }

  String _formatDateFromString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
      return formatter.format(date);
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

  Widget _buildDefaultAvatar(Users user, double size) {
    String initial = user.first_name.isNotEmpty
        ? user.first_name[0].toUpperCase()
        : "?";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade300, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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

  Widget _buildProfileImage(
    BuildContext context,
    String? imageUrl,
    double size,
    Users user,
  ) {
    final String heroTag = 'profile_photo_${user.profile_photo_url}_$size';
    Widget imageWidget;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildDefaultAvatar(user, size),
        ),
      );
    } else {
      imageWidget = _buildDefaultAvatar(user, size);
    }
    return GestureDetector(
      onTap: () {
        if (imageUrl != null && imageUrl.isNotEmpty) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Hero(
                  tag: heroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(imageUrl, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          );
        }
      },
      child: Hero(tag: heroTag, child: imageWidget),
    );
  }

  void _showStudentDetailDialog(Users student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: _buildProfileImage(
                    ctx,
                    student.profile_photo_url,
                    100,
                    student,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "${student.first_name} ${student.last_name}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        Icons.phone,
                        Colors.green,
                        "Telefon",
                        student.phone.isNotEmpty
                            ? student.phone
                            : "Belirtilmemiş",
                        onCall: student.phone.isNotEmpty
                            ? () async {
                                final url = Uri.parse("tel:${student.phone}");
                                if (await canLaunchUrl(url))
                                  await launchUrl(url);
                              }
                            : null,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildDetailRow(
                        Icons.cake,
                        Colors.orange,
                        "Doğum Tarihi",
                        _formatDateFromString(student.b_date),
                        subtitle: _calculateAge(student.b_date) > 0
                            ? "${_calculateAge(student.b_date)} yaşında"
                            : null,
                      ),
                      if (student.mother_name.isNotEmpty ||
                          student.father_name.isNotEmpty) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildDetailRow(
                          Icons.family_restroom,
                          Colors.purple,
                          "Aile",
                          [
                            if (student.mother_name.isNotEmpty)
                              "Anne: ${student.mother_name}",
                            if (student.father_name.isNotEmpty)
                              "Baba: ${student.father_name}",
                          ].join("\n"),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Kapat",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    Color color,
    String label,
    String value, {
    String? subtitle,
    VoidCallback? onCall,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
          if (onCall != null)
            GestureDetector(
              onTap: onCall,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.call, color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  String _getRoleText(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return 'Öğrenci';
      case 'coach':
        return 'Antrenör';
      case 'parent':
        return 'Veli';
      case 'admin':
        return 'Admin';
      default:
        return role;
    }
  }

  Future<void> _callStudent(Users student) async {
    final phone = student.phone;
    if (phone.isNotEmpty) {
      final url = Uri.parse("tel:$phone");
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _showSnackBar("Arama yapılamıyor", isError: true);
      }
    } else {
      _showSnackBar("Telefon numarası bulunamadı", isError: true);
    }
  }

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

  void _loadAttendanceForDate(DateTime date) {
    if (selectedGroup == null) return;
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final dateAttendances = allAttendances
        .where(
          (a) =>
              a.groups_id == selectedGroup!.groups_id &&
              a.attendance_date == formattedDate,
        )
        .toList();
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
      bool isPresent = existing.status.toString().toUpperCase() == "TRUE";
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

  List<Users> get _filteredStudents {
    var list = studentsInGroup;
    if (searchQuery.isNotEmpty) {
      list = list
          .where(
            (student) =>
                student.first_name.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                student.last_name.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ),
          )
          .toList();
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _hasAnyExistingRecord() =>
      existingRecordMap.values.any((v) => v == true);

  String _getStatusText() {
    if (_isToday(selectedDate)) return "Bugünkü Yoklama";
    if (_hasAnyExistingRecord()) return "Geçmiş Yoklama (Düzenlenebilir)";
    return "Yeni Yoklama Alınacak";
  }

  Color _getStatusColor() {
    if (_isToday(selectedDate)) return Colors.green;
    if (_hasAnyExistingRecord()) return Colors.orange;
    return Colors.grey;
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
      setState(() {
        selectedDate = picked;
        searchQuery = "";
        selectedFilter = "Tümü";
        _hasUnsavedChanges = false;
      });
      _loadAttendanceForDate(picked);
    }
  }

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
    await _repo.refreshTable('attendances');
    allAttendances = _repo.allAttendances;
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
            "Bu tarih için daha önce yoklama alınmış. Değişiklikler mevcut yoklamanın üzerine yazılacak.",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Yoklama Paneli",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: !_repo.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
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
            ),
      bottomNavigationBar: selectedGroup != null && studentsInGroup.isNotEmpty
          ? _buildBottomButton()
          : null,
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        Icon(icon, color: color, size: 20),
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
    final dateStr = _formatDateTurkish(selectedDate);
    final statusText = _getStatusText();
    final statusColor = _getStatusColor();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            _isToday(selectedDate) ? Icons.today : Icons.calendar_month,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 6),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) => setState(() => searchQuery = value),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Öğrenci ara...",
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.grey,
                    size: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedFilter,
                icon: const Icon(Icons.filter_list, size: 16),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                items: filterOptions
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (value) => setState(() => selectedFilter = value!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 🔥 YENİ ÖĞRENCİ KARTI — Kompakt, bilgi odaklı
  // =========================================================================
  Widget _buildStudentCard(Users student, bool isPresent, bool hasNote) {
    final age = _calculateAge(student.b_date);
    final birthStr = _formatDateFromString(student.b_date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPresent
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 🔥 Fotoğraf
            GestureDetector(
              onTap: () => _showStudentDetailDialog(student),
              child: _buildProfileImage(
                context,
                student.profile_photo_url,
                58,
                student,
              ),
            ),
            const SizedBox(width: 12),

            // 🔥 Bilgiler
            Expanded(
              child: GestureDetector(
                onTap: () => _showStudentDetailDialog(student),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // İsim
                    Text(
                      "${student.first_name} ${student.last_name}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Doğum tarihi + yaş
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
                            age > 0 ? "$birthStr ($age yaş)" : birthStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 3),

                    // Telefon
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 12,
                          color: Colors.green.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          student.phone.isNotEmpty
                              ? student.phone
                              : "Telefon yok",
                          style: TextStyle(
                            fontSize: 11,
                            color: student.phone.isNotEmpty
                                ? Colors.grey.shade700
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),

                    // Not (varsa)
                    if (hasNote) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.note_outlined,
                            size: 12,
                            color: Colors.indigo.shade400,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              noteMap[student.app] ?? "",
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
                    ],
                  ],
                ),
              ),
            ),

            // 🔥 Aksiyonlar
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Yoklama switch
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: isPresent,
                    onChanged: (val) {
                      setState(() {
                        attendanceMap[student.app] = val;
                        _hasUnsavedChanges = true;
                      });
                    },
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red.shade300,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 4),
                // Alt ikonlar
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Arama
                    if (student.phone.isNotEmpty)
                      _buildActionIcon(
                        Icons.call,
                        Colors.green,
                        () => _callStudent(student),
                      ),
                    const SizedBox(width: 4),
                    // Not
                    _buildActionIcon(
                      Icons.note_alt_outlined,
                      hasNote ? Colors.indigo : Colors.grey.shade400,
                      () => _showNoteDialog(
                        student.app,
                        "${student.first_name} ${student.last_name}",
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

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  void _showNoteDialog(String studentId, String studentName) {
    final controller = TextEditingController(text: noteMap[studentId] ?? "");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("$studentName", style: const TextStyle(fontSize: 16)),
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
        height: 50,
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save, size: 20),
          label: Text(
            isSaving ? "Kaydediliyor..." : "Yoklamayı Kaydet",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
