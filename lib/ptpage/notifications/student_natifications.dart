/*
import 'package:EVOM_SPOR/app_notificotions/locaal_notifications_service.dart';
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DuyurularPage extends StatefulWidget {
  final List<Notifications> tumDuyurular;
  final Users currentUser;
  final Coach? currentCoach;

  const DuyurularPage({
    super.key,
    required this.tumDuyurular,
    required this.currentUser,
    this.currentCoach,
  });

  @override
  State<DuyurularPage> createState() => _DuyurularPageState();
}

class _DuyurularPageState extends State<DuyurularPage> {
  late Future<List<Notifications>> _filteredNotificationsFuture;
  final NotificationService _notificationService = NotificationService();

  // Okunan bildirim ID'lerini saklamak için
  Set<int> _readNotificationIds = {};

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _filteredNotificationsFuture = _getFilteredNotifications();
  }

  Future<void> _initNotifications() async {
    await _notificationService.init();
    await _notificationService.requestPermission();
    await _loadReadNotifications();
  }

  // Okunan bildirimleri yükle
  Future<void> _loadReadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final readIds = prefs.getStringList('read_notifications') ?? [];
    _readNotificationIds = readIds.map((id) => int.parse(id)).toSet();
  }

  // Okunan bildirimi kaydet
  Future<void> _saveReadNotification(int id) async {
    final prefs = await SharedPreferences.getInstance();
    _readNotificationIds.add(id);
    final readIds = _readNotificationIds.map((id) => id.toString()).toList();
    await prefs.setStringList('read_notifications', readIds);
  }

  Future<List<Notifications>> _getFilteredNotifications() async {
    List<String> kullaniciGruplari = [];

    // 🔥 COACH İÇİN GRUPLARI BUL
    if (widget.currentCoach != null &&
        widget.currentCoach!.coach_id.isNotEmpty) {
      final groups = await GoogleSheetService.getGroupsByCoach(
        widget.currentCoach!.coach_id,
      );
      kullaniciGruplari = groups.map((g) => g.groups_id.toString()).toList();
      print("📚 Antrenörün grupları: $kullaniciGruplari");
    }
    // 🔥 STUDENT İÇİN GRUPLARI BUL
    else {
      final groupRelations =
          await GoogleSheetService.getGroupStudentsByStudentId(
            widget.currentUser.app,
          );
      kullaniciGruplari = groupRelations
          .where((rel) => rel.is_active.toString().toUpperCase() == "TRUE")
          .map((rel) => rel.groups_id.toString())
          .toList();
      print("📚 Öğrencinin aktif grupları: $kullaniciGruplari");
    }

    // Duyuruları filtrele
    final kullaniciId = widget.currentUser.app;

    final filtered = widget.tumDuyurular.where((d) {
      final recipientId = d.recipient_id;
      print("Duyuru: ${d.title}");
      print("   recipient_id: '$recipientId'");

      final recipientIdStr = recipientId?.toString() ?? '';
      final kullaniciIdStr = kullaniciId.toString();

      final shouldAdd =
          recipientIdStr == 'all' || recipientIdStr == kullaniciIdStr;

      print("   -> ${shouldAdd ? "EKLE" : "EKLEME"}");
      return shouldAdd;
    }).toList();

    // 🔔 YENİ DUYURULAR İÇİN BİLDİRİM GÖNDER
    await _sendNotificationsForNewDuyurular(filtered);

    print("📊 Bulunan: ${filtered.length} duyuru");
    return filtered;
  }

  // 🚀 YENİ DUYURULAR İÇİN BİLDİRİM GÖNDER
  Future<void> _sendNotificationsForNewDuyurular(
    List<Notifications> duyurular,
  ) async {
    for (var duyuru in duyurular) {
      // Duyuru okunmamışsa ve daha önce bildirim gönderilmemişse
      final isRead = duyuru.is_read?.toLowerCase() == "true";
      final notificationId = duyuru.notifications_id.hashCode;

      if (!isRead && !_readNotificationIds.contains(notificationId)) {
        // Bildirim gönder
        await _notificationService.showNotification(
          id: notificationId.toString(),
          title: _getNotificationTitle(duyuru.type, duyuru.title),
          body: _getNotificationBody(duyuru),
          payload: duyuru.notifications_id.toString(),
        );

        // Bildirim gönderildi olarak işaretle
        await _saveReadNotification(notificationId);

        print("🔔 Bildirim gönderildi: ${duyuru.title}");
      }
    }
  }

  String _getNotificationTitle(String type, String title) {
    switch (type.toLowerCase()) {
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
    if (message.length > 100) {
      message = message.substring(0, 100) + '...';
    }
    return message;
  }

  DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return DateTime(2000);
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime(2000);
    }
  }

  Future<void> _markAsRead(Notifications duyuru) async {
    if (duyuru.is_read?.toLowerCase() == "true") return;

    await GoogleSheetService.markNotificationAsRead(
      duyuru.notifications_id,
      widget.currentUser.app,
    );

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
                    onPressed: () {
                      setState(() {
                        _filteredNotificationsFuture =
                            _getFilteredNotifications();
                      });
                    },
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredNotifications.length,
            itemBuilder: (context, index) {
              final duyuru = filteredNotifications[index];
              return GestureDetector(
                onTap: () => _markAsRead(duyuru),
                child: _buildDuyuruCard(duyuru),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDuyuruCard(Notifications duyuru) {
    bool isUnread = duyuru.is_read?.toLowerCase() != "true";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isUnread
            ? Border.all(
                color: _getIconColor(duyuru.type).withOpacity(0.3),
                width: 1.5,
              )
            : Border.all(color: Colors.transparent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: _getIconColor(duyuru.type).withOpacity(0.1),
          child: Icon(_getIcon(duyuru.type), color: _getIconColor(duyuru.type)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                duyuru.title,
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            if (isUnread)
              const Icon(
                Icons.fiber_manual_record,
                color: Colors.blue,
                size: 12,
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                duyuru.message,
                style: TextStyle(color: Colors.grey[700], height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tip: ${_getTypeDisplay(duyuru.type)}",
                    style: TextStyle(
                      fontSize: 11,
                      color: _getIconColor(duyuru.type),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatDate(duyuru.sent_at),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Şimdi";
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) return "${diff.inDays} gün önce";
      if (diff.inHours > 0) return "${diff.inHours} saat önce";
      if (diff.inMinutes > 0) return "${diff.inMinutes} dakika önce";
      return "Şimdi";
    } catch (e) {
      return "Şimdi";
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
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "Henüz bir duyuru bulunmuyor.",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
*/
import 'package:EVOM_SPOR/app_notificotions/locaal_notifications_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DuyurularPage extends StatefulWidget {
  final List<Notifications> tumDuyurular;
  final Users currentUser;
  final Coach? currentCoach;

  const DuyurularPage({
    super.key,
    required this.tumDuyurular,
    required this.currentUser,
    this.currentCoach,
  });

  @override
  State<DuyurularPage> createState() => _DuyurularPageState();
}

