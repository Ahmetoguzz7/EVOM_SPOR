import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:url_launcher/url_launcher.dart';

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

  bool _isLoading = false; // 🔥 GLOBAL LOADING STATE

  // =========================================================================
  // 🔥 TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

  String _formatDateShort(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
    return formatter.format(date);
  }

  String _formatDateLong(DateTime date) {
    final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
    return formatter.format(date);
  }

  String _formatDateFromString(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      final date = DateTime.parse(dateStr);
      return _formatDateLong(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  void initState() {
    super.initState();
    _groupDataFuture = _loadGroupChain();
  }

  Future<Map<String, dynamic>> _loadGroupChain() async {
    try {
      final results = await Future.wait([
        GoogleSheetService.getUsersCached(forceRefresh: true),
        GoogleSheetService.getCoachesCached(forceRefresh: true),
        GoogleSheetService.getGroupStudentsByGroupId(
          widget.group.groups_id,
          forceRefresh: true,
        ),
        GoogleSheetService.getBranchesCached(forceRefresh: true),
        GoogleSheetService.getSportsCached(forceRefresh: true),
      ]);

      final allUsersTemp = results[0] as List<Users>;
      final allCoachesTemp = results[1] as List<Coach>;
      final allGroupRelations = results[2] as List<GroupStudent>;
      final allBranchesListTemp = results[3] as List<Branches>;
      final allSportsListTemp = results[4] as List<Sports>;

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

  // 🔥 YENİ: İŞLEM SIRASINDA LOADING GÖSTER
  Future<void> _executeWithLoading(
    Future<bool> Function() operation, {
    required String successMessage,
    required String loadingMessage,
    String? errorMessage,
  }) async {
    setState(() => _isLoading = true);

    // Loading dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(loadingMessage),
          ],
        ),
      ),
    );

    try {
      final success = await operation();

      // Loading dialog'u kapat
      Navigator.of(context).pop();

      if (success && mounted) {
        // Verileri yenile
        setState(() {
          _groupDataFuture = _loadGroupChain();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? "❌ İşlem başarısız!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Hata: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Varsayılan Avatar
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

  Widget _buildProfileImage(
    BuildContext context,
    String? imageUrl,
    double size,
    Users user,
  ) {
    final String heroTag = 'profile_photo_${user.profile_photo_url}';

    Widget imageWidget;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageWidget = ClipRRect(
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
              insetPadding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: InteractiveViewer(
                  panEnabled: true,
                  maxScale: 4.0,
                  child: Hero(
                    tag: heroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        width: MediaQuery.of(context).size.width * 0.95,
                        fit: BoxFit.contain,
                      ),
                    ),
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

  Future<bool> _updateGroup(Map<String, dynamic> updateData) async {
    setState(() => errorMessage = null);

    try {
      final success = await GoogleSheetService.updateGroup(
        widget.group.groups_id,
        updateData,
      );
      return success;
    } catch (e) {
      return false;
    }
  }

  void _showEditGroupDialog() {
    final nameCtrl = TextEditingController(text: widget.group.name);
    final scheduleCtrl = TextEditingController(text: widget.group.schedule);
    final capCtrl = TextEditingController(text: widget.group.capacity);
    final feeCtrl = TextEditingController(text: widget.group.monthly_fee);
    String? selBranch = widget.group.branches_id;
    String? selCoach = widget.group.coach_id;
    String? selSport = widget.group.sports_id;
    bool isSubmitting = false;

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

    List<Map<String, String>> sportList = [];
    for (var sport in allSportsList) {
      sportList.add({'id': sport.sports_id, 'name': sport.name});
    }

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

                      await _executeWithLoading(
                        () => _updateGroup(updateData),
                        successMessage: "✅ Grup güncellendi!",
                        loadingMessage: "Grup güncelleniyor...",
                      );

                      setDialogState(() => isSubmitting = false);
                      if (mounted) Navigator.pop(context);
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

    await _executeWithLoading(
      () async {
        final success = await GoogleSheetService.updateGroup(
          widget.group.groups_id,
          {"is_active": newStatus},
        );
        if (success) GoogleSheetService.invalidateCache('groups');
        return success;
      },
      successMessage: "✅ Grup ${actionText} yapıldı!",
      loadingMessage: "Grup durumu güncelleniyor...",
    );
  }

  Future<void> _assignCoach(String coachId) async {
    await _executeWithLoading(
      () => _updateGroup({"coach_id": coachId}),
      successMessage: "✅ Antrenör değiştirildi!",
      loadingMessage: "Antrenör atanıyor...",
    );
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
                  context,
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
    await _executeWithLoading(
      () => _updateGroup({"branches_id": branchId}),
      successMessage: "✅ Şube değiştirildi!",
      loadingMessage: "Şube güncelleniyor...",
    );
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

  // 🔥 YENİ: TRANSFER MANTIĞI İLE ÖĞRENCİ EKLEME
  void _showAddStudentDialog() async {
    final allStudents = await GoogleSheetService.getStudentsOnly();
    final studentsInGroup = enrolledStudents.map((s) => s.app).toList();

    // Mevcut grupta OLMAYAN tüm öğrenciler (başka grupta olsalar bile)
    final availableStudents = allStudents
        .where((s) => !studentsInGroup.contains(s.app))
        .toList();

    if (availableStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Eklenebilecek öğrenci bulunamadı")),
      );
      return;
    }

    // Öğrencilerin hangi grupta olduğunu bulmak için ilişkileri çek
    final allRelations = await GoogleSheetService.getGroupStudentsCached(
      forceRefresh: true,
    );
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

              // Öğrencinin aktif grubunu bul
              final activeRelation = allRelations.firstWhere(
                (rel) =>
                    rel.student_id == student.app && rel.is_active == "TRUE",
                orElse: () => GroupStudent(
                  group_students_id: "",
                  groups_id: "",
                  student_id: "",
                  enrolled_at: "",
                  is_active: "",
                ),
              );

              final isInAnotherGroup = activeRelation.groups_id.isNotEmpty;

              return ListTile(
                leading: _buildProfileImage(
                  context,
                  student.profile_photo_url,
                  40,
                  student,
                ),
                title: Text("${student.first_name} ${student.last_name}"),
                subtitle: Text(
                  isInAnotherGroup
                      ? "⚠️ Başka grupta - Bu gruba taşınacak"
                      : student.email,
                  style: TextStyle(
                    color: isInAnotherGroup ? Colors.orange : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                trailing: isInAnotherGroup
                    ? const Icon(Icons.swap_horiz, color: Colors.orange)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);

                  // TRANSFER veya YENİ EKLEME kararı
                  if (isInAnotherGroup) {
                    // 🔥 GRUP DEĞİŞTİR (TRANSFER)
                    await _executeWithLoading(
                      () => GoogleSheetService.transferStudentToGroup(
                        student.app,
                        widget.group.groups_id,
                      ),
                      successMessage:
                          "🔄 ${student.first_name} grubu değiştirildi!",
                      loadingMessage: "${student.first_name} taşınıyor...",
                    );
                  } else {
                    // YENİ EKLEME
                    await _executeWithLoading(
                      () => GoogleSheetService.assignStudentToGroup(
                        student.app,
                        widget.group.groups_id,
                      ),
                      successMessage: "✅ ${student.first_name} gruba eklendi!",
                      loadingMessage: "${student.first_name} ekleniyor...",
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
      final Uri launchUri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
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
      barrierDismissible: false, // Dialog kapanana kadar dokunma engelle
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
              setState(() {
                // Dialog içindeki state'i güncellemek için
              });

              // Önce dialog'u kapatma, içinde loading göster
              // Bunun yerine showDialog içinde StatefulBuilder kullan

              Navigator.pop(ctx); // Önce kapat

              // Loading dialog göster
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingCtx) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 20),
                      Text("Öğrenci çıkarılıyor..."),
                    ],
                  ),
                ),
              );

              try {
                final success = await GoogleSheetService.removeStudentFromGroup(
                  student.app,
                  widget.group.groups_id,
                );

                Navigator.pop(context); // Loading dialog'u kapat

                if (success && mounted) {
                  setState(() {
                    _groupDataFuture = _loadGroupChain();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "✅ ${student.first_name} gruptan çıkarıldı",
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("❌ İşlem başarısız!")),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("❌ Hata: $e")));
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
    return WillPopScope(
      onWillPop: () async {
        // Geri gidince parent sayfaya "true" döndür, o da yeniler
        Navigator.of(context).pop(true);
        return false;
      },
      child: Scaffold(
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
        body: Stack(
          children: [
            FutureBuilder<Map<String, dynamic>>(
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
            // 🔥 GLOBAL LOADING OVERLAY
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Veriler güncelleniyor..."),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
          context,
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
            leading: _buildProfileImage(
              context,
              student.profile_photo_url,
              45,
              student,
            ),
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
