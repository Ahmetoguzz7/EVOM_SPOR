/*import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'package:EVOM_SPOR/managerpage/manager_student_assignment.dart';

class GroupManagementScreen extends StatefulWidget {
  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  late Future<Map<String, dynamic>> _groupDataFuture;

  @override
  void initState() {
    super.initState();
    _groupDataFuture = _loadAllData();
  }

  Future<Map<String, dynamic>> _loadAllData() async {
    try {
      final results = await Future.wait([
        GoogleSheetService.getGroupsCached(),
        GoogleSheetService.getUsersCached(),
        GoogleSheetService.getCoachesCached(),
        GoogleSheetService.getGroupStudentsCached(),
        GoogleSheetService.getBranchesCached(),
        GoogleSheetService.getSportsCached(),
      ]);

      return {
        'groups': results[0] as List<Group>,
        'users': results[1] as List<Users>,
        'coaches': results[2] as List<Coach>,
        'relations': results[3] as List<GroupStudent>,
        'branches': results[4] as List<Branches>,
        'sports': results[5] as List<Sports>,
      };
    } catch (e) {
      print("Veri yükleme hatası: $e");
      return {
        'groups': <Group>[],
        'users': <Users>[],
        'coaches': <Coach>[],
        'relations': <GroupStudent>[],
        'branches': <Branches>[],
        'sports': <Sports>[],
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Grup Yönetimi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _groupDataFuture = _loadAllData()),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _groupDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
          }

          if (snapshot.hasError) {
            return _buildErrorScreen(snapshot.error);
          }

          final allGroups = snapshot.data?['groups'] as List<Group>? ?? [];
          final allUsers = snapshot.data?['users'] as List<Users>? ?? [];
          final allCoaches = snapshot.data?['coaches'] as List<Coach>? ?? [];
          final allRelations =
              snapshot.data?['relations'] as List<GroupStudent>? ?? [];
          final branches = snapshot.data?['branches'] as List<Branches>? ?? [];
          final sports = snapshot.data?['sports'] as List<Sports>? ?? [];

          if (allGroups.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _groupDataFuture = _loadAllData());
              await _groupDataFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: allGroups.length,
              itemBuilder: (context, index) => _buildGroupCard(
                allGroups[index],
                allUsers,
                allCoaches,
                allRelations,
                branches,
                sports,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E293B),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          _groupDataFuture.then((data) {
            final branches = data['branches'] as List<Branches>? ?? [];
            final sports = data['sports'] as List<Sports>? ?? [];
            final coaches = data['coaches'] as List<Coach>? ?? [];
            final users = data['users'] as List<Users>? ?? [];
            _showAddGroupBottomSheet(context, branches, sports, coaches, users);
          });
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF1E293B)),
          SizedBox(height: 16),
          Text("Gruplar yükleniyor..."),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text("Bir hata oluştu"),
          const SizedBox(height: 8),
          Text(error.toString()),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _groupDataFuture = _loadAllData()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
            ),
            child: const Text("Tekrar Dene"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_off, size: 64, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz grup bulunmuyor",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "Yeni grup eklemek için + butonuna tıklayın",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // 🔥 Varsayılan Avatar (İsmin ilk harfi)
  Widget _buildDefaultAvatar(Users user, double size) {
    String initial = user.first_name.isNotEmpty
        ? user.first_name[0].toUpperCase()
        : "?";

    return Container(
      width: size,
      height: size,
      color: Colors.indigo.shade100,
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

  // 🔥 GRUP DÜZENLEME DİYALOĞU
  void _showEditGroupDialog(
    Group group,
    List<Branches> branches,
    List<Sports> sports,
    List<Coach> coaches,
    List<Users> users,
  ) {
    final nameCtrl = TextEditingController(text: group.name);
    final scheduleCtrl = TextEditingController(text: group.schedule);
    final capCtrl = TextEditingController(text: group.capacity);
    final feeCtrl = TextEditingController(text: group.monthly_fee);
    String? selBranch = group.branches_id;
    String? selCoach = group.coach_id;
    String? selSport = group.sports_id;
    bool isSubmitting = false;

    // Antrenör listesini hazırla
    List<Map<String, String>> coachList = [];
    for (var coach in coaches) {
      final user = users.firstWhere(
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
                    items: branches.map((b) {
                      return DropdownMenuItem(
                        value: b.branches_id,
                        child: Text(b.name),
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
                    items: sports.map((s) {
                      return DropdownMenuItem(
                        value: s.sports_id,
                        child: Text(s.name),
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

                      bool ok = await GoogleSheetService.updateData(
                        "groups",
                        group.groups_id as Map<String, dynamic>,
                        updateData,
                      );

                      setDialogState(() => isSubmitting = false);

                      if (ok && mounted) {
                        Navigator.pop(context);
                        setState(() => _groupDataFuture = _loadAllData());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("✅ Grup güncellendi!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("❌ Güncelleme başarısız!"),
                            backgroundColor: Colors.red,
                          ),
                        );
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

  /*
  // 🔥 GRUP AKTİF/PASİF YAP
// 🔥 EN BASİT VE KESİN ÇÖZÜM: insertData ile güncelle (API'de var)
Future<void> _toggleGroupStatus(Group group) async {
  final newStatus = group.is_active == "TRUE" ? "FALSE" : "TRUE";
  final actionText = newStatus == "TRUE" ? "aktif" : "pasif";
  
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(group.is_active == "TRUE" ? "Grubu Pasif Yap" : "Grubu Aktif Yap"),
      content: Text("${group.name} grubunu ${actionText} yapmak istediğinize emin misiniz?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: group.is_active == "TRUE" ? Colors.red : Colors.green,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(group.is_active == "TRUE" ? "Pasif Yap" : "Aktif Yap"),
        ),
      ],
    ),
  );
  
  if (confirm != true) return;
  
  // 🔥 insertData ile TÜM grup verilerini güncelle
  final success = await GoogleSheetService.insertData("groups", {
    "groups_id": group.groups_id,
    "branches_id": group.branches_id,
    "coach_id": group.coach_id,
    "sports_id": group.sports_id,
    "groups_name": group.name,
    "schedule": group.schedule,
    "capacity": group.capacity,
    "monthly_fee": group.monthly_fee,
    "is_active": newStatus,
  });
  
  if (success && mounted) {
    GoogleSheetService.invalidateCache('groups');
    setState(() => _groupDataFuture = _loadAllData());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Grup ${actionText} yapıldı!"), backgroundColor: Colors.green),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❌ İşlem başarısız!"), backgroundColor: Colors.red),
    );
  }
}*/
  /*
  // 🔥 GRUP AKTİF/PASİF YAP - DÜZELTİLMİŞ VE KESİN ÇALIŞAN
  Future<void> _toggleGroupStatus(Group group) async {
    final newStatus = group.is_active == "TRUE" ? "FALSE" : "TRUE";
    final actionText = newStatus == "TRUE" ? "aktif" : "pasif";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          group.is_active == "TRUE" ? "Grubu Pasif Yap" : "Grubu Aktif Yap",
        ),
        content: Text(
          "${group.name} grubunu ${actionText} yapmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: group.is_active == "TRUE"
                  ? Colors.red
                  : Colors.green,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(group.is_active == "TRUE" ? "Pasif Yap" : "Aktif Yap"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 🔥 YENİ EKLENEN updateGroupStatus METODUNU KULLAN
    final success = await GoogleSheetService.updateGroupStatus(
      group.groups_id,
      newStatus,
    );

    if (success && mounted) {
      setState(() => _groupDataFuture = _loadAllData());
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
  */
  // 🔥 GRUP AKTİF/PASİF YAP - DÜZELTİLMİŞ (setState hatası giderildi)
  Future<void> _toggleGroupStatus(Group group) async {
    final newStatus = group.is_active == "TRUE" ? "FALSE" : "TRUE";
    final actionText = newStatus == "TRUE" ? "aktif" : "pasif";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          group.is_active == "TRUE" ? "Grubu Pasif Yap" : "Grubu Aktif Yap",
        ),
        content: Text(
          "${group.name} grubunu ${actionText} yapmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: group.is_active == "TRUE"
                  ? Colors.red
                  : Colors.green,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(group.is_active == "TRUE" ? "Pasif Yap" : "Aktif Yap"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 🔥 API'DE VAR OLAN updateGroup aksiyonunu kullan
    final success = await GoogleSheetService.updateGroup(group.groups_id, {
      "is_active": newStatus,
    });

    // 🔥 setState DIŞINDA işlem yap, sonra setState içinde state'i güncelle
    if (success && mounted) {
      // Cache'i temizle
      GoogleSheetService.invalidateCache('groups');

      // setState içinde SADECE state güncelleme yap
      setState(() {
        _groupDataFuture = _loadAllData();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Grup ${actionText} yapıldı!"),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ İşlem başarısız!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeStudentFromGroup(Users student, Group group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Öğrenciyi Çıkar"),
        content: Text(
          "${student.first_name} ${student.last_name} adlı öğrenciyi gruptan çıkarmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Çıkar"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await GoogleSheetService.removeStudentFromGroup(
      student.app,
      group.groups_id,
    );

    if (success && mounted) {
      setState(() => _groupDataFuture = _loadAllData());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ ${student.first_name} gruptan çıkarıldı"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildGroupCard(
    Group group,
    List<Users> allUsers,
    List<Coach> allCoaches,
    List<GroupStudent> allRelations,
    List<Branches> branches,
    List<Sports> sports,
  ) {
    // Antrenör bilgisini bul
    String coachName = "Atanmamış";
    String coachId = "";
    try {
      final coachObj = allCoaches.firstWhere(
        (c) => c.coach_id == group.coach_id,
        orElse: () => Coach(
          coach_id: "",
          user_id: "",
          branches_id: "",
          sports_id: "",
          bio: "",
          certificate_info: "",
          monthly_salary: "",
          hired_at: "",
        ),
      );
      if (coachObj.user_id.isNotEmpty) {
        final user = allUsers.firstWhere(
          (u) => u.app == coachObj.user_id,
          orElse: () => Users(
            app: "",
            branches_id: "",
            first_name: "",
            last_name: "",
            email: "",
            phone: "",
            password_hash: "",
            role: "",
            profile_photo_url: "",
            amount: "",
            b_date: "",
            created_at: "",
            last_login: "",
            is_active: "",
          ),
        );
        if (user.first_name.isNotEmpty) {
          coachName = "${user.first_name} ${user.last_name}";
          coachId = coachObj.coach_id;
        }
      }
    } catch (e) {}

    // Şube adını bul
    String branchName = "Belirtilmemiş";
    try {
      final branch = branches.firstWhere(
        (b) => b.branches_id == group.branches_id,
      );
      branchName = branch.name;
    } catch (e) {}

    // Spor adını bul
    String sportName = "Belirtilmemiş";
    try {
      final sport = sports.firstWhere((s) => s.sports_id == group.sports_id);
      sportName = sport.name;
    } catch (e) {}

    // Gruptaki öğrencileri bul
    final studentsInGroup = allUsers.where((u) {
      return allRelations.any(
        (rel) =>
            rel.groups_id == group.groups_id &&
            rel.student_id == u.app &&
            rel.is_active.toString().toUpperCase() == "TRUE",
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.group, color: Colors.indigo),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "${studentsInGroup.length} öğrenci • ${group.capacity} kapasite",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              coachName != "Atanmamış"
                  ? "👨‍🏫 $coachName"
                  : "👨‍🏫 Antrenör atanmamış",
              style: TextStyle(
                fontSize: 12,
                color: coachName != "Atanmamış" ? Colors.teal : Colors.grey,
              ),
            ),
          ],
        ),
        // 🔥 SAĞ TARAFTAKİ MENÜ
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Aktif/Pasif etiketi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: group.is_active == "TRUE"
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                group.is_active == "TRUE" ? "Aktif" : "Pasif",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: group.is_active == "TRUE" ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Menü butonu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) async {
                if (value == 'edit') {
                  _showEditGroupDialog(
                    group,
                    branches,
                    sports,
                    allCoaches,
                    allUsers,
                  );
                } else if (value == 'toggle_status') {
                  await _toggleGroupStatus(group);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20, color: Colors.blue),
                      SizedBox(width: 12),
                      Text("Düzenle"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_status',
                  child: Row(
                    children: [
                      Icon(
                        group.is_active == "TRUE"
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                        color: group.is_active == "TRUE"
                            ? Colors.red
                            : Colors.green,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        group.is_active == "TRUE" ? "Pasif Yap" : "Aktif Yap",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bilgi Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(Icons.business, "Şube", branchName),
                    ),
                    Expanded(
                      child: _buildInfoTile(
                        Icons.sports_basketball,
                        "Spor",
                        sportName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        Icons.schedule,
                        "Program",
                        group.schedule.isEmpty
                            ? "Belirtilmemiş"
                            : group.schedule,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (coachId.isNotEmpty)
                  _buildInfoTile(Icons.person, "Antrenör ID", coachId),
                const Divider(height: 24),

                // Öğrenci Listesi Başlığı
                Row(
                  children: [
                    const Icon(Icons.people, color: Colors.indigo, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Öğrenci Listesi (${studentsInGroup.length})",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 🔥 ÖĞRENCİ LİSTESİ (FOTOĞRAFLI + ÇIKARMA BUTONLU)
                studentsInGroup.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Bu grupta henüz öğrenci yok",
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Öğrenci eklemek için 'Öğrenci Ata' butonuna tıklayın",
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: studentsInGroup.length,
                        itemBuilder: (context, index) {
                          final student = studentsInGroup[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: _buildProfileImage(
                                student.profile_photo_url,
                                45,
                                student,
                              ),
                              title: Text(
                                "${student.first_name} ${student.last_name}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(student.email),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _removeStudentFromGroup(student, group),
                                tooltip: "Gruptan Çıkar",
                              ),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 20),

                // Butonlar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentAssignmentScreen(group: group),
                        ),
                      ),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text("Öğrenci Ata"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddGroupBottomSheet(
    BuildContext context,
    List<Branches> branches,
    List<Sports> sports,
    List<Coach> coaches,
    List<Users> users,
  ) {
    final nameCtrl = TextEditingController();
    final scheduleCtrl = TextEditingController();
    final capCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    String? selBranch;
    String? selCoach;
    String? selSport;
    bool isSubmitting = false;

    // Antrenör listesini hazırla (isimleriyle birlikte)
    List<Map<String, String>> coachList = [];
    for (var coach in coaches) {
      final user = users.firstWhere(
        (u) => u.app == coach.user_id,
        orElse: () => Users(
          app: "",
          first_name: "",
          last_name: "",
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.group_add, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        "Yeni Grup Oluştur",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Şube",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          prefixIcon: Icon(Icons.business),
                        ),
                        hint: const Text("Şube Seçiniz"),
                        items: branches.map((b) {
                          return DropdownMenuItem(
                            value: b.branches_id,
                            child: Text(b.name),
                          );
                        }).toList(),
                        onChanged: (v) => setModalState(() => selBranch = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Spor Branşı",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          prefixIcon: Icon(Icons.sports_basketball),
                        ),
                        hint: const Text("Spor Seçiniz"),
                        items: sports.map((s) {
                          return DropdownMenuItem(
                            value: s.sports_id,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (v) => setModalState(() => selSport = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        hint: const Text("Antrenör Seçiniz"),
                        decoration: const InputDecoration(
                          labelText: "Antrenör",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: coachList.map((coach) {
                          return DropdownMenuItem(
                            value: coach['id'],
                            child: Text(coach['name']!),
                          );
                        }).toList(),
                        onChanged: (v) => setModalState(() => selCoach = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: "Grup Adı",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          prefixIcon: Icon(Icons.group),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: scheduleCtrl,
                        decoration: const InputDecoration(
                          labelText: "Program (Saat/Gün)",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
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
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
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
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                                prefixIcon: Icon(Icons.payments),
                                suffixText: "TL",
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  setModalState(() => isSubmitting = true);

                                  final newGroupData = {
                                    "branches_id": selBranch,
                                    "coach_id": selCoach ?? "",
                                    "sports_id": selSport,
                                    "groups_name": nameCtrl.text,
                                    "schedule": scheduleCtrl.text,
                                    "capacity": capCtrl.text.isEmpty
                                        ? "0"
                                        : capCtrl.text,
                                    "monthly_fee": feeCtrl.text.isEmpty
                                        ? "0"
                                        : feeCtrl.text,
                                    "is_active": "TRUE",
                                  };

                                  bool ok = await GoogleSheetService.insertData(
                                    "groups",
                                    newGroupData,
                                  );
                                  if (ok && mounted) {
                                    Navigator.pop(context);
                                    setState(
                                      () => _groupDataFuture = _loadAllData(),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "✅ Grup başarıyla oluşturuldu!",
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    setModalState(() => isSubmitting = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("❌ Grup oluşturulamadı!"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Grubu Oluştur",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'package:EVOM_SPOR/managerpage/manager_student_assignment.dart';

class GroupManagementScreen extends StatefulWidget {
  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  late Future<Map<String, dynamic>> _groupDataFuture;

  // =========================================================================
  // 🔥 TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

  // Bugünün tarihini Türkçe formatla göster
  String _getTodayDateTurkish() {
    final now = DateTime.now();
    final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
    return formatter.format(now);
  }

  // Tarihi "dd/MM/yyyy" formatında göster
  String _formatDateShort(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
    return formatter.format(date);
  }

  // Tarihi "dd MMMM yyyy HH:mm" formatında göster
  String _formatDateTimeLong(DateTime date) {
    final formatter = DateFormat('dd MMMM yyyy HH:mm', 'tr_TR');
    return formatter.format(date);
  }

  // String'den gelen tarihi Türkçe formatta göster
  String _formatDateFromString(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      final date = DateTime.parse(dateStr);
      return _formatDateShort(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  void initState() {
    super.initState();
    _groupDataFuture = _loadAllData();
  }

  Future<Map<String, dynamic>> _loadAllData() async {
    try {
      final results = await Future.wait([
        GoogleSheetService.getGroupsCached(),
        GoogleSheetService.getUsersCached(),
        GoogleSheetService.getCoachesCached(),
        GoogleSheetService.getGroupStudentsCached(),
        GoogleSheetService.getBranchesCached(),
        GoogleSheetService.getSportsCached(),
      ]);

      return {
        'groups': results[0] as List<Group>,
        'users': results[1] as List<Users>,
        'coaches': results[2] as List<Coach>,
        'relations': results[3] as List<GroupStudent>,
        'branches': results[4] as List<Branches>,
        'sports': results[5] as List<Sports>,
      };
    } catch (e) {
      print("Veri yükleme hatası: $e");
      return {
        'groups': <Group>[],
        'users': <Users>[],
        'coaches': <Coach>[],
        'relations': <GroupStudent>[],
        'branches': <Branches>[],
        'sports': <Sports>[],
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Grup Yönetimi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _groupDataFuture = _loadAllData()),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _groupDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
          }

          if (snapshot.hasError) {
            return _buildErrorScreen(snapshot.error);
          }

          final allGroups = snapshot.data?['groups'] as List<Group>? ?? [];
          final allUsers = snapshot.data?['users'] as List<Users>? ?? [];
          final allCoaches = snapshot.data?['coaches'] as List<Coach>? ?? [];
          final allRelations =
              snapshot.data?['relations'] as List<GroupStudent>? ?? [];
          final branches = snapshot.data?['branches'] as List<Branches>? ?? [];
          final sports = snapshot.data?['sports'] as List<Sports>? ?? [];

          if (allGroups.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _groupDataFuture = _loadAllData());
              await _groupDataFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: allGroups.length,
              itemBuilder: (context, index) => _buildGroupCard(
                allGroups[index],
                allUsers,
                allCoaches,
                allRelations,
                branches,
                sports,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E293B),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          _groupDataFuture.then((data) {
            final branches = data['branches'] as List<Branches>? ?? [];
            final sports = data['sports'] as List<Sports>? ?? [];
            final coaches = data['coaches'] as List<Coach>? ?? [];
            final users = data['users'] as List<Users>? ?? [];
            _showAddGroupBottomSheet(context, branches, sports, coaches, users);
          });
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF1E293B)),
          SizedBox(height: 16),
          Text("Gruplar yükleniyor..."),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text("Bir hata oluştu"),
          const SizedBox(height: 8),
          Text(error.toString()),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _groupDataFuture = _loadAllData()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
            ),
            child: const Text("Tekrar Dene"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_off, size: 64, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz grup bulunmuyor",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "Yeni grup eklemek için + butonuna tıklayın",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // Varsayılan Avatar (İsmin ilk harfi)
  Widget _buildDefaultAvatar(Users user, double size) {
    String initial = user.first_name.isNotEmpty
        ? user.first_name[0].toUpperCase()
        : "?";

    return Container(
      width: size,
      height: size,
      color: Colors.indigo.shade100,
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

  // Profil Fotoğrafı (Kare)
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

  // GRUP DÜZENLEME DİYALOĞU
  void _showEditGroupDialog(
    Group group,
    List<Branches> branches,
    List<Sports> sports,
    List<Coach> coaches,
    List<Users> users,
  ) {
    final nameCtrl = TextEditingController(text: group.name);
    final scheduleCtrl = TextEditingController(text: group.schedule);
    final capCtrl = TextEditingController(text: group.capacity);
    final feeCtrl = TextEditingController(text: group.monthly_fee);
    String? selBranch = group.branches_id;
    String? selCoach = group.coach_id;
    String? selSport = group.sports_id;
    bool isSubmitting = false;

    // Antrenör listesini hazırla
    List<Map<String, String>> coachList = [];
    for (var coach in coaches) {
      final user = users.firstWhere(
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
                    items: branches.map((b) {
                      return DropdownMenuItem(
                        value: b.branches_id,
                        child: Text(b.name),
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
                    items: sports.map((s) {
                      return DropdownMenuItem(
                        value: s.sports_id,
                        child: Text(s.name),
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

                      bool ok = await GoogleSheetService.updateData(
                        "groups",
                        group.groups_id as Map<String, dynamic>,
                        updateData,
                      );

                      setDialogState(() => isSubmitting = false);

                      if (ok && mounted) {
                        Navigator.pop(context);
                        setState(() => _groupDataFuture = _loadAllData());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("✅ Grup güncellendi!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("❌ Güncelleme başarısız!"),
                            backgroundColor: Colors.red,
                          ),
                        );
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

  // GRUP AKTİF/PASİF YAP
  Future<void> _toggleGroupStatus(Group group) async {
    final newStatus = group.is_active == "TRUE" ? "FALSE" : "TRUE";
    final actionText = newStatus == "TRUE" ? "aktif" : "pasif";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          group.is_active == "TRUE" ? "Grubu Pasif Yap" : "Grubu Aktif Yap",
        ),
        content: Text(
          "${group.name} grubunu ${actionText} yapmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: group.is_active == "TRUE"
                  ? Colors.red
                  : Colors.green,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(group.is_active == "TRUE" ? "Pasif Yap" : "Aktif Yap"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await GoogleSheetService.updateGroup(group.groups_id, {
      "is_active": newStatus,
    });

    if (success && mounted) {
      GoogleSheetService.invalidateCache('groups');

      setState(() {
        _groupDataFuture = _loadAllData();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Grup ${actionText} yapıldı!"),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ İşlem başarısız!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeStudentFromGroup(Users student, Group group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Öğrenciyi Çıkar"),
        content: Text(
          "${student.first_name} ${student.last_name} adlı öğrenciyi gruptan çıkarmak istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Çıkar"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await GoogleSheetService.removeStudentFromGroup(
      student.app,
      group.groups_id,
    );

    if (success && mounted) {
      setState(() => _groupDataFuture = _loadAllData());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ ${student.first_name} gruptan çıkarıldı"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildGroupCard(
    Group group,
    List<Users> allUsers,
    List<Coach> allCoaches,
    List<GroupStudent> allRelations,
    List<Branches> branches,
    List<Sports> sports,
  ) {
    // Antrenör bilgisini bul
    String coachName = "Atanmamış";
    String coachId = "";
    try {
      final coachObj = allCoaches.firstWhere(
        (c) => c.coach_id == group.coach_id,
        orElse: () => Coach(
          coach_id: "",
          user_id: "",
          branches_id: "",
          sports_id: "",
          bio: "",
          certificate_info: "",
          monthly_salary: "",
          hired_at: "",
        ),
      );
      if (coachObj.user_id.isNotEmpty) {
        final user = allUsers.firstWhere(
          (u) => u.app == coachObj.user_id,
          orElse: () => Users(
            app: "",
            branches_id: "",
            first_name: "",
            last_name: "",
            email: "",
            phone: "",
            password_hash: "",
            role: "",
            profile_photo_url: "",
            amount: "",
            b_date: "",
            created_at: "",
            last_login: "",
            is_active: "",
          ),
        );
        if (user.first_name.isNotEmpty) {
          coachName = "${user.first_name} ${user.last_name}";
          coachId = coachObj.coach_id;
        }
      }
    } catch (e) {}

    // Şube adını bul
    String branchName = "Belirtilmemiş";
    try {
      final branch = branches.firstWhere(
        (b) => b.branches_id == group.branches_id,
      );
      branchName = branch.name;
    } catch (e) {}

    // Spor adını bul
    String sportName = "Belirtilmemiş";
    try {
      final sport = sports.firstWhere((s) => s.sports_id == group.sports_id);
      sportName = sport.name;
    } catch (e) {}

    // Gruptaki öğrencileri bul
    final studentsInGroup = allUsers.where((u) {
      return allRelations.any(
        (rel) =>
            rel.groups_id == group.groups_id &&
            rel.student_id == u.app &&
            rel.is_active.toString().toUpperCase() == "TRUE",
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.group, color: Colors.indigo),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "${studentsInGroup.length} öğrenci • ${group.capacity} kapasite",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              coachName != "Atanmamış"
                  ? "👨‍🏫 $coachName"
                  : "👨‍🏫 Antrenör atanmamış",
              style: TextStyle(
                fontSize: 12,
                color: coachName != "Atanmamış" ? Colors.teal : Colors.grey,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Aktif/Pasif etiketi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: group.is_active == "TRUE"
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                group.is_active == "TRUE" ? "Aktif" : "Pasif",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: group.is_active == "TRUE" ? Colors.green : Colors.red,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Menü butonu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) async {
                if (value == 'edit') {
                  _showEditGroupDialog(
                    group,
                    branches,
                    sports,
                    allCoaches,
                    allUsers,
                  );
                } else if (value == 'toggle_status') {
                  await _toggleGroupStatus(group);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20, color: Colors.blue),
                      SizedBox(width: 12),
                      Text("Düzenle"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_status',
                  child: Row(
                    children: [
                      Icon(
                        group.is_active == "TRUE"
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                        color: group.is_active == "TRUE"
                            ? Colors.red
                            : Colors.green,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        group.is_active == "TRUE" ? "Pasif Yap" : "Aktif Yap",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bilgi Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(Icons.business, "Şube", branchName),
                    ),
                    Expanded(
                      child: _buildInfoTile(
                        Icons.sports_basketball,
                        "Spor",
                        sportName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        Icons.schedule,
                        "Program",
                        group.schedule.isEmpty
                            ? "Belirtilmemiş"
                            : group.schedule,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (coachId.isNotEmpty)
                  _buildInfoTile(Icons.person, "Antrenör ID", coachId),
                const Divider(height: 24),

                // Öğrenci Listesi Başlığı
                Row(
                  children: [
                    const Icon(Icons.people, color: Colors.indigo, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Öğrenci Listesi (${studentsInGroup.length})",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ÖĞRENCİ LİSTESİ (FOTOĞRAFLI + ÇIKARMA BUTONLU)
                studentsInGroup.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Bu grupta henüz öğrenci yok",
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Öğrenci eklemek için 'Öğrenci Ata' butonuna tıklayın",
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: studentsInGroup.length,
                        itemBuilder: (context, index) {
                          final student = studentsInGroup[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: _buildProfileImage(
                                student.profile_photo_url,
                                45,
                                student,
                              ),
                              title: Text(
                                "${student.first_name} ${student.last_name}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(student.email),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _removeStudentFromGroup(student, group),
                                tooltip: "Gruptan Çıkar",
                              ),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 20),

                // Butonlar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentAssignmentScreen(group: group),
                        ),
                      ),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text("Öğrenci Ata"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddGroupBottomSheet(
    BuildContext context,
    List<Branches> branches,
    List<Sports> sports,
    List<Coach> coaches,
    List<Users> users,
  ) {
    final nameCtrl = TextEditingController();
    final scheduleCtrl = TextEditingController();
    final capCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    String? selBranch;
    String? selCoach;
    String? selSport;
    bool isSubmitting = false;

    // Antrenör listesini hazırla (isimleriyle birlikte)
    List<Map<String, String>> coachList = [];
    for (var coach in coaches) {
      final user = users.firstWhere(
        (u) => u.app == coach.user_id,
        orElse: () => Users(
          app: "",
          first_name: "",
          last_name: "",
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.group_add, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        "Yeni Grup Oluştur",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Şube",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          prefixIcon: Icon(Icons.business),
                        ),
                        hint: const Text("Şube Seçiniz"),
                        items: branches.map((b) {
                          return DropdownMenuItem(
                            value: b.branches_id,
                            child: Text(b.name),
                          );
                        }).toList(),
                        onChanged: (v) => setModalState(() => selBranch = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Spor Branşı",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          prefixIcon: Icon(Icons.sports_basketball),
                        ),
                        hint: const Text("Spor Seçiniz"),
                        items: sports.map((s) {
                          return DropdownMenuItem(
                            value: s.sports_id,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (v) => setModalState(() => selSport = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        hint: const Text("Antrenör Seçiniz"),
                        decoration: const InputDecoration(
                          labelText: "Antrenör",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: coachList.map((coach) {
                          return DropdownMenuItem(
                            value: coach['id'],
                            child: Text(coach['name']!),
                          );
                        }).toList(),
                        onChanged: (v) => setModalState(() => selCoach = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: "Grup Adı",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          prefixIcon: Icon(Icons.group),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: scheduleCtrl,
                        decoration: const InputDecoration(
                          labelText: "Program (Saat/Gün)",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
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
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
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
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                                prefixIcon: Icon(Icons.payments),
                                suffixText: "TL",
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  setModalState(() => isSubmitting = true);

                                  final newGroupData = {
                                    "branches_id": selBranch,
                                    "coach_id": selCoach ?? "",
                                    "sports_id": selSport,
                                    "groups_name": nameCtrl.text,
                                    "schedule": scheduleCtrl.text,
                                    "capacity": capCtrl.text.isEmpty
                                        ? "0"
                                        : capCtrl.text,
                                    "monthly_fee": feeCtrl.text.isEmpty
                                        ? "0"
                                        : feeCtrl.text,
                                    "is_active": "TRUE",
                                  };

                                  bool ok = await GoogleSheetService.insertData(
                                    "groups",
                                    newGroupData,
                                  );
                                  if (ok && mounted) {
                                    Navigator.pop(context);
                                    setState(
                                      () => _groupDataFuture = _loadAllData(),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "✅ Grup başarıyla oluşturuldu!",
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    setModalState(() => isSubmitting = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("❌ Grup oluşturulamadı!"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Grubu Oluştur",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
