import 'package:EVOM_SPOR/app_notificotions/locaal_notifications_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

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
  late Future<List<Notifications>> _notificationsFuture;
  String _selectedFilter = "Son 7 gün";
  final List<String> _filterOptions = [
    "Son 7 gün",
    "Son 30 gün",
    "Son 3 ay",
    "Tümü",
  ];

  final NotificationService _notificationService = NotificationService();
  List<Notifications> _previousNotifications = [];

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _notificationsFuture = _loadNotifications();
  }

  Future<void> _initNotifications() async {
    await _notificationService.init();
    await _notificationService.requestPermission();
  }

  // =========================================================================
  // 🔥 TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

  String _formatDateLongTurkish(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMMM yyyy HH:mm', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateShortTurkish(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatRelativeDateTurkish(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Şimdi";
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 30) {
        final formatter = DateFormat('dd MMM yyyy', 'tr_TR');
        return formatter.format(date);
      }
      if (diff.inDays > 0) {
        if (diff.inDays == 1) return "Dün";
        return "${diff.inDays} geomagnetic gün önce";
      }
      if (diff.inHours > 0) {
        return "${diff.inHours} saat önce";
      }
      if (diff.inMinutes > 0) {
        return "${diff.inMinutes} dakika önce";
      }
      return "Az önce";
    } catch (e) {
      return dateStr ?? "Şimdi";
    }
  }

  String _formatDateOnlyTurkish(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<List<Notifications>> _loadNotifications() async {
    final String currentUserIdStr = widget.currentUser.app.toString().trim();

    // fetch_data_page içindeki 4 bildirim bulan zırhlı fonksiyonu çağırıyoruz
    final List<Map<String, dynamic>> rawFilteredMaps =
        await GoogleSheetService.getNotificationsForUser(currentUserIdStr);

    final List<Notifications> filteredNotifications = rawFilteredMaps.map((
      item,
    ) {
      return Notifications(
        notifications_id: item['notifications_id']?.toString() ?? '',
        sender_id: item['sender_id']?.toString() ?? '',
        recipient_id: item['recipient_id']?.toString() ?? '',
        groups_id: item['groups_id']?.toString() ?? '',
        title: item['title']?.toString() ?? '',
        message: item['message']?.toString() ?? '',
        type: item['type']?.toString() ?? 'announcement',
        is_read: item['is_read']?.toString() ?? 'FALSE',
        sent_at: item['sent_at']?.toString() ?? '',
      );
    }).toList();

    await _checkAndSendNotifications(filteredNotifications);

    // Tarih süzgecine gönder
    return _filterByDate(filteredNotifications);
  }

  // 🚀 YENİ DUYURULAR İÇİN BİLDİRİM GÖNDER
  Future<void> _checkAndSendNotifications(
    List<Notifications> currentNotifications,
  ) async {
    final previousIds = _previousNotifications
        .map((n) => n.notifications_id)
        .toSet();
    final currentIds = currentNotifications
        .map((n) => n.notifications_id)
        .toSet();

    final newNotificationIds = currentIds.difference(previousIds);
    final newNotifications = currentNotifications
        .where((n) => newNotificationIds.contains(n.notifications_id))
        .toList();

    final unreadNotifications = currentNotifications
        .where((n) => n.is_read?.toLowerCase() != "true")
        .toList();

    final notificationsToSend = {
      ...newNotifications,
      ...unreadNotifications,
    }.toList();

    for (var duyuru in notificationsToSend) {
      final notificationId =
          "${duyuru.notifications_id}_${widget.currentUser.app}";

      if (duyuru.is_read?.toLowerCase() != "true") {
        await _notificationService.showNotification(
          id: notificationId,
          title: _getNotificationTitle(duyuru.type, duyuru.title),
          body: _getNotificationBody(duyuru),
          type: duyuru.type,
          payload: '${duyuru.notifications_id}',
        );
      }
    }

    _previousNotifications = List.from(currentNotifications);
  }

  String _getNotificationTitle(String type, String title) {
    switch (type.toLowerCase()) {
      case 'payment_reminder':
        return '💰 Ödeme Hatırlatması';
      case 'urgent':
        return '⚠️ ACİL Duyuru';
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
    if (message.length > 100) {
      message = '${message.substring(0, 100)}...';
    }
    return message;
  }

  List<Notifications> _filterByDate(List<Notifications> list) {
    if (_selectedFilter == "Tümü") return list;

    final now = DateTime.now();
    Duration limit;

    switch (_selectedFilter) {
      case "Son 7 gün":
        limit = const Duration(days: 7);
        break;
      case "Son 30 gün":
        limit = const Duration(days: 30);
        break;
      case "Son 3 ay":
        limit = const Duration(days: 90);
        break;
      default:
        return list;
    }

    final cutoff = now.subtract(limit);

    return list.where((notif) {
      if (notif.sent_at.isEmpty || notif.sent_at == 'null') {
        return true; // Tarihi boş olan test verilerini ekrandan silme, göster!
      }

      // Farklı tarih formatlarını (GG.AA.YYYY veya YYYY-AA-GG) tolere etmek için güvenli parse
      DateTime? notifDate = DateTime.tryParse(notif.sent_at);
      if (notifDate == null) {
        try {
          // Eğer GG.AA.YYYY formatındaysa manuel parçala
          final parts = notif.sent_at.split('.');
          if (parts.length == 3) {
            notifDate = DateTime(
              int.parse(parts[2].split(' ')[0]), // Yıl
              int.parse(parts[1]), // Ay
              int.parse(parts[0]), // Gün
            );
          }
        } catch (_) {
          return true; // Tarih formatı bozuksa bile bildirimi kaybetme, listele!
        }
      }

      if (notifDate == null) return true;
      return notifDate.isAfter(cutoff);
    }).toList();
  }

  Future<void> _markAsRead(Notifications duyuru) async {
    if (duyuru.is_read?.toLowerCase() == "true") return;

    await GoogleSheetService.markNotificationAsRead(
      duyuru.notifications_id,
      widget.currentUser.app,
    );

    GoogleSheetService.invalidateCache('notifications');
    setState(() {
      _notificationsFuture = _loadNotifications();
    });
  }

  void _changeFilter(String? filter) {
    if (filter != null && filter != _selectedFilter) {
      setState(() {
        _selectedFilter = filter;
        _notificationsFuture = _loadNotifications();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
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
            onPressed: () {
              GoogleSheetService.invalidateCache('notifications');
              setState(() {
                _notificationsFuture = _loadNotifications();
              });
            },
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
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text("Duyurular yükleniyor..."),
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
                  const Text("Duyurular yüklenirken hata oluştu"),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      GoogleSheetService.invalidateCache('notifications');
                      setState(() {
                        _notificationsFuture = _loadNotifications();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Tekrar Dene"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              GoogleSheetService.invalidateCache('notifications');
              setState(() {
                _notificationsFuture = _loadNotifications();
              });
              await _notificationsFuture;
            },
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.indigo,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedFilter,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${notifications.length} duyuru",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final duyuru = notifications[index];
                      return GestureDetector(
                        onTap: () => _markAsRead(duyuru),
                        child: _buildDuyuruCard(duyuru),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDuyuruCard(Notifications duyuru) {
    bool isUnread = duyuru.is_read?.toLowerCase() != "true";
    bool hasGroup =
        duyuru.groups_id != null &&
        duyuru.groups_id!.isNotEmpty &&
        duyuru.groups_id != 'null';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isUnread
            ? Border.all(
                color: _getIconColor(duyuru.type).withOpacity(0.3),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _markAsRead(duyuru),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getIconColor(duyuru.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getIcon(duyuru.type),
                    color: _getIconColor(duyuru.type),
                    size: 28,
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
                              duyuru.title,
                              style: TextStyle(
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getIconColor(duyuru.type),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        duyuru.message,
                        style: TextStyle(color: Colors.grey[600], height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // 🔥 GRUP ETİKETİ EKLENDİ
                          if (hasGroup)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.group,
                                    size: 10,
                                    color: Colors.purple,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Grup Duyurusu",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.purple,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (hasGroup) const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getIconColor(
                                duyuru.type,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getTypeDisplay(duyuru.type),
                              style: TextStyle(
                                fontSize: 10,
                                color: _getIconColor(duyuru.type),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatRelativeDateTurkish(duyuru.sent_at),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
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

  String _getTypeDisplay(String type) {
    switch (type.toLowerCase()) {
      case 'payment_reminder':
        return 'Ödeme Hatırlatması';
      case 'attendance_alert':
        return 'Antrenman İptali';
      case 'announcement':
        return 'Duyuru';
      case 'urgent':
        return 'Acil';
      default:
        return type;
    }
  }

  IconData _getIcon(String type) {
    switch (type.toLowerCase()) {
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

  Color _getIconColor(String type) {
    switch (type.toLowerCase()) {
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz bir duyuru bulunmuyor.",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "Yeni duyurular geldiğinde burada görünecektir",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
