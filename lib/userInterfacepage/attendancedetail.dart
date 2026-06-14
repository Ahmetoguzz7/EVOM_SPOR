import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class YoklamaSayfasi extends StatelessWidget {
  final Group selectedGroup;
  final Users currentUser;

  const YoklamaSayfasi({
    super.key,
    required this.selectedGroup,
    required this.currentUser,
  });

  String _getTodayDateTurkish() {
    final now = DateTime.now();
    final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
    return formatter.format(now);
  }

  @override
  Widget build(BuildContext context) {
    final Future<Map<String, dynamic>> attendanceDataFuture =
        _loadAttendanceData();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedGroup.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(_getTodayDateTurkish(), style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: attendanceDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text("Yoklama verileri yükleniyor..."),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text("Veriler yüklenirken hata oluştu"),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      GoogleSheetService.invalidateCache('users');
                      GoogleSheetService.invalidateCache('group_students');
                      GoogleSheetService.invalidateCache('attendances');
                      (context as Element).reassemble();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            );
          }

          final yoklamaListesi =
              snapshot.data?['yoklamaListesi'] as List<Map<String, dynamic>>? ??
              [];
          final students = snapshot.data?['students'] as List<Users>? ?? [];

          if (students.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text("Bu grupta henüz öğrenci yok"),
                ],
              ),
            );
          }

          return _YoklamaWidget(
            yoklamaListesi: yoklamaListesi,
            selectedGroup: selectedGroup,
            currentUser: currentUser,
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _loadAttendanceData() async {
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final allUsers = await GoogleSheetService.getUsersCached();
    final allRelations = await GoogleSheetService.getGroupStudentsCached();
    final allAttendances = await GoogleSheetService.getAttendancesCached();

    final groupRelations = allRelations
        .where(
          (rel) =>
              rel.groups_id == selectedGroup.groups_id &&
              rel.is_active.toUpperCase() == "TRUE",
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

    final todayAttendances = allAttendances.where((a) {
      final attDate = a.attendance_date.split('T')[0];
      return attDate == formattedDate;
    }).toList();

    final List<Map<String, dynamic>> yoklamaListesi = [];
    for (var ogrenci in students) {
      Attendance? foundAttendance;
      for (var att in todayAttendances) {
        if (att.student_id == ogrenci.app) {
          foundAttendance = att;
          break;
        }
      }

      bool isPresent = false;
      if (foundAttendance != null) {
        final statusValue = foundAttendance.status;
        if (statusValue == true ||
            statusValue == "TRUE" ||
            statusValue == "true") {
          isPresent = true;
        }
      }

      yoklamaListesi.add({
        "student": ogrenci,
        "is_present": isPresent,
        "note": foundAttendance?.note ?? "",
        "has_attendance": foundAttendance != null,
      });
    }

    return {
      'students': students,
      'yoklamaListesi': yoklamaListesi,
      'hasSaved': todayAttendances.isNotEmpty,
    };
  }
}

// 🔥 YENİ YOKLAMA WIDGET - TakeAttendanceScreen tasarımı ile
class _YoklamaWidget extends StatefulWidget {
  final List<Map<String, dynamic>> yoklamaListesi;
  final Group selectedGroup;
  final Users currentUser;

  const _YoklamaWidget({
    required this.yoklamaListesi,
    required this.selectedGroup,
    required this.currentUser,
  });

  @override
  State<_YoklamaWidget> createState() => _YoklamaWidgetState();
}

class _YoklamaWidgetState extends State<_YoklamaWidget> {
  late List<Map<String, dynamic>> _yoklamaListesi;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String _searchQuery = "";
  String _selectedFilter = "Tümü";
  final List<String> _filterOptions = ["Tümü", "Gelenler", "Gelmeyenler"];

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _accent = Color(0xFF0EA5E9);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _yoklamaListesi = List.from(widget.yoklamaListesi);
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

  Widget _buildDefaultAvatar(Users student, double size) {
    String initial = student.first_name.isNotEmpty
        ? student.first_name[0].toUpperCase()
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
    Users student,
  ) {
    final String heroTag = 'profile_photo_${student.profile_photo_url}_$size';
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
              _buildDefaultAvatar(student, size),
        ),
      );
    } else {
      imageWidget = _buildDefaultAvatar(student, size);
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

  void _showStudentDetailDialog(BuildContext context, Users student) {
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

  void _showNoteDialog(int index, Users student) {
    final controller = TextEditingController(
      text: _yoklamaListesi[index]["note"] ?? "",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "${student.first_name} ${student.last_name}",
          style: const TextStyle(fontSize: 16),
        ),
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

  Future<void> _saveAttendance() async {
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    int savedCount = 0;

    for (var item in _yoklamaListesi) {
      final Users ogrenci = item["student"];
      final isPresent = item["is_present"] == true;
      final note = item["note"] ?? "";

      final attendance = Attendance(
        attendances_id: "",
        groups_id: widget.selectedGroup.groups_id,
        student_id: ogrenci.app,
        taken_by: widget.currentUser.app,
        attendance_date: formattedDate,
        status: isPresent ? "TRUE" : "FALSE",
        note: note,
      );

      final success = await GoogleSheetService.saveAttendance(attendance);
      if (success) savedCount++;
    }

    setState(() => _isSaving = false);

    if (mounted) {
      GoogleSheetService.invalidateCache('attendances');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ $savedCount öğrencinin yoklaması kaydedildi"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
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
        // İstatistik Kartı (TakeAttendanceScreen'deki gibi)
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
              _buildStatItem("Toplam", totalCount, Icons.people, Colors.white),
              _buildStatItem(
                "Gelen",
                presentCount,
                Icons.check_circle,
                Colors.green.shade300,
              ),
              _buildStatItem(
                "Gelmeyen",
                absentCount,
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
        ),

        // Arama ve Filtre
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    onChanged: (value) => setState(() => _searchQuery = value),
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
                    value: _selectedFilter,
                    icon: const Icon(Icons.filter_list, size: 16),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
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

        const SizedBox(height: 4),

        // Öğrenci Listesi (TakeAttendanceScreen'deki gibi kartlar)
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

                    return _buildStudentCard(
                      ogrenci,
                      isPresent,
                      hasNote,
                      originalIndex,
                    );
                  },
                ),
        ),

        // Kaydet Butonu
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
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAttendance,
                icon: _isSaving
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

  Widget _buildStatItem(
    String title,
    dynamic value,
    IconData icon,
    Color color,
  ) {
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

  // 🔥 ÖĞRENCİ KARTI - TakeAttendanceScreen'deki gibi (telefon, doğum günü, arama butonu)
  Widget _buildStudentCard(
    Users student,
    bool isPresent,
    bool hasNote,
    int index,
  ) {
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
            // Fotoğraf
            GestureDetector(
              onTap: () => _showStudentDetailDialog(context, student),
              child: _buildProfileImage(
                context,
                student.profile_photo_url,
                58,
                student,
              ),
            ),
            const SizedBox(width: 12),

            // Bilgiler
            Expanded(
              child: GestureDetector(
                onTap: () => _showStudentDetailDialog(context, student),
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
                    ],
                  ],
                ),
              ),
            ),

            // Aksiyonlar
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Yoklama switch
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: isPresent,
                    onChanged: (val) => _updateAttendance(index, val),
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
                    // Arama butonu
                    if (student.phone.isNotEmpty)
                      _buildActionIcon(Icons.call, Colors.green, () async {
                        final url = Uri.parse("tel:${student.phone}");
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Arama yapılamıyor"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }),
                    const SizedBox(width: 4),
                    // Not butonu
                    _buildActionIcon(
                      Icons.note_alt_outlined,
                      hasNote ? Colors.indigo : Colors.grey.shade400,
                      () => _showNoteDialog(index, student),
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
}
