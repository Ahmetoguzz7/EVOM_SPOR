import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'dart:core';
import 'package:intl/intl.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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
  bool _sendLocalNotification = true;

  // 🔥 BEYAZ TEMA RENKLERİ
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _surfaceLight = Color(0xFFF1F5F9);
  static const Color _accent = Color(0xFF0EA5E9);
  static const Color _accentDark = Color(0xFF0284C7);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF22C55E);
  static const Color _warning = Color(0xFFF97316);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _info = Color(0xFF3B82F6);
  static const Color _purple = Color(0xFF8B5CF6);

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

  // =========================================================================
  // 🔥 TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

  String _formatDateTurkish(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString.replaceAll(' ', 'T'));
      final now = DateTime.now();
      final diff = now.difference(date);

      // Türkçe format için
      final formatter = DateFormat('dd MMMM yyyy HH:mm', 'tr_TR');

      if (diff.inDays > 7) {
        return formatter.format(date);
      }
      if (diff.inDays > 0) {
        return '${diff.inDays} gün önce';
      }
      if (diff.inHours > 0) {
        return '${diff.inHours} saat önce';
      }
      if (diff.inMinutes > 0) {
        return '${diff.inMinutes} dakika önce';
      }
      return 'Az önce';
    } catch (e) {
      return dateString;
    }
  }

  // Kısa tarih formatı (sadece gün/ay/yıl)
  String _formatDateShortTurkish(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString.replaceAll(' ', 'T'));
      final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateString;
    }
  }

  // Uzun tarih formatı (gün ay yıl saat:dakika)
  String _formatDateLongTurkish(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString.replaceAll(' ', 'T'));
      final formatter = DateFormat('dd MMMM yyyy HH:mm', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateString;
    }
  }

  void _onSearchChanged() {
    final query = _searchUserController.text;
    if (_selectedUserId != null && !query.contains("(")) {
      setState(() => _selectedUserId = null);
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
    _searchUserController.removeListener(_onSearchChanged);
    setState(() {
      _selectedUserId = user.app;
      _searchUserController.text =
          "${user.first_name} ${user.last_name} (${_getRoleText(user.role)})";
      _filteredUsers = [];
      _searchQuery = "";
    });
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
        return _success;
      case "coach":
        return _warning;
      case "accountant":
        return _info;
      case "admin":
        return _purple;
      default:
        return _textSecondary;
    }
  }

  String _getCurrentUserId() {
    if (widget.currentUser != null) {
      return widget.currentUser!.app?.toString() ?? "Admin";
    }
    return "Admin";
  }

  Future<void> _showLocalNotification(String title, String message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'evom_spor_channel',
          'EVOM SPOR Bildirimleri',
          channelDescription: 'Spor salonu duyuruları ve bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          showWhen: true,
          enableVibration: true,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: message,
      notificationDetails: notificationDetails,
    );
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

    // 🔥 HEDEF YAPISI
    if (_selectedTargetType == "Tümü") {
      recipientId = "all";
      groupsId = "";
    } else if (_selectedTargetType == "Grup" && _selectedGroupId != null) {
      recipientId = "group";
      groupsId = _selectedGroupId!;
    } else if (_selectedTargetType == "Kullanıcı" && _selectedUserId != null) {
      recipientId = _selectedUserId!;
      groupsId = "";
    }

    if (recipientId.isEmpty) {
      _showSnackBar("Lütfen bir hedef seçin!", isError: true);
      setState(() => _isSending = false);
      return;
    }

    final currentUserId = _getCurrentUserId();

    // 🔥🔥🔥 KENDİNE BİLDİRİM GÖNDERMEYİ ENGELLE 🔥🔥🔥
    if (recipientId == currentUserId) {
      _showSnackBar("❌ Kendinize bildirim gönderemezsiniz!", isError: true);
      setState(() => _isSending = false);
      return;
    }

    // Eğer "Kullanıcı" seçiliyse ve seçilen kullanıcı kendisiyse tekrar kontrol
    if (_selectedTargetType == "Kullanıcı" &&
        _selectedUserId == currentUserId) {
      _showSnackBar("❌ Kendinize bildirim gönderemezsiniz!", isError: true);
      setState(() => _isSending = false);
      return;
    }

    final notifData = {
      "notifications_id": "NTF-${DateTime.now().millisecondsSinceEpoch}",
      "sender_id": currentUserId,
      "recipient_id": recipientId,
      "groups_id": groupsId,
      "title": _titleController.text,
      "message": _messageController.text,
      "type": dbType,
      "is_read": "FALSE",
      "sent_at": DateTime.now().toIso8601String(),
    };

    // SADECE VERİTABANINA KAYDET, TELEFONA BİLDİRİM GÖNDERME
    bool dbSuccess = await GoogleSheetService.addNotification(notifData);

    setState(() => _isSending = false);

    if (dbSuccess) {
      _showSnackBar("✅ Duyuru başarıyla gönderildi!");
      _titleController.clear();
      _messageController.clear();
      _clearSelectedUser();
      setState(() {});
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
        return _warning;
      case "attendance_alert":
        return _purple;
      case "announcement":
        return _info;
      case "urgent":
        return _danger;
      default:
        return _info;
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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _danger : _success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Text(
          "Bildirim Paneli ",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: _textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: _accent,
          unselectedLabelColor: _textSecondary,
          tabs: const [
            Tab(text: "Yeni Duyuru", icon: Icon(Icons.send, size: 18)),
            Tab(
              text: "Bildirimlerim",
              icon: Icon(Icons.notifications, size: 18),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSendNotificationTab(), _buildNotificationsListTab()],
      ),
    );
  }

  // 🚀 PARALEL VERİ ÇEKEN YENİ METOD
  Future<Map<String, dynamic>> _loadDataParallel() async {
    final stopwatch = Stopwatch()..start();

    final results = await Future.wait([
      GoogleSheetService.getGroupsCached(),
      GoogleSheetService.getUsersCached(),
    ]);

    stopwatch.stop();
    /* print(
      "⏱️ Bildirim sayfası verileri PARALEL olarak ${stopwatch.elapsedMilliseconds}ms'de yüklendi",
    );*/

    return {
      'groups': results[0] as List<Group>,
      'users': results[1] as List<Users>,
    };
  }

  Widget _buildSendNotificationTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadDataParallel(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        _allGroups = snapshot.data!['groups'] as List<Group>;
        final allRawUsers = snapshot.data!['users'] as List<Users>;
        _allUsers = allRawUsers.where((u) {
          final r = u.role.toLowerCase();
          return ["student", "coach", "accountant", "admin"].contains(r);
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Telefona Bildirim Switch Kartı
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.notifications_active,
                            color: _accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Telefona Bildirim Gönder",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              "Açıkken bildirim telefonunuza da gelir",
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _sendLocalNotification,
                      onChanged: (val) =>
                          setState(() => _sendLocalNotification = val),
                      activeColor: _accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Hedef Seçimi Kartı
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.people_alt_rounded,
                            color: _accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Hedef Seçimi",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildTargetButton(
                          "Tümü",
                          Icons.public_rounded,
                          "Tümü",
                          _accent,
                        ),
                        const SizedBox(width: 12),
                        _buildTargetButton(
                          "Grup",
                          Icons.group_rounded,
                          "Grup",
                          _purple,
                        ),
                        const SizedBox(width: 12),
                        _buildTargetButton(
                          "Kullanıcı",
                          Icons.person_rounded,
                          "Kullanıcı",
                          _info,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Grup Seç (eğer grup seçiliyse)
              if (_selectedTargetType == "Grup")
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.group_rounded,
                              color: _purple,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Grup Seç",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedGroupId,
                        decoration: InputDecoration(
                          hintText: "Grup seçin",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
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
                        onChanged: (val) =>
                            setState(() => _selectedGroupId = val),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Kullanıcı Ara (eğer kullanıcı seçiliyse)
              if (_selectedTargetType == "Kullanıcı")
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _info.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.search_rounded,
                              color: _info,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Kullanıcı Ara",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchUserController,
                        style: const TextStyle(color: _textPrimary),
                        decoration: InputDecoration(
                          hintText: "İsim, email veya rol ile ara...",
                          hintStyle: TextStyle(color: _textSecondary),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: _textSecondary,
                            size: 20,
                          ),
                          suffixIcon: _searchUserController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: _textSecondary,
                                    size: 18,
                                  ),
                                  onPressed: _clearSelectedUser,
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      if (_filteredUsers.isNotEmpty && _selectedUserId == null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
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
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  _getRoleText(user.role),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () => _selectUser(user),
                              );
                            },
                          ),
                        ),
                      if (_selectedUserId != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: _accent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Seçili: $_selectedUserId",
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: _clearSelectedUser,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Duyuru Tipi Kartı
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.label_important_rounded,
                            color: _info,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Duyuru Tipi",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTypeButton("Genel", Icons.info_rounded, _info),
                        _buildTypeButton(
                          "Acil",
                          Icons.warning_rounded,
                          _danger,
                        ),
                        _buildTypeButton(
                          "Ödeme Hatırlatması",
                          Icons.money_rounded,
                          _warning,
                        ),
                        _buildTypeButton(
                          "Antrenman İptali",
                          Icons.sports_rounded,
                          _purple,
                        ),
                        _buildTypeButton(
                          "Maç Duyurusu",
                          Icons.emoji_events_rounded,
                          _accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // İçerik Kartı
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.edit_note_rounded,
                            color: _accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "İçerik",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: _textPrimary),
                      decoration: InputDecoration(
                        hintText: "Başlık",
                        hintStyle: TextStyle(color: _textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      maxLines: 4,
                      style: const TextStyle(color: _textPrimary),
                      decoration: InputDecoration(
                        hintText: "Mesajınızı yazın...",
                        hintStyle: TextStyle(color: _textSecondary),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Gönder Butonu
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSending ? null : _sendNotification,
                  child: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.send, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Duyuruyu Yayınla",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTargetButton(
    String label,
    IconData icon,
    String value,
    Color color,
  ) {
    final isSelected = _selectedTargetType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTargetType = value;
            _clearSelectedUser();
            _selectedGroupId = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : _surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? color : _border, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : _textSecondary, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, IconData icon, Color color) {
    final isSelected = _selectedType == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : _surfaceLight,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? color : _border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : _textSecondary, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NotificationsScreen.dart - Bildirimleri gösterirken

  // _buildNotificationsListTab fonksiyonunu DEĞİŞTİR:
  // 🔥 MÜDÜR/YÖNETİCİ PANELİNDEKİ LİSTELEME FİLTRESİ (BUNUNLA DEĞİŞTİR)
  Widget _buildNotificationsListTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      // Gönderen kim olursa olsun, sadece bu kullanıcının alıcı (recipient_id) olduğu verileri getirir
      future: GoogleSheetService.getNotificationsForUser(_getCurrentUserId()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text("Bildirimler yüklenirken hata oluştu"),
                const SizedBox(height: 8),
                TextButton(
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
                Icon(
                  Icons.notifications_off_rounded,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  "Henüz bildirim yok",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notif = notifications[index];
            final dbType = notif['type']?.toString() ?? 'announcement';
            final color = _getTypeColor(dbType);
            final icon = _getTypeIcon(dbType);
            final isRead = notif['is_read']?.toString().toUpperCase() == 'TRUE';

            // Gönderen bilgisini kontrol et (Sadece "Siz" etiketini basmak için, filtreyi etkilemez)
            final senderId = notif['sender_id']?.toString() ?? '';
            final isOwnNotification = senderId == _getCurrentUserId();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isRead ? _border : color.withOpacity(0.3),
                  width: isRead ? 1 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showNotificationDetail(notif),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              icon,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
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
                                            ? FontWeight.w600
                                            : FontWeight.bold,
                                        fontSize: 15,
                                        color: _textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isOwnNotification)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        "Siz",
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notif['message'] ?? '',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatDateTurkish(notif['sent_at'] ?? ''),
                                style: TextStyle(
                                  color: _textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationDetail(Map<String, dynamic> notif) {
    final dbType = notif['type']?.toString() ?? 'announcement';
    final color = _getTypeColor(dbType);
    final icon = _getTypeIcon(dbType);
    final formattedDate = _formatDateLongTurkish(notif['sent_at'] ?? '');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif['title'] ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      notif['message'] ?? '',
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: _accent.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        "Kapat",
                        style: TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
