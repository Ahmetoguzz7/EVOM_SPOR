/*
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
*/
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  // =========================================================================
  // 🔥 TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

  // Bugünün tarihini Türkçe formatla göster (örn: 15 Ocak 2025)
  String _getTodayDateTurkish() {
    final now = DateTime.now();
    final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
    return formatter.format(now);
  }

  // Bugünün kısa tarih formatı (örn: 15/01/2025)
  String _getTodayDateShortTurkish() {
    final now = DateTime.now();
    final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
    return formatter.format(now);
  }

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
              "${_getTodayDateTurkish()} (Bugün)",
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
