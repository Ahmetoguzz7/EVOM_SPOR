/*
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class YoklamaSayfasi extends StatefulWidget {
  final Group selectedGroup;
  final Users currentUser;

  const YoklamaSayfasi({
    super.key,
    required this.selectedGroup,
    required this.currentUser,
  });

  @override
  State<YoklamaSayfasi> createState() => _YoklamaSayfasiState();
}

class _YoklamaSayfasiState extends State<YoklamaSayfasi> {
  late Future<Map<String, dynamic>> _attendanceDataFuture;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _attendanceDataFuture = _loadAttendanceData();
  }

  Future<Map<String, dynamic>> _loadAttendanceData() async {
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final allUsers = await GoogleSheetService.getUsers();
    final allRelations = await GoogleSheetService.getGroupStudents();
    final allAttendances = await GoogleSheetService.getAttendancesForGroup(
      widget.selectedGroup.groups_id,
    );

    // Grup öğrencilerini bul
    final groupRelations = allRelations
        .where(
          (rel) =>
              rel.groups_id == widget.selectedGroup.groups_id &&
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

    // Bugünün yoklamalarını bul
    final todayAttendances = allAttendances.where((a) {
      final attDate = a.attendance_date.split('T')[0];
      return attDate == formattedDate;
    }).toList();

    // Yoklama listesini oluştur
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
            statusValue == "true" ||
            statusValue.toString().toUpperCase() == "TRUE") {
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

  // 🔥 ARKA PLANDA KAYDETME FONKSİYONU (Sayfa kapandıktan sonra)
  Future<void> _saveInBackground(
    List<Map<String, dynamic>> yoklamaListesi,
  ) async {
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    int savedCount = 0;
    int totalCount = yoklamaListesi.length;

    for (var item in yoklamaListesi) {
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

      bool success = await GoogleSheetService.saveAttendance(attendance);
      if (success) savedCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ $savedCount/$totalCount öğrencinin yoklaması kaydedildi",
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Normal kaydetme (sayfada kalarak)
  Future<void> _saveAttendance(
    List<Map<String, dynamic>> yoklamaListesi,
  ) async {
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    int savedCount = 0;

    for (var item in yoklamaListesi) {
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

      bool success = await GoogleSheetService.saveAttendance(attendance);
      if (success) savedCount++;
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ $savedCount öğrencinin yoklaması kaydedildi"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<bool> _onWillPop(
    List<Map<String, dynamic>> yoklamaListesi,
    bool hasSaved,
  ) async {
    if (!_hasUnsavedChanges || hasSaved) return true;

    final presentCount = yoklamaListesi
        .where((item) => item["is_present"] == true)
        .length;
    final absentCount = yoklamaListesi.length - presentCount;

    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 48,
          ),
        ),
        titlePadding: const EdgeInsets.all(0),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Kaydedilmemiş Yoklama!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Yoklamayı kaydetmeden çıkmak istiyor musunuz?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBigStat("Toplam", yoklamaListesi.length, Colors.blue),
                  _buildBigStat("✅ Gelen", presentCount, Colors.green),
                  _buildBigStat("❌ Gelmeyen", absentCount, Colors.red),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Kaydet ve Çık - ANA BUTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx, null);
                      _saveInBackground(yoklamaListesi);
                    },
                    icon: const Icon(Icons.save, size: 20),
                    label: const Text("YOKLAMAYI KAYDET VE ÇIK"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "İptal",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.red.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Kaydetmeden Çık",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (shouldSave == null) {
      return false;
    }

    return shouldSave;
  }

  Widget _buildBigStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.selectedGroup.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} (Bugün)",
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _attendanceDataFuture,
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
                      setState(() {
                        _attendanceDataFuture = _loadAttendanceData();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Tekrar Dene"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final students = snapshot.data?['students'] as List<Users>? ?? [];
          final yoklamaListesi =
              snapshot.data?['yoklamaListesi'] as List<Map<String, dynamic>>? ??
              [];
          final hasSaved = snapshot.data?['hasSaved'] as bool? ?? false;

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
                  const Text(
                    "Bu grupta henüz öğrenci yok",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Öğrenciler atandıktan sonra yoklama alabilirsiniz",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return _YoklamaWidget(
            yoklamaListesi: yoklamaListesi,
            hasSaved: hasSaved,
            onChanged: (hasChanges) {
              _hasUnsavedChanges = hasChanges;
            },
            onSave: () async {
              await _saveAttendance(yoklamaListesi);
            },
            onWillPop: () => _onWillPop(yoklamaListesi, hasSaved),
          );
        },
      ),
    );
  }
}

// Yoklama Widget'i (StatefulWidget olarak ayrıldı)
class _YoklamaWidget extends StatefulWidget {
  final List<Map<String, dynamic>> yoklamaListesi;
  final bool hasSaved;
  final Function(bool) onChanged;
  final VoidCallback onSave;
  final Future<bool> Function() onWillPop;

  const _YoklamaWidget({
    required this.yoklamaListesi,
    required this.hasSaved,
    required this.onChanged,
    required this.onSave,
    required this.onWillPop,
  });

  @override
  State<_YoklamaWidget> createState() => _YoklamaWidgetState();
}

class _YoklamaWidgetState extends State<_YoklamaWidget> {
  late List<Map<String, dynamic>> _yoklamaListesi;
  late bool _hasUnsavedChanges;
  String _searchQuery = "";
  String _selectedFilter = "Tümü";
  final List<String> _filterOptions = ["Tümü", "Gelenler", "Gelmeyenler"];

  @override
  void initState() {
    super.initState();
    _yoklamaListesi = List.from(widget.yoklamaListesi);
    _hasUnsavedChanges = widget.hasSaved ? false : false;
  }

  void _updateAttendance(int index, bool value) {
    setState(() {
      _yoklamaListesi[index]["is_present"] = value;
      _hasUnsavedChanges = true;
      widget.onChanged(true);
    });
  }

  void _showNoteDialog(int index) {
    final ogrenci = _yoklamaListesi[index]["student"] as Users;
    final controller = TextEditingController(
      text: _yoklamaListesi[index]["note"],
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("${ogrenci.first_name} ${ogrenci.last_name}"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Not ekleyin...",
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
                _yoklamaListesi[index]["note"] = controller.text;
                _hasUnsavedChanges = true;
                widget.onChanged(true);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Not eklendi"),
                  duration: Duration(seconds: 1),
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await widget.onWillPop();
        if (context.mounted && shouldPop) {
          Navigator.pop(context);
        }
      },
      child: Column(
        children: [
          // İstatistik Kartı
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.indigo, Colors.indigoAccent],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  "Toplam",
                  _yoklamaListesi.length,
                  Icons.people,
                  Colors.white,
                ),
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
              ],
            ),
          ),
          // Arama ve Filtre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: const InputDecoration(
                        hintText: "Öğrenci ara...",
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: OutlineInputBorder(borderSide: BorderSide.none),
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
                    value: _selectedFilter,
                    items: _filterOptions.map((filter) {
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
                    onChanged: (value) =>
                        setState(() => _selectedFilter = value!),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.filter_list),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Öğrenci Listesi
          Expanded(
            child: _filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFilter == "Gelenler"
                              ? "Bugün gelen öğrenci yok"
                              : _selectedFilter == "Gelmeyenler"
                              ? "Bugün gelmeyen öğrenci yok"
                              : "Öğrenci bulunamadı",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final item = _filteredList[index];
                      final originalIndex = _yoklamaListesi.indexOf(item);
                      final ogrenci = item["student"] as Users;
                      final isPresent = item["is_present"] == true;
                      final hasNote = item["note"].toString().isNotEmpty;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isPresent
                                ? Colors.green.shade50
                                : Colors.white,
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isPresent
                                      ? Colors.green.shade200
                                      : Colors.red.shade200,
                                  child: Text(
                                    ogrenci.first_name.isNotEmpty
                                        ? ogrenci.first_name[0].toUpperCase()
                                        : "?",
                                    style: TextStyle(
                                      color: isPresent
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  "${ogrenci.first_name} ${ogrenci.last_name}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: hasNote
                                    ? Text(
                                        item["note"],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.indigo.shade600,
                                        ),
                                      )
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.note_alt,
                                        color: hasNote
                                            ? Colors.indigo
                                            : Colors.grey.shade400,
                                      ),
                                      onPressed: () =>
                                          _showNoteDialog(originalIndex),
                                    ),
                                    Switch(
                                      value: isPresent,
                                      onChanged: (val) =>
                                          _updateAttendance(originalIndex, val),
                                      activeColor: Colors.green,
                                      inactiveThumbColor: Colors.red,
                                    ),
                                  ],
                                ),
                              ),
                              if (hasNote && item["note"].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    12,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.edit_note,
                                          size: 18,
                                          color: Colors.indigo,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            item["note"],
                                            style: TextStyle(
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
                        ),
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
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: widget.onSave,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    "Yoklamayı Kaydet",
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}
*/
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final Future<Map<String, dynamic>> attendanceDataFuture =
        _loadAttendanceData();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedGroup.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} (Bugün)",
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
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

