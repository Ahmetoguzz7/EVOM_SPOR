/*
  manager_payment_dekont.dart - Ödeme Dekontu Ekranı
  - Öğrenciye ait ödeme bilgilerini gösterir
  - Yeni ödeme ekleme ve mevcut ödemeleri görüntüleme imkanı sağlar
  - Aylık ücret, ödenen tutar ve kalan borç gibi bilgileri hesaplar
  - Ödeme geçmişini detaylı şekilde listeler
  - Kullanıcı dostu arayüz ile hızlı işlem yapma imkanı sunar
  */
/*
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';

class StudentAssignmentScreen extends StatefulWidget {
  final Group group;
  const StudentAssignmentScreen({required this.group});

  @override
  _StudentAssignmentScreenState createState() =>
      _StudentAssignmentScreenState();
}

class _StudentAssignmentScreenState extends State<StudentAssignmentScreen> {
  List<Users> allStudents = [];
  List<Users> filteredStudents = [];
  List<GroupStudent> allRelations = [];
  bool isLoading = true;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return; // ✅ EKLENDI - mounted kontrolü

    setState(() => isLoading = true);

    try {
      final students = await GoogleSheetService.getStudentsOnly();
      final relations = await GoogleSheetService.getGroupStudents();

      if (!mounted) return; // ✅ EKLENDI - mounted kontrolü

      setState(() {
        allStudents = students;
        allRelations = relations;
        _filterStudents("");
        isLoading = false;
      });
    } catch (e) {
      // print("Yükleme hatası: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _filterStudents(String query) {
    if (!mounted) return; // ✅ EKLENDI - mounted kontrolü

    setState(() {
      searchQuery = query;
      filteredStudents = allStudents.where((student) {
        final fullName = "${student.first_name} ${student.last_name}"
            .toLowerCase();
        final alreadyInGroup = allRelations.any(
          (rel) =>
              rel.groups_id == widget.group.groups_id &&
              rel.student_id == student.app &&
              rel.is_active == "TRUE",
        );
        return fullName.contains(query.toLowerCase()) && !alreadyInGroup;
      }).toList();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${student.first_name} eklendi!")));
      _loadData(); // Listeyi güncelle
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("${widget.group.name} | Atama"),
        backgroundColor: Colors.indigo,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboard(currentUserRole: 'admin'),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _actionChip("Tümü", Icons.all_inclusive, Colors.blue),
                      _actionChip(
                        "Yeni Kayıtlar",
                        Icons.fiber_new,
                        Colors.green,
                      ),
                      _actionChip("Borçlular", Icons.warning, Colors.red),
                      _actionChip("Lisanslılar", Icons.verified, Colors.orange),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: filteredStudents.isEmpty
                      ? const Center(child: Text("Öğrenci bulunamadı."))
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
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.indigo.shade50,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.indigo,
                                  ),
                                ),
                                title: Text("${s.first_name} ${s.last_name}"),
                                subtitle: Text(s.phone),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: Colors.green,
                                    size: 30,
                                  ),
                                  onPressed: () => _assignStudent(s),
                                ),
                              ),
                            );
                          },
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
        onPressed: () {},
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
    );
  }
}
*/
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';

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

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    try {
      final students = await GoogleSheetService.getStudentsOnlyCached();
      final relations = await GoogleSheetService.getGroupStudentsCached();

      return {'students': students, 'relations': relations};
    } catch (e) {
      print("Yükleme hatası: $e");
      return {'students': <Users>[], 'relations': <GroupStudent>[]};
    }
  }

  void _filterStudents(String query) {
    if (!mounted) return;

    setState(() {
      searchQuery = query;
      filteredStudents = allStudents.where((student) {
        final fullName = "${student.first_name} ${student.last_name}"
            .toLowerCase();
        final alreadyInGroup = allRelations.any(
          (rel) =>
              rel.groups_id == widget.group.groups_id &&
              rel.student_id == student.app &&
              rel.is_active == "TRUE",
        );
        return fullName.contains(query.toLowerCase()) && !alreadyInGroup;
      }).toList();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${student.first_name} eklendi!")));
      setState(() {
        _dataFuture = _loadData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("${widget.group.name} | Atama"),
        backgroundColor: Colors.indigo,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Ana sayfayı yeniden başlatmadan geri dön
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
                        _dataFuture = _loadData();
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

          if (filteredStudents.isEmpty && searchQuery.isEmpty) {
            _filterStudents("");
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
                    ? const Center(child: Text("Öğrenci bulunamadı."))
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
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo.shade50,
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.indigo,
                                ),
                              ),
                              title: Text("${s.first_name} ${s.last_name}"),
                              subtitle: Text(s.phone),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.green,
                                  size: 30,
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
        onPressed: () {},
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
    );
  }
}