class _DuyurularPageState extends State<DuyurularPage> {
  late Future<List<Notifications>> _filteredNotificationsFuture;
  final NotificationService _notificationService = NotificationService();

  // Okunan bildirim ID'lerini saklamak için
  Set<int> _readNotificationIds = {};

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _filteredNotificationsFuture = _getFilteredNotifications();
  }

  Future<void> _initNotifications() async {
    await _notificationService.init();
    await _notificationService.requestPermission();
    await _loadReadNotifications();
  }

  // =========================================================================
  // 🔥 TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

  // Göreceli tarih (bugün, dün, 5 gün önce, 2 saat önce...)
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
        return "${diff.inDays} gün önce";
      }
      if (diff.inHours > 0) {
        return "${diff.inHours} saat önce";
      }
      if (diff.inMinutes > 0) {
        return "${diff.inMinutes} dakika önce";
      }
      return "Az önce";
    } catch (e) {
      return dateStr;
    }
  }

  // Uzun tarih formatı (dd MMMM yyyy HH:mm)
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

  // Kısa tarih formatı (dd MMM yyyy)
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

  // Okunan bildirimleri yükle
  Future<void> _loadReadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final readIds = prefs.getStringList('read_notifications') ?? [];
    _readNotificationIds = readIds.map((id) => int.parse(id)).toSet();
  }

  // Okunan bildirimi kaydet
  Future<void> _saveReadNotification(int id) async {
    final prefs = await SharedPreferences.getInstance();
    _readNotificationIds.add(id);
    final readIds = _readNotificationIds.map((id) => id.toString()).toList();
    await prefs.setStringList('read_notifications', readIds);
  }

  Future<List<Notifications>> _getFilteredNotifications() async {
    List<String> kullaniciGruplari = [];

    // 🔥 COACH İÇİN GRUPLARI BUL
    if (widget.currentCoach != null &&
        widget.currentCoach!.coach_id.isNotEmpty) {
      final groups = await GoogleSheetService.getGroupsByCoach(
        widget.currentCoach!.coach_id,
      );
      kullaniciGruplari = groups.map((g) => g.groups_id.toString()).toList();
      print("📚 Antrenörün grupları: $kullaniciGruplari");
    }
    // 🔥 STUDENT İÇİN GRUPLARI BUL
    else {
      final groupRelations =
          await GoogleSheetService.getGroupStudentsByStudentId(
            widget.currentUser.app,
          );
      kullaniciGruplari = groupRelations
          .where((rel) => rel.is_active.toString().toUpperCase() == "TRUE")
          .map((rel) => rel.groups_id.toString())
          .toList();
      print("📚 Öğrencinin aktif grupları: $kullaniciGruplari");
    }

    // Duyuruları filtrele
    final kullaniciId = widget.currentUser.app;

    final filtered = widget.tumDuyurular.where((d) {
      final recipientId = d.recipient_id;
      print("Duyuru: ${d.title}");
      print("   recipient_id: '$recipientId'");

      final recipientIdStr = recipientId?.toString() ?? '';
      final kullaniciIdStr = kullaniciId.toString();

      final shouldAdd =
          recipientIdStr == 'all' || recipientIdStr == kullaniciIdStr;

      print("   -> ${shouldAdd ? "EKLE" : "EKLEME"}");
      return shouldAdd;
    }).toList();

    // 🔔 YENİ DUYURULAR İÇİN BİLDİRİM GÖNDER
    await _sendNotificationsForNewDuyurular(filtered);

    print("📊 Bulunan: ${filtered.length} duyuru");
    return filtered;
  }

  // 🚀 YENİ DUYURULAR İÇİN BİLDİRİM GÖNDER
  Future<void> _sendNotificationsForNewDuyurular(
    List<Notifications> duyurular,
  ) async {
    for (var duyuru in duyurular) {
      // Duyuru okunmamışsa ve daha önce bildirim gönderilmemişse
      final isRead = duyuru.is_read?.toLowerCase() == "true";
      final notificationId = duyuru.notifications_id.hashCode;

      if (!isRead && !_readNotificationIds.contains(notificationId)) {
        // Bildirim gönder
        await _notificationService.showNotification(
          id: notificationId.toString(),
          title: _getNotificationTitle(duyuru.type, duyuru.title),
          body: _getNotificationBody(duyuru),
          payload: duyuru.notifications_id.toString(),
        );

        // Bildirim gönderildi olarak işaretle
        await _saveReadNotification(notificationId);

        print("🔔 Bildirim gönderildi: ${duyuru.title}");
      }
    }
  }

  String _getNotificationTitle(String type, String title) {
    switch (type.toLowerCase()) {
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
    if (message.length > 100) {
      message = message.substring(0, 100) + '...';
    }
    return message;
  }

  DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return DateTime(2000);
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime(2000);
    }
  }

  Future<void> _markAsRead(Notifications duyuru) async {
    if (duyuru.is_read?.toLowerCase() == "true") return;

    await GoogleSheetService.markNotificationAsRead(
      duyuru.notifications_id,
      widget.currentUser.app,
    );

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
                    onPressed: () {
                      setState(() {
                        _filteredNotificationsFuture =
                            _getFilteredNotifications();
                      });
                    },
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredNotifications.length,
            itemBuilder: (context, index) {
              final duyuru = filteredNotifications[index];
              return GestureDetector(
                onTap: () => _markAsRead(duyuru),
                child: _buildDuyuruCard(duyuru),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDuyuruCard(Notifications duyuru) {
    bool isUnread = duyuru.is_read?.toLowerCase() != "true";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isUnread
            ? Border.all(
                color: _getIconColor(duyuru.type).withOpacity(0.3),
                width: 1.5,
              )
            : Border.all(color: Colors.transparent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: _getIconColor(duyuru.type).withOpacity(0.1),
          child: Icon(_getIcon(duyuru.type), color: _getIconColor(duyuru.type)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                duyuru.title,
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            if (isUnread)
              const Icon(
                Icons.fiber_manual_record,
                color: Colors.blue,
                size: 12,
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                duyuru.message,
                style: TextStyle(color: Colors.grey[700], height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tip: ${_getTypeDisplay(duyuru.type)}",
                    style: TextStyle(
                      fontSize: 11,
                      color: _getIconColor(duyuru.type),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatRelativeDateTurkish(duyuru.sent_at),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
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
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "Henüz bir duyuru bulunmuyor.",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
