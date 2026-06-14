import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'package:flutter/scheduler.dart';

class StudentAssignmentScreen extends StatefulWidget {
  final Group group;
  const StudentAssignmentScreen({required this.group});

  @override
  _StudentAssignmentScreenState createState() =>
      _StudentAssignmentScreenState();
}

class _StudentAssignmentScreenState extends State<StudentAssignmentScreen> {
  late Future<Map<String, dynamic>> _dataFuture;
  List<Users> allStudents = [];
  List<Users> filteredStudents = [];
  List<GroupStudent> allRelations = [];
  String searchQuery = "";

  // 🔥 YENİ: Loading state'leri
  bool _isInitialLoad = true;
  Set<String> _assigningStudents = {}; // Hangi öğrenci ekleniyor takip et

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadDataParallel();
  }

  // 🚀 PARALEL VERİ ÇEKEN METOD
  Future<Map<String, dynamic>> _loadDataParallel() async {
    final stopwatch = Stopwatch()..start();

    try {
      final results = await Future.wait([
        GoogleSheetService.getStudentsOnlyCached(),
        GoogleSheetService.getGroupStudentsCached(),
      ]);

      final students = results[0] as List<Users>;
      final relations = results[1] as List<GroupStudent>;

      stopwatch.stop();
      print(
        "⏱️ StudentAssignmentScreen verileri PARALEL olarak ${stopwatch.elapsedMilliseconds}ms'de yüklendi",
      );

      return {'students': students, 'relations': relations};
    } catch (e) {
      print("❌ Yükleme hatası: $e");
      return {'students': <Users>[], 'relations': <GroupStudent>[]};
    }
  }

  void _filterStudents(String query) {
    if (!mounted) return;

    if (SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks ||
        SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.postFrameCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            searchQuery = query;
            _applyFilter();
          });
        }
      });
    } else {
      setState(() {
        searchQuery = query;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    filteredStudents = allStudents.where((student) {
      final fullName = "${student.first_name} ${student.last_name}"
          .toLowerCase();
      final alreadyInGroup = allRelations.any(
        (rel) =>
            rel.groups_id == widget.group.groups_id &&
            rel.student_id == student.app &&
            rel.is_active.toString().toUpperCase() == "TRUE",
      );
      return fullName.contains(searchQuery.toLowerCase()) && !alreadyInGroup;
    }).toList();
  }

  void _onDataLoaded() {
    if (!mounted) return;
    setState(() {
      _applyFilter();
    });
  }

  // 🔥 YENİ: Loading göstererek ekleme yap
  Future<void> _assignStudent(Users student) async {
    // Eğer bu öğrenci zaten ekleniyorsa, tekrar tıklanmasın
    if (_assigningStudents.contains(student.app)) return;

    setState(() {
      _assigningStudents.add(student.app);
    });

    bool ok = await GoogleSheetService.assignStudentToGroup(
      student.app,
      widget.group.groups_id,
    );

    setState(() {
      _assigningStudents.remove(student.app);
    });

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ ${student.first_name} ${student.last_name} eklendi!",
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      // Verileri yeniden yükle
      setState(() {
        _dataFuture = _loadDataParallel();
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Ekleme başarısız oldu!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("${widget.group.name} | Öğrenci Atama"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text("Öğrenciler yükleniyor..."),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text("Veriler yüklenirken hata oluştu"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _dataFuture = _loadDataParallel();
                      });
                    },
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          allStudents = data['students'] ?? [];
          allRelations = data['relations'] ?? [];

          if (_isInitialLoad) {
            _isInitialLoad = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _applyFilter();
            });
          }

          return Column(
            children: [
              // Arama çubuğu
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  onChanged: _filterStudents,
                  decoration: InputDecoration(
                    hintText: "Öğrenci ara (İsim/Soyisim)...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // İstatistik kartı (kaç öğrenci var)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.people_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Eklenebilecek Öğrenciler",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              "${filteredStudents.length} öğrenci",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (searchQuery.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Aranıyor: $searchQuery",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Öğrenci listesi
              Expanded(
                child: filteredStudents.isEmpty
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
                              searchQuery.isEmpty
                                  ? "Gruba eklenebilecek öğrenci bulunamadı"
                                  : "Aranan kriterde öğrenci yok",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (searchQuery.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => _filterStudents(""),
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text("Aramayı Temizle"),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final s = filteredStudents[index];
                          final isAssigning = _assigningStudents.contains(
                            s.app,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.indigo.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showStudentDetailDialog(s),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Profil fotoğrafı / Avatar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          width: 55,
                                          height: 55,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.indigo.shade300,
                                                Colors.indigo.shade600,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: s.profile_photo_url.isNotEmpty
                                              ? Image.network(
                                                  s.profile_photo_url,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return Center(
                                                          child: Text(
                                                            s
                                                                    .first_name
                                                                    .isNotEmpty
                                                                ? s.first_name[0]
                                                                      .toUpperCase()
                                                                : "?",
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 24,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                )
                                              : Center(
                                                  child: Text(
                                                    s.first_name.isNotEmpty
                                                        ? s.first_name[0]
                                                              .toUpperCase()
                                                        : "?",
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Öğrenci bilgileri
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${s.first_name} ${s.last_name}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.phone_outlined,
                                                  size: 12,
                                                  color: Colors.green.shade500,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  s.phone.isNotEmpty
                                                      ? s.phone
                                                      : "Telefon yok",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: s.phone.isNotEmpty
                                                        ? Colors.grey.shade700
                                                        : Colors.grey.shade400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.email_outlined,
                                                  size: 12,
                                                  color: Colors.grey.shade500,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    s.email.isNotEmpty
                                                        ? s.email
                                                        : "E-posta yok",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // 🔥 EKLE BUTONU - Loading gösteriyor!
                                      if (isAssigning)
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.indigo,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        GestureDetector(
                                          onTap: () => _assignStudent(s),
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.green.shade200,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.person_add_alt_rounded,
                                              color: Colors.green,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🔥 YENİ: Öğrenci detay dialog'u
  void _showStudentDetailDialog(Users student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
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
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.indigo.shade300,
                          Colors.indigo.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: student.profile_photo_url.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Image.network(
                              student.profile_photo_url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    student.first_name.isNotEmpty
                                        ? student.first_name[0].toUpperCase()
                                        : "?",
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Text(
                              student.first_name.isNotEmpty
                                  ? student.first_name[0].toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "${student.first_name} ${student.last_name}",
                  style: const TextStyle(
                    fontSize: 22,
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
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildDetailRow(
                        Icons.email,
                        Colors.blue,
                        "E-posta",
                        student.email.isNotEmpty
                            ? student.email
                            : "Belirtilmemiş",
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildDetailRow(
                        Icons.cake,
                        Colors.orange,
                        "Doğum Tarihi",
                        student.b_date.isNotEmpty
                            ? student.b_date
                            : "Belirtilmemiş",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text(
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
    String value,
  ) {
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip(String label, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(label),
        onPressed: () {
          if (label == "Tümü") {
            _filterStudents("");
          }
        },
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
    );
  }
}
