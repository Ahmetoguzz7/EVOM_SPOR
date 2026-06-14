import 'package:EVOM_SPOR/app_notificotions/locaal_notifications_service.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DuyurularPage extends StatefulWidget {
  final Users currentUser;
  final Coach? currentCoach;

  const DuyurularPage({
    super.key,
    required this.currentUser,
    this.currentCoach,
  });

  @override
  State<DuyurularPage> createState() => _DuyurularPageState();
}

class _DuyurularPageState extends State<DuyurularPage> {
  final AppRepository _repo = AppRepository();
  late Future<List<Notifications>> _filteredNotificationsFuture;
  final NotificationService _notificationService = NotificationService();
  Set<int> _readNotificationIds = {};

  // 🔥 FİLTRELEME İÇİN YENİ DEĞİŞKENLER
  String _selectedFilter = "Tümü";
  final List<String> _filterOptions = [
    "Tümü",
    "Genel Duyurular",
    "Kişisel Duyurular",
    "Grup Duyuruları",
    "Ödeme Hatırlatmaları",
    "Acil Duyurular",
    "Okunmamışlar",
  ];

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadDataAndFilter();
  }

  Future<void> _initNotifications() async {
    await _notificationService.init();
    await _notificationService.requestPermission();
    await _loadReadNotifications();
  }

  String _formatRelativeDateTurkish(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Şimdi";
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 30) {
        return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
      }
      if (diff.inDays > 0) {
        return diff.inDays == 1 ? "Dün" : "${diff.inDays} gün önce";
      }
      if (diff.inHours > 0) return "${diff.inHours} saat önce";
      if (diff.inMinutes > 0) return "${diff.inMinutes} dakika önce";
      return "Az önce";
    } catch (e) {
      return dateStr ?? "Şimdi";
    }
  }

  Future<void> _loadReadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final readIds =
        prefs.getStringList('read_notifications_${widget.currentUser.app}') ??
        [];
    _readNotificationIds = readIds.map((id) => int.parse(id)).toSet();
  }

  Future<void> _saveReadNotification(int id) async {
    final prefs = await SharedPreferences.getInstance();
    _readNotificationIds.add(id);
    await prefs.setStringList(
      'read_notifications_${widget.currentUser.app}',
      _readNotificationIds.map((id) => id.toString()).toList(),
    );
  }

  // 🔥🔥🔥 GELİŞMİŞ FİLTRELEME FONKSİYONU 🔥🔥🔥
  Future<List<Notifications>> _getFilteredNotifications() async {
    if (!_repo.isLoaded) {
      await _repo.loadCriticalData();
    }

    final kullaniciId = widget.currentUser.app.toString().trim().toLowerCase();
    final kullaniciRole = widget.currentUser.role.toLowerCase();

    final isStudent = kullaniciRole == 'student' || kullaniciRole == 'öğrenci';
    final isCoach = kullaniciRole == 'coach' || kullaniciRole == 'antrenör';
    final isParent = kullaniciRole == 'parent' || kullaniciRole == 'veli';

    // Öğrencinin gruplarını ve antrenörünü bul
    final myGroups = _repo.getGroupsByStudentId(widget.currentUser.app);
    final myGroupIds = myGroups.map((g) => g.groups_id).toSet();
    final myCoach = _repo.getCoachByStudentId(widget.currentUser.app);
    final myCoachUserId =
        myCoach?.user_id.toString().trim().toLowerCase() ?? '';

    // Antrenörün gruplarını bul (eğer antrenörse)
    String coachIdForFilter = '';
    Set<String> coachGroupIds = {};
    if (isCoach && widget.currentCoach != null) {
      coachIdForFilter = widget.currentCoach!.coach_id
          .toString()
          .trim()
          .toLowerCase();
      final coachGroups = _repo.getGroupsByCoachId(coachIdForFilter);
      coachGroupIds = coachGroups.map((g) => g.groups_id).toSet();
    }

    // Veli için çocukların gruplarını bul
    Set<String> parentGroupIds = {};
    if (isParent) {
      final parentStudents = await GoogleSheetService.getParentStudents();
      final childrenIds = parentStudents
          .where(
            (ps) => ps.parent_id.toString().trim() == widget.currentUser.app,
          )
          .map((ps) => ps.student_id.toString().trim())
          .toSet();

      for (var childId in childrenIds) {
        final childGroups = _repo.getGroupsByStudentId(childId);
        parentGroupIds.addAll(childGroups.map((g) => g.groups_id));
      }
    }

    // Tüm bildirimleri filtrele
    var filtered = _repo.allNotifications.where((d) {
      final recipientId = d.recipient_id?.toString().trim().toLowerCase() ?? '';
      final senderId = d.sender_id?.toString().trim().toLowerCase() ?? '';
      final groupId = d.groups_id?.toString().trim() ?? '';

      // Kendi gönderdiğimiz bildirimleri gösterme
      if (senderId == kullaniciId) return false;

      // SENARYO 1: Genel duyuru
      if (recipientId == 'all' || recipientId == 'tümü') return true;

      // SENARYO 2: Kişiye özel duyuru
      if (recipientId == kullaniciId) return true;

      // SENARYO 3: Öğrenci için - Gruba özel duyuru
      if (isStudent && groupId.isNotEmpty && myGroupIds.contains(groupId)) {
        return true;
      }

      // SENARYO 4: Öğrenci için - Antrenörümden gelen duyuru
      if (isStudent && myCoachUserId.isNotEmpty && senderId == myCoachUserId) {
        return true;
      }

      // SENARYO 5: Antrenör için - Gruba özel duyuru
      if (isCoach && groupId.isNotEmpty && coachGroupIds.contains(groupId)) {
        return true;
      }

      // SENARYO 6: Antrenör için - Kendi ID'sine özel duyuru
      if (isCoach &&
          (recipientId == coachIdForFilter || recipientId == kullaniciId)) {
        return true;
      }

      // SENARYO 7: Veli için - Çocuklarının gruplarına gelen duyurular
      if (isParent && groupId.isNotEmpty && parentGroupIds.contains(groupId)) {
        return true;
      }

      return false;
    }).toList();

    // Tarihe göre sırala (en yeniden en eskiye)
    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(a.sent_at ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b.sent_at ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    // 🔥 SEÇİLEN FİLTREYE GÖRE İKİNCİL FİLTRELEME
    filtered = _applySecondaryFilter(filtered);

    await _sendNotificationsForNewDuyurular(filtered);
    return filtered;
  }

  // 🔥 İKİNCİL FİLTRELEME (UI'dan seçilen filtreye göre)
  List<Notifications> _applySecondaryFilter(List<Notifications> notifications) {
    switch (_selectedFilter) {
      case "Genel Duyurular":
        return notifications.where((n) {
          final recipientId =
              n.recipient_id?.toString().trim().toLowerCase() ?? '';
          return recipientId == 'all' || recipientId == 'tümü';
        }).toList();

      case "Kişisel Duyurular":
        final kullaniciId = widget.currentUser.app
            .toString()
            .trim()
            .toLowerCase();
        return notifications.where((n) {
          final recipientId =
              n.recipient_id?.toString().trim().toLowerCase() ?? '';
          return recipientId == kullaniciId;
        }).toList();

      case "Grup Duyuruları":
        return notifications.where((n) {
          final groupId = n.groups_id?.toString().trim() ?? '';
          return groupId.isNotEmpty && groupId != 'null' && groupId != '0';
        }).toList();

      case "Ödeme Hatırlatmaları":
        return notifications.where((n) {
          return n.type?.toLowerCase() == 'payment_reminder';
        }).toList();

      case "Acil Duyurular":
        return notifications.where((n) {
          return n.type?.toLowerCase() == 'urgent';
        }).toList();

      case "Okunmamışlar":
        return notifications.where((n) {
          return n.is_read?.toLowerCase() != "true";
        }).toList();

      default:
        return notifications;
    }
  }

  Future<void> _loadDataAndFilter() async {
    setState(() {
      _filteredNotificationsFuture = _getFilteredNotifications();
    });
  }

  void _changeFilter(String? filter) {
    if (filter != null && filter != _selectedFilter) {
      setState(() {
        _selectedFilter = filter;
        _filteredNotificationsFuture = _getFilteredNotifications();
      });
    }
  }

  Future<void> _sendNotificationsForNewDuyurular(
    List<Notifications> duyurular,
  ) async {
    for (var duyuru in duyurular) {
      final isRead = duyuru.is_read?.toLowerCase() == "true";
      final notificationId = duyuru.notifications_id.hashCode;
      if (!isRead && !_readNotificationIds.contains(notificationId)) {
        await _notificationService.showNotification(
          id: notificationId.toString(),
          title: _getNotificationTitle(duyuru.type, duyuru.title),
          body: _getNotificationBody(duyuru),
          type: duyuru.type,
          payload: duyuru.notifications_id.toString(),
        );
        await _saveReadNotification(notificationId);
      }
    }
  }

  String _getNotificationTitle(String? type, String title) {
    switch (type?.toLowerCase()) {
      case 'payment_reminder':
        return '💰 Ödeme Hatırlatması';
      case 'urgent':
        return '⚠️ Acil Duyuru';
      case 'announcement':
        return '📢 Yeni Duyuru';
      case 'attendance_alert':
        return '❌ Antrenman İptali';
      default:
        return '🔔 $title';
    }
  }

  String _getNotificationBody(Notifications duyuru) {
    String message = duyuru.message;
    if (message.length > 100) message = message.substring(0, 100) + '...';
    return message;
  }

  Future<void> _markAsRead(Notifications duyuru) async {
    if (duyuru.is_read?.toLowerCase() == "true") return;
    await GoogleSheetService.markNotificationAsRead(
      duyuru.notifications_id,
      widget.currentUser.app,
    );
    GoogleSheetService.invalidateCache('notifications');
    setState(() => _filteredNotificationsFuture = _getFilteredNotifications());
  }

  Future<void> _refreshNotifications() async {
    GoogleSheetService.invalidateCache('notifications');
    await _repo.refreshAllData();
    setState(() {
      _filteredNotificationsFuture = _getFilteredNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Duyurular & Bildirimler",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshNotifications,
            tooltip: "Yenile",
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: _changeFilter,
            itemBuilder: (context) => _filterOptions.map((filter) {
              return PopupMenuItem(
                value: filter,
                child: Row(
                  children: [
                    Icon(
                      filter == _selectedFilter
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: filter == _selectedFilter
                          ? Colors.indigo
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(filter),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: FutureBuilder<List<Notifications>>(
        future: _filteredNotificationsFuture,
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
                  Text("Hata: ${snapshot.error}"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshNotifications,
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            );
          }
          final filteredNotifications = snapshot.data ?? [];
          if (filteredNotifications.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // 🔥 FİLTRE BİLGİSİ (KÜÇÜLTÜLMÜŞ)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.filter_alt,
                      size: 12,
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Filtre: $_selectedFilter",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${filteredNotifications.length}",
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredNotifications.length,
                  itemBuilder: (context, index) {
                    final duyuru = filteredNotifications[index];
                    return GestureDetector(
                      onTap: () => _markAsRead(duyuru),
                      child: _buildDuyuruCard(duyuru),
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

  // 🔥 KÜÇÜLTÜLMÜŞ DUYURU KARTI
  Widget _buildDuyuruCard(Notifications duyuru) {
    bool isUnread = duyuru.is_read?.toLowerCase() != "true";
    bool isUrgent = duyuru.type?.toLowerCase() == "urgent";
    bool hasGroup =
        duyuru.groups_id != null &&
        duyuru.groups_id!.isNotEmpty &&
        duyuru.groups_id != 'null';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isUnread ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isUnread || isUrgent
            ? Border.all(
                color: isUrgent
                    ? Colors.red.withOpacity(0.3)
                    : _getIconColor(duyuru.type).withOpacity(0.3),
                width: isUrgent ? 1.5 : 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _markAsRead(duyuru),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // İkon (küçültüldü)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getIconColor(duyuru.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getIcon(duyuru.type),
                    color: _getIconColor(duyuru.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                // İçerik
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              duyuru.title,
                              style: TextStyle(
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 13,
                                color: isUrgent
                                    ? Colors.red.shade800
                                    : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUrgent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "Acil",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          if (isUnread && !isUrgent)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        duyuru.message,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (hasGroup)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.group,
                                    size: 9,
                                    color: Colors.purple,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    "Grup",
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getIconColor(
                                duyuru.type,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getTypeDisplay(duyuru.type),
                              style: TextStyle(
                                fontSize: 9,
                                color: _getIconColor(duyuru.type),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 9,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatRelativeDateTurkish(duyuru.sent_at),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
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

  String _getTypeDisplay(String? type) {
    switch (type?.toLowerCase()) {
      case 'payment_reminder':
        return 'Ödeme';
      case 'attendance_alert':
        return 'İptal';
      case 'announcement':
        return 'Duyuru';
      case 'urgent':
        return 'Acil';
      default:
        return 'Duyuru';
    }
  }

  IconData _getIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'payment_reminder':
        return Icons.account_balance_wallet;
      case 'urgent':
        return Icons.priority_high;
      case 'announcement':
        return Icons.emoji_events;
      case 'attendance_alert':
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'payment_reminder':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      case 'announcement':
        return Colors.green;
      case 'attendance_alert':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 70,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            "Henüz bir duyuru bulunmuyor.",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            "Farklı bir filtre seçmeyi deneyin",
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
        ],
      ),
    );
  }
}
