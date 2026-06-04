import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  const GroupDetailScreen({Key? key, required this.group}) : super(key: key);

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late Future<Map<String, dynamic>> _groupDataFuture;

  Users? coachUser;
  List<Users> enrolledStudents = [];
  List<Coach> allCoaches = [];
  List<Users> allUsers = [];
  List<Branches> allBranchesList = [];
  List<Sports> allSportsList = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _groupDataFuture = _loadGroupChain();
  }

  Future<Map<String, dynamic>> _loadGroupChain() async {
    try {
      final results = await Future.wait([
        GoogleSheetService.getUsersCached(),
        GoogleSheetService.getCoachesCached(),
        GoogleSheetService.getGroupStudentsByGroupId(widget.group.groups_id),
        GoogleSheetService.getBranchesCached(),
        GoogleSheetService.getSportsCached(),
      ]);

      final allUsersTemp = results[0] as List<Users>;
      final allCoachesTemp = results[1] as List<Coach>;
      final allGroupRelations = results[2] as List<GroupStudent>;
      final allBranchesListTemp = results[3] as List<Branches>;
      final allSportsListTemp = results[4] as List<Sports>;

      // Antrenör eşleştirme
      Users? coachUserTemp;
      if (widget.group.coach_id.isNotEmpty) {
        try {
          final matchedCoach = allCoachesTemp.firstWhere(
            (c) => c.coach_id == widget.group.coach_id,
          );
          final matchedUser = allUsersTemp.firstWhere(
            (u) => u.app == matchedCoach.user_id,
          );
          coachUserTemp = matchedUser;
        } catch (e) {
          coachUserTemp = null;
        }
      }

      // Öğrenci kadrosu eşleştirme
      final studentIdsInGroup = allGroupRelations
          .where((rel) => rel.is_active == "TRUE")
          .map((rel) => rel.student_id)
          .toList();

      final enrolledStudentsTemp = allUsersTemp
          .where((u) => studentIdsInGroup.contains(u.app))
          .toList();

      return {
        'coachUser': coachUserTemp,
        'enrolledStudents': enrolledStudentsTemp,
        'allCoaches': allCoachesTemp,
        'allUsers': allUsersTemp,
        'allBranchesList': allBranchesListTemp,
        'allSportsList': allSportsListTemp,
      };
    } catch (e) {
      print("❌ Veri yükleme hatası: $e");
      throw Exception("Veriler yüklenirken hata oluştu: ${e.toString()}");
    }
  }

  void _updateData(Map<String, dynamic> data) {
    setState(() {
      coachUser = data['coachUser'];
      enrolledStudents = data['enrolledStudents'];
      allCoaches = data['allCoaches'];
      allUsers = data['allUsers'];
      allBranchesList = data['allBranchesList'];
      allSportsList = data['allSportsList'];
      errorMessage = null;
    });
  }

  // 🔥 Varsayılan Avatar
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

  // 🔥 Profil Fotoğrafı
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

  // 🔥 GRUBU GÜNCELLE
  Future<bool> _updateGroup(Map<String, dynamic> updateData) async {
    setState(() => errorMessage = null);

    try {
      final success = await GoogleSheetService.updateGroup(
        widget.group.groups_id,
        updateData,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Güncelleme başarılı!"),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _groupDataFuture = _loadGroupChain();
        });
        return true;
      } else {
        throw Exception("Güncelleme başarısız");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Hata: $e"), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  // 🔥 GRUP DÜZENLEME DİYALOĞU
  void _showEditGroupDialog() {
    final nameCtrl = TextEditingController(text: widget.group.name);
    final scheduleCtrl = TextEditingController(text: widget.group.schedule);
    final capCtrl = TextEditingController(text: widget.group.capacity);
    final feeCtrl = TextEditingController(text: widget.group.monthly_fee);
    String? selBranch = widget.group.branches_id;
    String? selCoach = widget.group.coach_id;
    String? selSport = widget.group.sports_id;
    bool isSubmitting = false;

    // Antrenör listesini hazırla
    List<Map<String, String>> coachList = [];
    for (var coach in allCoaches) {
      final user = allUsers.firstWhere(
        (u) => u.app == coach.user_id,
        orElse: () => Users(
          app: "",
          first_name: "Bilinmeyen",
          last_name: "Antrenör",
          email: "",
          branches_id: '',
          phone: '',
          password_hash: '',
          role: '',
          profile_photo_url: '',
          amount: '',
          b_date: '',
          created_at: '',
          last_login: '',
          is_active: '',
        ),
      );
      coachList.add({
        'id': coach.coach_id,
        'name': "${user.first_name} ${user.last_name}".trim(),
      });
    }

    // Spor listesi
    List<Map<String, String>> sportList = [];
    for (var sport in allSportsList) {
      sportList.add({'id': sport.sports_id, 'name': sport.name});
    }

    // Şube listesi
    List<Map<String, String>> branchList = [];
    for (var branch in allBranchesList) {
      branchList.add({'id': branch.branches_id, 'name': branch.name});
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit, color: Colors.indigo),
              SizedBox(width: 8),
              Text("Grubu Düzenle"),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selBranch,
                    decoration: const InputDecoration(
                      labelText: "Şube",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: branchList.map((b) {
                      return DropdownMenuItem(
                        value: b['id'],
                        child: Text(b['name']!),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selBranch = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selSport,
                    decoration: const InputDecoration(
                      labelText: "Spor Branşı",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sports_basketball),
                    ),
                    items: sportList.map((s) {
                      return DropdownMenuItem(
                        value: s['id'],
                        child: Text(s['name']!),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selSport = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selCoach,
                    hint: const Text("Antrenör Seçiniz"),
                    decoration: const InputDecoration(
                      labelText: "Antrenör",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: coachList.map((coach) {
                      return DropdownMenuItem(
                        value: coach['id'],
                        child: Text(coach['name']!),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selCoach = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Grup Adı",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.group),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scheduleCtrl,
                    decoration: const InputDecoration(
                      labelText: "Program (Saat/Gün)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: capCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Kapasite",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.people),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: feeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Aylık Ücret",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payments),
                            suffixText: "TL",
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (selBranch == null ||
                          selSport == null ||
                          nameCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Lütfen tüm zorunlu alanları doldurun!",
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      final updateData = {
                        "branches_id": selBranch,
                        "coach_id": selCoach ?? "",
                        "sports_id": selSport,
                        "groups_name": nameCtrl.text,
                        "schedule": scheduleCtrl.text,
                        "capacity": capCtrl.text.isEmpty ? "0" : capCtrl.text,
                        "monthly_fee": feeCtrl.text.isEmpty
                            ? "0"
                            : feeCtrl.text,
                      };

                      final ok = await _updateGroup(updateData);

                      setDialogState(() => isSubmitting = false);

                      if (ok && mounted) {
                        Navigator.pop(context);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Güncelle"),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 GRUBU AKTİF/PASİF YAP - DÜZELTİLDİ (parametresiz)
  Future<void> _toggleGroupStatus() async {
    final newStatus = widget.group.is_active == "TRUE" ? "FALSE" : "TRUE";
    final actionText = newStatus == "TRUE" ? "aktif" : "pasif";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          widget.group.is_active == "TRUE"
              ? "Grubu Pasif Yap"
              : "Grubu Aktif Yap",
        ),
        content: Text(
          "${widget.group.name} grubunu ${actionText} yapmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.group.is_active == "TRUE"
                  ? Colors.red
                  : Colors.green,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              widget.group.is_active == "TRUE" ? "Pasif Yap" : "Aktif Yap",
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 🔥 updateGroup ile güncelle
    final success = await GoogleSheetService.updateGroup(
      widget.group.groups_id,
      {"is_active": newStatus},
    );

    if (success && mounted) {
      GoogleSheetService.invalidateCache('groups');
      setState(() => _groupDataFuture = _loadGroupChain());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Grup ${actionText} yapıldı!"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ İşlem başarısız!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _assignCoach(String coachId) async {
    await _updateGroup({"coach_id": coachId});
  }

  void _showAssignCoachDialog() {
    if (allCoaches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kayıtlı antrenör bulunamadı")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Antrenör Seç"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: allCoaches.length,
            itemBuilder: (context, index) {
              final coach = allCoaches[index];
              final coachUserTemp = allUsers.firstWhere(
                (u) => u.app == coach.user_id,
                orElse: () => Users(
                  app: "",
                  first_name: "Bilinmeyen",
                  last_name: "Antrenör",
                  email: "",
                  phone: "",
                  password_hash: "",
                  role: "coach",
                  profile_photo_url: "",
                  amount: "",
                  b_date: "",
                  created_at: "",
                  last_login: "",
                  is_active: "",
                  branches_id: "",
                ),
              );
              return ListTile(
                leading: _buildProfileImage(
                  coachUserTemp.profile_photo_url,
                  40,
                  coachUserTemp,
                ),
                title: Text(
                  "${coachUserTemp.first_name} ${coachUserTemp.last_name}",
                ),
                subtitle: Text(coachUserTemp.email),
                onTap: () {
                  Navigator.pop(context);
                  _assignCoach(coach.coach_id);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
        ],
      ),
    );
  }

  Future<void> _changeBranch(String branchId) async {
    await _updateGroup({"branches_id": branchId});
  }

  void _showChangeBranchDialog() {
    if (allBranchesList.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Kayıtlı şube bulunamadı")));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Şube Seç"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: allBranchesList.length,
            itemBuilder: (context, index) {
              final branch = allBranchesList[index];
              return ListTile(
                title: Text(branch.name),
                subtitle: Text(branch.address),
                trailing: widget.group.branches_id == branch.branches_id
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (widget.group.branches_id != branch.branches_id) {
                    _changeBranch(branch.branches_id);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog() async {
    final allStudents = await GoogleSheetService.getStudentsOnly();
    final studentsInGroup = enrolledStudents.map((s) => s.app).toList();
    final availableStudents = allStudents
        .where((s) => !studentsInGroup.contains(s.app))
        .toList();

    if (availableStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Eklenebilecek öğrenci bulunamadı")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Öğrenci Seç"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: availableStudents.length,
            itemBuilder: (context, index) {
              final student = availableStudents[index];
              return ListTile(
                leading: _buildProfileImage(
                  student.profile_photo_url,
                  40,
                  student,
                ),
                title: Text("${student.first_name} ${student.last_name}"),
                subtitle: Text(student.email),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => errorMessage = null);
                  final success = await GoogleSheetService.assignStudentToGroup(
                    student.app,
                    widget.group.groups_id,
                  );
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("✅ ${student.first_name} gruba eklendi"),
                      ),
                    );
                    setState(() {
                      _groupDataFuture = _loadGroupChain();
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("❌ Öğrenci eklenemedi"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
        ],
      ),
    );
  }

  void _makePhoneCall(String? phone) async {
    if (phone != null && phone.isNotEmpty) {
      // Telefon arama işlemi
    }
  }

  void _handleStudentAction(String action, Users student) {
    switch (action) {
      case 'view':
        break;
      case 'call':
        _makePhoneCall(student.phone);
        break;
      case 'remove':
        _showRemoveConfirmation(student);
        break;
    }
  }

  void _showRemoveConfirmation(Users student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Öğrenciyi Çıkar"),
        content: Text(
          "${student.first_name} ${student.last_name} adlı öğrenciyi gruptan çıkarmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => errorMessage = null);
              final success = await GoogleSheetService.removeStudentFromGroup(
                student.app,
                widget.group.groups_id,
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("✅ ${student.first_name} gruptan çıkarıldı"),
                  ),
                );
                setState(() {
                  _groupDataFuture = _loadGroupChain();
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("❌ Öğrenci çıkarılamadı"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Çıkar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          widget.group.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditGroupDialog,
            tooltip: "Grubu Düzenle",
          ),
          IconButton(
            icon: Icon(
              widget.group.is_active == "TRUE"
                  ? Icons.visibility_off
                  : Icons.visibility,
              color: widget.group.is_active == "TRUE"
                  ? Colors.red
                  : Colors.green,
            ),
            onPressed: _toggleGroupStatus,
            tooltip: widget.group.is_active == "TRUE"
                ? "Pasif Yap"
                : "Aktif Yap",
          ),
          IconButton(
            icon: const Icon(Icons.business),
            onPressed: _showChangeBranchDialog,
            tooltip: "Şube Değiştir",
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _groupDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorWidget(snapshot.error);
          }

          final data = snapshot.data!;
          _updateData(data);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _groupDataFuture = _loadGroupChain();
              });
              await _groupDataFuture;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 24),
                  _buildCoachSection(),
                  const SizedBox(height: 32),
                  _buildStudentSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoachSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Sorumlu Antrenör",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            TextButton.icon(
              onPressed: _showAssignCoachDialog,
              icon: const Icon(Icons.swap_horiz),
              label: const Text("Değiştir"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        coachUser != null ? _buildCoachCard() : _buildEmptyCoachCard(),
      ],
    );
  }

  Widget _buildStudentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Öğrenci Kadrosu (${enrolledStudents.length})",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            TextButton.icon(
              onPressed: _showAddStudentDialog,
              icon: const Icon(Icons.add),
              label: const Text("Ekle"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildStudentList(),
      ],
    );
  }

  Widget _buildErrorWidget(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _groupDataFuture = _loadGroupChain();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text("Tekrar Dene"),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final capacityPercentage = widget.group.capacity != "0"
        ? (enrolledStudents.length / double.parse(widget.group.capacity)) * 100
        : 0.0;

    final branch = allBranchesList.firstWhere(
      (b) => b.branches_id == widget.group.branches_id,
      orElse: () => Branches(
        branches_id: widget.group.branches_id,
        name: 'Belirtilmemiş',
        address: '',
        phone: '',
        email: '',
        is_active: 'FALSE',
        created_at: '',
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          _rowInfo(Icons.business, "Şube", branch.name),
          const Divider(height: 24),
          _rowInfo(Icons.calendar_month, "Program", widget.group.schedule),
          const Divider(height: 24),
          _rowInfo(
            Icons.people,
            "Kapasite",
            "${enrolledStudents.length} / ${widget.group.capacity}",
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: capacityPercentage / 100,
            backgroundColor: Colors.grey.shade200,
            color: capacityPercentage > 80 ? Colors.orange : Colors.indigo,
          ),
          const Divider(height: 24),
          _rowInfo(
            Icons.payments,
            "Aylık Ücret",
            "${widget.group.monthly_fee} TL",
          ),
        ],
      ),
    );
  }

  Widget _buildCoachCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.indigo.shade100),
      ),
      child: ListTile(
        leading: _buildProfileImage(
          coachUser!.profile_photo_url,
          50,
          coachUser!,
        ),
        title: Text(
          "${coachUser!.first_name} ${coachUser!.last_name}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(coachUser!.email),
        trailing: IconButton(
          icon: const Icon(Icons.phone, color: Colors.green),
          onPressed: () => _makePhoneCall(coachUser!.phone),
        ),
      ),
    );
  }

  Widget _buildEmptyCoachCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: _showAssignCoachDialog,
        child: const ListTile(
          leading: Icon(Icons.person_add, color: Colors.indigo),
          title: Text("Antrenör Ata"),
          subtitle: Text("Bu gruba bir antrenör atamak için tıklayın"),
          trailing: Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    if (enrolledStudents.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                "Grupta kayıtlı öğrenci yok",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: enrolledStudents.length,
      itemBuilder: (context, index) {
        final student = enrolledStudents[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: _buildProfileImage(student.profile_photo_url, 45, student),
            title: Text(
              "${student.first_name} ${student.last_name}",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              student.phone.isNotEmpty ? student.phone : "Telefon yok",
            ),
            trailing: PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text("Profili Gör")),
                const PopupMenuItem(value: 'call', child: Text("Ara")),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text("Gruptan Çıkar"),
                ),
              ],
              onSelected: (value) => _handleStudentAction(value, student),
            ),
          ),
        );
      },
    );
  }

  Widget _rowInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.indigo),
        const SizedBox(width: 12),
        Text("$label: ", style: const TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
