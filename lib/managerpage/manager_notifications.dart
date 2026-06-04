/*
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/app_notificotions/locaal_notifications_service.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';

class NotificationsScreen extends StatefulWidget {
  final Users? currentUser;

  const NotificationsScreen({super.key, this.currentUser});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchUserController = TextEditingController();

  String _selectedType = "Genel";
  String _selectedTargetType = "Tümü";
  String? _selectedGroupId;
  String? _selectedUserId;
  String _searchQuery = "";

  List<Group> _allGroups = [];
  List<Users> _allStudents = [];
  List<Users> _allCoaches = [];
  List<Users> _filteredUsers = [];

  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchUserController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    _searchUserController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchUserController.text;
      _filterUsers();
    });
  }

  void _filterUsers() {
    if (_searchQuery.isEmpty) {
      _filteredUsers = [];
      return;
    }

    final query = _searchQuery.toLowerCase();
    _filteredUsers = [..._allStudents, ..._allCoaches].where((user) {
      return user.first_name.toLowerCase().contains(query) ||
          user.last_name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
    }).toList();
  }

  void _selectUser(Users user) {
    setState(() {
      _selectedUserId = user.app;
      _searchUserController.text =
          "${user.first_name} ${user.last_name} (${user.role})";
      _searchQuery = "";
      _filteredUsers = [];
    });
  }

  void _clearSelectedUser() {
    setState(() {
      _selectedUserId = null;
      _searchUserController.clear();
    });
  }

  String _getCurrentUserId() {
    if (widget.currentUser != null) {
      if (widget.currentUser!.app != null &&
          widget.currentUser!.app.toString().isNotEmpty) {
        return widget.currentUser!.app.toString();
      }
      if (widget.currentUser!.email != null &&
          widget.currentUser!.email.toString().isNotEmpty) {
        return widget.currentUser!.email.toString();
      }
    }
    return "Admin";
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      _showSnackBar("Başlık ve mesaj boş olamaz!");
      return;
    }

    setState(() => _isSearching = true);

    String dbType = _convertTypeToEnglish(_selectedType);
    String recipientId = "";
    String groupsId = "";

    if (_selectedTargetType == "Tümü") {
      recipientId = "all";
      groupsId = "";
    } else if (_selectedTargetType == "Grup" && _selectedGroupId != null) {
      recipientId = _selectedGroupId!;
      groupsId = _selectedGroupId!;
    } else if (_selectedTargetType == "Kullanıcı" && _selectedUserId != null) {
      recipientId = _selectedUserId!;
      groupsId = "";
    }

    if (recipientId.isEmpty) {
      _showSnackBar("Lütfen bir hedef seçin!", isError: true);
      setState(() => _isSearching = false);
      return;
    }

    final notifData = {
      "notifications_id": "NTF-${DateTime.now().millisecondsSinceEpoch}",
      "sender_id": _getCurrentUserId(),
      "recipient_id": recipientId,
      "groups_id": groupsId,
      "title": _titleController.text,
      "message": _messageController.text,
      "type": dbType,
      "is_read": "FALSE",
      "sent_at": DateTime.now().toIso8601String(),
    };

    bool success = await GoogleSheetService.addNotification(notifData);
    setState(() => _isSearching = false);

    if (success) {
      _showSnackBar("✅ Duyuru gönderildi!");
      _titleController.clear();
      _messageController.clear();
      _clearSelectedUser();
      if (_tabController.index == 1) {
        setState(() {});
      }
    } else {
      _showSnackBar("❌ Duyuru gönderilemedi!", isError: true);
    }
  }

  String _convertTypeToEnglish(String turkishType) {
    switch (turkishType) {
      case "Ödeme Hatırlatması":
        return "payment_reminder";
      case "Antrenman İptali":
        return "attendance_alert";
      case "Maç Duyurusu":
        return "announcement";
      case "Acil":
        return "urgent";
      default:
        return "announcement";
    }
  }

  String _getTypeIcon(String type) {
    switch (type) {
      case "payment_reminder":
        return '💰';
      case "attendance_alert":
        return '❌';
      case "announcement":
        return '📢';
      case "urgent":
        return '⚠️';
      default:
        return '📢';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case "payment_reminder":
        return Colors.orange;
      case "attendance_alert":
        return Colors.purple;
      case "announcement":
        return Colors.blue;
      case "urgent":
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = dateString.contains('T')
          ? DateTime.parse(dateString)
          : DateTime.parse(dateString.replaceAll(' ', 'T'));
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 7) return '${date.day}/${date.month}/${date.year}';
      if (diff.inDays > 0) return '${diff.inDays} gün önce';
      if (diff.inHours > 0) return '${diff.inHours} saat önce';
      if (diff.inMinutes > 0) return '${diff.inMinutes} dakika önce';
      return 'Az önce';
    } catch (e) {
      return dateString;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Ana sayfayı yeniden başlatmadan geri dön
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Bildirim Merkezi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Yeni Duyuru", icon: Icon(Icons.send)),
            Tab(text: "Bildirimlerim", icon: Icon(Icons.notifications)),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSendNotificationTab(), _buildNotificationsListTab()],
      ),
    );
  }

  Widget _buildSendNotificationTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        GoogleSheetService.getGroupsCached(),
        GoogleSheetService.getStudentsOnlyCached(),
        GoogleSheetService.getCoachesCached(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.indigo),
                SizedBox(height: 16),
                Text("Veriler yükleniyor..."),
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
                  onPressed: () => setState(() {}),
                  child: const Text("Tekrar Dene"),
                ),
              ],
            ),
          );
        }

        _allGroups = snapshot.data?[0] as List<Group>? ?? [];
        _allStudents = snapshot.data?[1] as List<Users>? ?? [];

        final coachesRaw = snapshot.data?[2] as List<Coach>? ?? [];
        _allCoaches = [];
        for (var coach in coachesRaw) {
          final allUsers = _allStudents;
          final coachUser = allUsers.firstWhere(
            (u) => u.app == coach.user_id,
            orElse: () => Users(
              app: "",
              branches_id: "",
              first_name: "Bilinmeyen",
              last_name: "Antrenör",
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
          if (coachUser.app.isNotEmpty) {
            _allCoaches.add(coachUser);
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Yeni Duyuru Oluştur",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Hedef Seçimi
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Hedef Seçimi",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildTargetChip("Tümü", "Tümü"),
                        const SizedBox(width: 8),
                        _buildTargetChip("Grup", "Grup"),
                        const SizedBox(width: 8),
                        _buildTargetChip("Kullanıcı", "Kullanıcı"),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Grup Seçimi
              if (_selectedTargetType == "Grup")
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Grup Seç",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedGroupId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.group),
                        ),
                        items: _allGroups.map((g) {
                          return DropdownMenuItem(
                            value: g.groups_id,
                            child: Text(g.name),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedGroupId = val),
                      ),
                    ],
                  ),
                ),

              // Kullanıcı Seçimi (Arama ile)
              if (_selectedTargetType == "Kullanıcı")
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Kullanıcı Ara",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedUserId != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: Colors.indigo),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _searchUserController.text,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: _clearSelectedUser,
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            TextField(
                              controller: _searchUserController,
                              decoration: InputDecoration(
                                hintText:
                                    "İsim, soyisim veya e-posta ile ara...",
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () =>
                                            _searchUserController.clear(),
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.indigo,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            if (_filteredUsers.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _filteredUsers.length > 5
                                      ? 5
                                      : _filteredUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = _filteredUsers[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: user.role == "student"
                                            ? Colors.green.shade100
                                            : Colors.orange.shade100,
                                        child: Icon(
                                          user.role == "student"
                                              ? Icons.school
                                              : Icons.sports,
                                          size: 18,
                                        ),
                                      ),
                                      title: Text(
                                        "${user.first_name} ${user.last_name}",
                                      ),
                                      subtitle: Text(user.email),
                                      trailing: Chip(
                                        label: Text(
                                          user.role == "student"
                                              ? "Öğrenci"
                                              : "Antrenör",
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        backgroundColor: user.role == "student"
                                            ? Colors.green.shade100
                                            : Colors.orange.shade100,
                                      ),
                                      onTap: () => _selectUser(user),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Duyuru Tipi
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Duyuru Tipi",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildTypeChip("Genel", Icons.info),
                        _buildTypeChip("Acil", Icons.warning),
                        _buildTypeChip("Ödeme Hatırlatması", Icons.payment),
                        _buildTypeChip("Antrenman İptali", Icons.cancel),
                        _buildTypeChip("Maç Duyurusu", Icons.sports),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Başlık ve Mesaj
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Duyuru İçeriği",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: "Başlık",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: "Mesajınızı yazın...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.message),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Gönder Butonu
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  icon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSearching ? "Gönderiliyor..." : "Duyuruyu Yayınla",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _isSearching ? null : _sendNotification,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTargetChip(String label, String value) {
    bool isSelected = _selectedTargetType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedTargetType = selected ? value : "Tümü";
          if (_selectedTargetType != "Grup") _selectedGroupId = null;
          if (_selectedTargetType != "Kullanıcı") {
            _selectedUserId = null;
            _searchUserController.clear();
          }
        });
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: Colors.indigo.shade100,
      checkmarkColor: Colors.indigo,
      labelStyle: TextStyle(
        color: isSelected ? Colors.indigo : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTypeChip(String label, IconData icon) {
    bool isSelected = _selectedType == label;
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 16),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedType = selected ? label : "Genel";
        });
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: _getColorForType(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case "Acil":
        return Colors.red;
      case "Ödeme Hatırlatması":
        return Colors.orange;
      case "Antrenman İptali":
        return Colors.purple;
      case "Maç Duyurusu":
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Widget _buildNotificationsListTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: GoogleSheetService.getNotificationsForUser(_getCurrentUserId()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.indigo),
                SizedBox(height: 16),
                Text("Bildirimler yükleniyor..."),
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
                Text("Hata: ${snapshot.error}"),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text("Tekrar Dene"),
                ),
              ],
            ),
          );
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
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
                  child: Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Henüz bildirim yok",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  "Yeni bildirimler geldiğinde burada görünecektir",
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final isRead =
                  notif['is_read']?.toString().toUpperCase() == 'TRUE';
              final dbType = notif['type']?.toString() ?? 'announcement';
              final typeColor = _getTypeColor(dbType);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: isRead ? Colors.white : typeColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      if (!isRead) {
                        await GoogleSheetService.markNotificationAsRead(
                          notif['notifications_id'].toString(),
                          notif['recipient_id'].toString(),
                        );
                        setState(() {});
                      }
                      _showNotificationDetail(notif);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                _getTypeIcon(dbType),
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notif['title'] ?? '',
                                        style: TextStyle(
                                          fontWeight: isRead
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: typeColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notif['message'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(notif['sent_at'] ?? ''),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
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
            },
          ),
        );
      },
    );
  }

  void _showNotificationDetail(Map<String, dynamic> notif) {
    final dbType = notif['type']?.toString() ?? 'announcement';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getTypeColor(dbType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      _getTypeIcon(dbType),
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    notif['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              notif['message'] ?? '',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(notif['sent_at'] ?? ''),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Kapat",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/app_notificotions/locaal_notifications_service.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';

class NotificationsScreen extends StatefulWidget {
  final Users? currentUser;

  const NotificationsScreen({super.key, this.currentUser});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchUserController = TextEditingController();

  String _selectedType = "Genel";
  String _selectedTargetType = "Tümü";
  String? _selectedGroupId;
  String? _selectedUserId;
  String _searchQuery = "";

  List<Group> _allGroups = [];
  List<Users> _allUsers = [];
  List<Users> _filteredUsers = [];

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Dinleyiciyi initState içinde tanımlıyoruz
    _searchUserController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    _searchUserController.dispose();
    super.dispose();
  }

  // Klavyenin kapanmaması için setState içindeki mantığı optimize ediyoruz
  void _onSearchChanged() {
    final query = _searchUserController.text;

    // Eğer seçili bir kullanıcı varken metin değişirse (silinirse) seçimi temizle
    if (_selectedUserId != null && !query.contains("(")) {
      setState(() {
        _selectedUserId = null;
      });
    }

    if (query.isEmpty) {
      if (_filteredUsers.isNotEmpty) {
        setState(() {
          _filteredUsers = [];
          _searchQuery = "";
        });
      }
      return;
    }

    final lowerQuery = query.toLowerCase();
    final results = _allUsers.where((user) {
      final fullName = "${user.first_name} ${user.last_name}".toLowerCase();
      final email = user.email.toLowerCase();
      final roleText = _getRoleText(user.role).toLowerCase();
      return fullName.contains(lowerQuery) ||
          email.contains(lowerQuery) ||
          roleText.contains(lowerQuery);
    }).toList();

    setState(() {
      _searchQuery = query;
      _filteredUsers = results;
    });
  }

  void _selectUser(Users user) {
    // Önce listener'ı kaldırıp sonra metni set ediyoruz ki tekrar arama tetiklenmesin
    _searchUserController.removeListener(_onSearchChanged);

    setState(() {
      _selectedUserId = user.app;
      _searchUserController.text =
          "${user.first_name} ${user.last_name} (${_getRoleText(user.role)})";
      _filteredUsers = [];
      _searchQuery = "";
    });

    // Küçük bir gecikme ile listener'ı geri ekliyoruz
    Future.delayed(const Duration(milliseconds: 100), () {
      _searchUserController.addListener(_onSearchChanged);
    });
  }

  void _clearSelectedUser() {
    setState(() {
      _selectedUserId = null;
      _searchUserController.clear();
      _filteredUsers = [];
      _searchQuery = "";
    });
  }

  String _getRoleText(String role) {
    switch (role.toLowerCase()) {
      case "student":
        return "Öğrenci";
      case "coach":
        return "Antrenör";
      case "accountant":
        return "Muhasebeci";
      case "admin":
        return "Admin";
      default:
        return role;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case "student":
        return Icons.school;
      case "coach":
        return Icons.sports;
      case "accountant":
        return Icons.calculate;
      case "admin":
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case "student":
        return Colors.green;
      case "coach":
        return Colors.orange;
      case "accountant":
        return Colors.blue;
      case "admin":
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getCurrentUserId() {
    if (widget.currentUser != null) {
      return widget.currentUser!.app?.toString() ??
          widget.currentUser!.email?.toString() ??
          "Admin";
    }
    return "Admin";
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      _showSnackBar("Başlık ve mesaj boş olamaz!", isError: true);
      return;
    }

    setState(() => _isSending = true);

    String dbType = _convertTypeToEnglish(_selectedType);
    String recipientId = "";
    String groupsId = "";

    if (_selectedTargetType == "Tümü") {
      recipientId = "all";
    } else if (_selectedTargetType == "Grup" && _selectedGroupId != null) {
      recipientId = _selectedGroupId!;
      groupsId = _selectedGroupId!;
    } else if (_selectedTargetType == "Kullanıcı" && _selectedUserId != null) {
      recipientId = _selectedUserId!;
    }

    if (recipientId.isEmpty) {
      _showSnackBar("Lütfen bir hedef seçin!", isError: true);
      setState(() => _isSending = false);
      return;
    }

    final notifData = {
      "notifications_id": "NTF-${DateTime.now().millisecondsSinceEpoch}",
      "sender_id": _getCurrentUserId(),
      "recipient_id": recipientId,
      "groups_id": groupsId,
      "title": _titleController.text,
      "message": _messageController.text,
      "type": dbType,
      "is_read": "FALSE",
      "sent_at": DateTime.now().toIso8601String(),
    };

    bool success = await GoogleSheetService.addNotification(notifData);
    setState(() => _isSending = false);

    if (success) {
      _showSnackBar("✅ Duyuru gönderildi!");
      _titleController.clear();
      _messageController.clear();
      _clearSelectedUser();
    } else {
      _showSnackBar("❌ Duyuru gönderilemedi!", isError: true);
    }
  }

  String _convertTypeToEnglish(String turkishType) {
    switch (turkishType) {
      case "Ödeme Hatırlatması":
        return "payment_reminder";
      case "Antrenman İptali":
        return "attendance_alert";
      case "Maç Duyurusu":
        return "announcement";
      case "Acil":
        return "urgent";
      default:
        return "announcement";
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case "payment_reminder":
        return Colors.orange;
      case "attendance_alert":
        return Colors.purple;
      case "announcement":
        return Colors.blue;
      case "urgent":
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getTypeIcon(String type) {
    switch (type) {
      case "payment_reminder":
        return '💰';
      case "attendance_alert":
        return '❌';
      case "announcement":
        return '📢';
      case "urgent":
        return '⚠️';
      default:
        return '📢';
    }
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString.replaceAll(' ', 'T'));
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 7) return '${date.day}/${date.month}/${date.year}';
      if (diff.inDays > 0) return '${diff.inDays} gün önce';
      if (diff.inHours > 0) return '${diff.inHours} saat önce';
      if (diff.inMinutes > 0) return '${diff.inMinutes} dakika önce';
      return 'Az önce';
    } catch (e) {
      return dateString;
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Bildirim Merkezi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Yeni Duyuru", icon: Icon(Icons.send)),
            Tab(text: "Bildirimlerim", icon: Icon(Icons.notifications)),
          ],
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSendNotificationTab(), _buildNotificationsListTab()],
      ),
    );
  }

  Widget _buildSendNotificationTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        GoogleSheetService.getGroupsCached(),
        GoogleSheetService.getUsersCached(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        _allGroups = snapshot.data![0] as List<Group>;
        final allRawUsers = snapshot.data![1] as List<Users>;

        // Verileri bir kez filtrele
        _allUsers = allRawUsers.where((u) {
          final r = u.role.toLowerCase();
          return ["student", "coach", "accountant", "admin"].contains(r);
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Yeni Duyuru Oluştur",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Hedef Seçimi Kartı
              _buildCard(
                title: "Hedef Seçimi",
                child: Row(
                  children: [
                    _buildTargetChip("Tümü", "Tümü"),
                    const SizedBox(width: 8),
                    _buildTargetChip("Grup", "Grup"),
                    const SizedBox(width: 8),
                    _buildTargetChip("Kullanıcı", "Kullanıcı"),
                  ],
                ),
              ),

              if (_selectedTargetType == "Grup")
                _buildCard(
                  title: "Grup Seç",
                  child: DropdownButtonFormField<String>(
                    value: _selectedGroupId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _allGroups
                        .map(
                          (g) => DropdownMenuItem(
                            value: g.groups_id,
                            child: Text(g.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedGroupId = val),
                  ),
                ),

              if (_selectedTargetType == "Kullanıcı")
                _buildCard(
                  title: "Kullanıcı Ara",
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchUserController,
                        decoration: InputDecoration(
                          hintText: "İsim veya rol ile ara...",
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchUserController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: _clearSelectedUser,
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_filteredUsers.isNotEmpty && _selectedUserId == null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 8),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return ListTile(
                                leading: Icon(
                                  _getRoleIcon(user.role),
                                  color: _getRoleColor(user.role),
                                ),
                                title: Text(
                                  "${user.first_name} ${user.last_name}",
                                ),
                                subtitle: Text(_getRoleText(user.role)),
                                onTap: () => _selectUser(user),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              _buildCard(
                title: "Duyuru Tipi",
                child: Wrap(
                  spacing: 8,
                  children: [
                    "Genel",
                    "Acil",
                    "Ödeme Hatırlatması",
                    "Antrenman İptali",
                    "Maç Duyurusu",
                  ].map((t) => _buildTypeChip(t, Icons.label)).toList(),
                ),
              ),

              const SizedBox(height: 16),
              _buildCard(
                title: "İçerik",
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: "Başlık",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "Mesaj...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isSending ? null : _sendNotification,
                  icon: _isSending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(Icons.send, color: Colors.white),
                  label: Text(
                    _isSending ? "Gönderiliyor..." : "Duyuruyu Yayınla",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTargetChip(String label, String value) {
    bool isSelected = _selectedTargetType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedTargetType = value;
          _clearSelectedUser();
          _selectedGroupId = null;
        });
      },
    );
  }

  Widget _buildTypeChip(String label, IconData icon) {
    bool isSelected = _selectedType == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => setState(() => _selectedType = label),
      selectedColor: _getColorForType(label).withOpacity(0.3),
    );
  }

  Color _getColorForType(String label) {
    if (label == "Acil") return Colors.red;
    if (label == "Ödeme Hatırlatması") return Colors.orange;
    return Colors.blue;
  }

  // Bildirim Listesi Tabı (Kodun devamı senin orijinal mantığınla aynı kalabilir)
  Widget _buildNotificationsListTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: GoogleSheetService.getNotificationsForUser(_getCurrentUserId()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final notifications = snapshot.data ?? [];
        if (notifications.isEmpty)
          return const Center(child: Text("Bildirim yok"));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notif = notifications[index];
            final dbType = notif['type']?.toString() ?? 'announcement';
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getTypeColor(dbType).withOpacity(0.1),
                  child: Text(_getTypeIcon(dbType)),
                ),
                title: Text(
                  notif['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(notif['message'] ?? '', maxLines: 1),
                onTap: () => _showNotificationDetail(notif),
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationDetail(Map<String, dynamic> notif) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notif['title'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(notif['message'] ?? ''),
            const SizedBox(height: 20),
            Text(
              _formatDate(notif['sent_at'] ?? ''),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