// YOKLAMA WIDGET'ı (Stateful devam ediyor - değişen veri var)
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

  // Varsayılan Avatar (İsmin ilk harfi)
  Widget _buildDefaultAvatar(Users ogrenci) {
    String initial = ogrenci.first_name.isNotEmpty
        ? ogrenci.first_name[0].toUpperCase()
        : "?";

    return Container(
      width: 50,
      height: 50,
      color: Colors.indigo.shade100,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // İstatistik Kartı
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.indigo, Colors.indigoAccent],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("Toplam", _yoklamaListesi.length, Icons.people),
              _buildStatItem(
                "Gelen",
                _yoklamaListesi
                    .where((item) => item["is_present"] == true)
                    .length,
                Icons.check_circle,
              ),
              _buildStatItem(
                "Gelmeyen",
                _yoklamaListesi
                    .where((item) => item["is_present"] == false)
                    .length,
                Icons.cancel,
              ),
            ],
          ),
        ),
        // Arama ve Filtre
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: const InputDecoration(
                    hintText: "Öğrenci ara...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedFilter,
                items: _filterOptions.map((filter) {
                  return DropdownMenuItem(value: filter, child: Text(filter));
                }).toList(),
                onChanged: (value) => setState(() => _selectedFilter = value!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Öğrenci Listesi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredList.length,
            itemBuilder: (context, index) {
              final item = _filteredList[index];
              final originalIndex = _yoklamaListesi.indexOf(item);
              final ogrenci = item["student"] as Users;
              final isPresent = item["is_present"] == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  // KARE FOTOĞRAF
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey.shade200,
                      child: ogrenci.profile_photo_url.isNotEmpty
                          ? Image.network(
                              ogrenci.profile_photo_url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar(ogrenci);
                              },
                            )
                          : _buildDefaultAvatar(ogrenci),
                    ),
                  ),
                  title: Text(
                    "${ogrenci.first_name} ${ogrenci.last_name}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    ogrenci.email,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  trailing: Switch(
                    value: isPresent,
                    onChanged: (val) => _updateAttendance(originalIndex, val),
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                  ),
                ),
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
                  blurRadius: 10,
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveAttendance,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? "Kaydediliyor..." : "Yoklamayı Kaydet"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem(String title, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}
