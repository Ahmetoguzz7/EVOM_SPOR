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

  // 🔥 YENİ: İlk yükleme kontrolü
  bool _isInitialLoad = true;

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

      return {'students': students, 'relations': relations};
    } catch (e) {
      print("❌ Yükleme hatası: $e");
      return {'students': <Users>[], 'relations': <GroupStudent>[]};
    }
  }

  // 🔥 DÜZELTİLMİŞ: Filtreleme metodu (setState kontrolü ile)
  void _filterStudents(String query) {
    // Eğer widget build edilirken çağrıldıysa, addPostFrameCallback ile ertele
    if (!mounted) return;

    // 🔥 KRİTİK: Eğer şu anda build aşamasındaysak, setState'i ertele
    if (SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks ||
        SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.postFrameCallbacks) {
      // Build aşamasındaysak, bir sonraki frame'de çalıştır
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            searchQuery = query;
            _applyFilter();
          });
        }
      });
    } else {
      // Normal durumda direkt setState
      setState(() {
        searchQuery = query;
        _applyFilter();
      });
    }
  }

  // 🔥 YENİ: Filtreleme mantığını ayrı metoda al
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

  // 🔥 YENİ: Veriler yüklendikten sonra filtrelemeyi başlat
  void _onDataLoaded() {
    if (!mounted) return;
    setState(() {
      _applyFilter();
    });
  }

  Future<void> _assignStudent(Users student) async {
    final newRelation = {
      "groups_id": widget.group.groups_id,
      "student_id": student.app,
      "enrolled_at": DateTime.now().toIso8601String(),
      "is_active": "TRUE",
    };

    bool ok = await GoogleSheetService.insertData(
      "group_students",
      newRelation,
    );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${student.first_name} ${student.last_name} eklendi!"),
        ),
      );
      // 🔥 Verileri yeniden yükle
      setState(() {
        _dataFuture = _loadDataParallel();
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Ekleme başarısız oldu!",
            style: TextStyle(color: Colors.red),
          ),
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
            return const Center(child: CircularProgressIndicator());
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

          // 🔥 DÜZELTİLMİŞ: İlk yüklemede filtrelemeyi bir sonraki frame'de yap
          if (_isInitialLoad) {
            _isInitialLoad = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _applyFilter();
            });
          }

          return Column(
            children: [
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
              // 🔥 Filtre butonları (şimdilik pasif, istersen aktifleştir)
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _actionChip("Tümü", Icons.all_inclusive, Colors.blue),
                    _actionChip("Yeni Kayıtlar", Icons.fiber_new, Colors.green),
                  ],
                ),
              ),
              const SizedBox(height: 10),
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
                                  ? "Gruba eklenebilecek öğrenci bulunamadı."
                                  : "Aranan kriterde öğrenci yok",
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final s = filteredStudents[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo.shade50,
                                child: Text(
                                  s.first_name.isNotEmpty
                                      ? s.first_name[0].toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                "${s.first_name} ${s.last_name}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(s.phone),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.green,
                                  size: 32,
                                ),
                                onPressed: () => _assignStudent(s),
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

  Widget _actionChip(String label, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(label),
        onPressed: () {
          // 🔥 Filtreleme butonları için (ileride eklenebilir)
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
