import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/parent/parent_student_attandence.dart';
import 'package:EVOM_SPOR/parent/veli_payment_page.dart';
import 'package:EVOM_SPOR/ptpage/student_interface.dart';
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:EVOM_SPOR/userInterfacepage/notifications/pt_natifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VeliAnaSayfa extends StatefulWidget {
  final Users veli;
  const VeliAnaSayfa({super.key, required this.veli});

  @override
  State<VeliAnaSayfa> createState() => _VeliAnaSayfaState();
}

class _VeliAnaSayfaState extends State<VeliAnaSayfa> {
  late Future<Map<String, dynamic>> _dataFuture;
  List<Users> cocuklar = [];
  int _seciliCocukIndex = 0;

  // İstatistikler için
  Map<String, dynamic> _seciliCocukIstatistik = {};

  // 🔥 Cache için
  Map<String, Map<String, dynamic>> _statsCache = {};

  // 📢 BİLDİRİMLER İÇİN DEĞİŞKENLER
  List<Notifications> _recentNotifications = [];
  int _unreadNotificationCount = 0;
  bool _notificationsLoaded = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _verileriParalelGetir();
  }

  // 🚀 PARALEL VERİ ÇEKME
  Future<Map<String, dynamic>> _verileriParalelGetir() async {
    try {
      final results = await Future.wait([
        GoogleSheetService.getStudentsByParent(widget.veli.app),
        GoogleSheetService.getUsersCached(),
        GoogleSheetService.getAttendancesCached(),
      ]);

      final studentsByParent = results[0] as List<ParentStudent>;
      final allUsers = results[1] as List<Users>;
      final allAttendances = results[2] as List<Attendance>;

      List<String> myIds = studentsByParent.map((ps) => ps.student_id).toList();
      List<Users> cocuklarList = [];

      if (myIds.isNotEmpty) {
        cocuklarList = allUsers.where((u) => myIds.contains(u.app)).toList();

        // İstatistikleri hesapla
        for (var cocuk in cocuklarList) {
          final cocukYoklamalari = allAttendances
              .where((a) => a.student_id == cocuk.app)
              .toList();

          int attended = cocukYoklamalari
              .where((a) => a.status == "TRUE")
              .length;
          int total = cocukYoklamalari.length;
          double rate = total == 0 ? 0 : (attended / total) * 100;

          _statsCache[cocuk.app] = {
            'attended': attended,
            'total': total,
            'rate': rate,
          };
        }

        // 🔥 BİLDİRİMLERİ GETİR (VELİ İÇİN OTOMATİK FİLTRELENMİŞ)
        final filteredNotifications =
            await GoogleSheetService.getNotificationsForUser(widget.veli.app);

        // Map'leri Notifications objesine çevir
        final List<Notifications> allNotifications = filteredNotifications.map((
          item,
        ) {
          return Notifications(
            notifications_id: item['notifications_id']?.toString() ?? '',
            sender_id: item['sender_id']?.toString() ?? '',
            recipient_id: item['recipient_id']?.toString() ?? '',
            title: item['title']?.toString() ?? '',
            message: item['message']?.toString() ?? '',
            type: item['type']?.toString() ?? 'announcement',
            is_read: item['is_read']?.toString() ?? 'FALSE',
            sent_at: item['sent_at']?.toString() ?? '',
            groups_id: item['groups_id']?.toString() ?? '',
          );
        }).toList();

        // SON 7 GÜN FİLTRESİ
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        final filteredByDate = allNotifications.where((notif) {
          if (notif.sent_at.isEmpty || notif.sent_at == 'null') return false;
          final notifDate = DateTime.tryParse(notif.sent_at);
          if (notifDate == null) return false;
          return notifDate.isAfter(sevenDaysAgo);
        }).toList();

        setState(() {
          _recentNotifications = filteredByDate.take(3).toList();
          _unreadNotificationCount = filteredByDate
              .where((n) => n.is_read?.toLowerCase() != "true")
              .length;
          _notificationsLoaded = true;
        });
      }

      return {'cocuklar': cocuklarList, 'success': true};
    } catch (e) {
      print("❌ Veri yükleme hatası: $e");
      return {'cocuklar': <Users>[], 'success': false, 'error': e.toString()};
    }
  }

  void _cocukEkleDialog() {
    final nameController = TextEditingController();
    final surnameController = TextEditingController();
    final phoneController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text("Sporcu Bilgilerini Girin"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameController, "Adı", Icons.person),
              const SizedBox(height: 12),
              _dialogField(surnameController, "Soyadı", Icons.person_outline),
              const SizedBox(height: 12),
              _dialogField(
                phoneController,
                "Telefon Numarası",
                Icons.phone,
                inputType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setDialogState(() => isProcessing = true);

                      String ad = nameController.text.trim();
                      String soyad = surnameController.text.trim();
                      String tel = phoneController.text.trim();

                      try {
                        List<Users> allUsers =
                            await GoogleSheetService.getUsersCached();
                        var found = allUsers
                            .where(
                              (u) =>
                                  u.first_name.toLowerCase() ==
                                      ad.toLowerCase() &&
                                  u.last_name.toLowerCase() ==
                                      soyad.toLowerCase(),
                            )
                            .toList();

                        String studentId = "";

                        if (found.isNotEmpty) {
                          studentId = found.first.app;
                          _showSuccessDialog("Sporcu bulundu ve bağlandı!");
                        } else {
                          bool? confirm = await _showConfirmNewRecord(
                            ad,
                            soyad,
                          );
                          if (confirm == true) {
                            Users yeniCocuk = Users(
                              app: "",
                              branches_id: widget.veli.branches_id,
                              first_name: ad,
                              last_name: soyad,
                              email:
                                  "${ad.toLowerCase()}${soyad.toLowerCase()}",
                              phone: tel,
                              password_hash: "",
                              role: "student",
                              profile_photo_url: "",
                              amount: widget.veli.amount,
                              b_date: widget.veli.b_date,
                              created_at: DateTime.now().toIso8601String(),
                              last_login: "",
                              is_active: "TRUE",
                            );

                            await GoogleSheetService.registerUser(yeniCocuk);

                            var updatedUsers =
                                await GoogleSheetService.getUsersCached(
                                  forceRefresh: true,
                                );
                            studentId = updatedUsers
                                .firstWhere(
                                  (u) =>
                                      u.first_name == ad &&
                                      u.last_name == soyad,
                                )
                                .app;

                            _showSuccessDialog(
                              "Yeni sporcu kaydı oluşturuldu ve bağlandı!",
                            );
                          } else {
                            setDialogState(() => isProcessing = false);
                            return;
                          }
                        }

                        await GoogleSheetService.addParentStudent(
                          widget.veli.app,
                          studentId,
                        );

                        Navigator.pop(context);
                        setState(() {
                          _dataFuture = _verileriParalelGetir();
                        });
                      } catch (e) {
                        print("Hata: $e");
                        _showErrorDialog(
                          "Bir hata oluştu. Lütfen tekrar deneyin.",
                        );
                      } finally {
                        setDialogState(() => isProcessing = false);
                      }
                    },
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Sorgula ve Bağla"),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool?> _showConfirmNewRecord(String ad, String soyad) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text("Kayıt Bulunamadı"),
          ],
        ),
        content: Text(
          "$ad $soyad sistemde kayıtlı değil.\nYeni bir sporcu kaydı oluşturup hesabınıza bağlayalım mı?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hayır"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Evet, Kaydet"),
          ),
        ],
      ),
    );
  }

  void _openNotificationsPage(BuildContext context) async {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DuyurularPage(currentUser: widget.veli),
      ),
    );
  }

  IconData _getIconForNotif(String? type) {
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

  Color _getIconColorForNotif(String? type) {
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

  Widget _buildNotificationCardForHome(Notifications notif) {
    bool isUrgent = notif.type?.toLowerCase() == "urgent";
    bool isUnread = notif.is_read?.toLowerCase() != "true";

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isUnread ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isUrgent
            ? Border.all(color: Colors.red.shade200, width: 1)
            : (isUnread
                  ? Border.all(color: Colors.blue.shade200, width: 1)
                  : null),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: isUrgent
                  ? Colors.red
                  : (isUnread ? Colors.blue : Colors.grey),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getIconColorForNotif(notif.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIconForNotif(notif.type),
              color: _getIconColorForNotif(notif.type),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: TextStyle(
                          fontWeight: isUnread
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 12,
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
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "Acil",
                          style: TextStyle(
                            fontSize: 8,
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
                const SizedBox(height: 2),
                Text(
                  notif.message,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRelativeDateTurkish(notif.sent_at),
                  style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    if (_recentNotifications.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                "Son 7 Günün Duyuruları",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              if (_unreadNotificationCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "$_unreadNotificationCount",
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ..._recentNotifications.map(
            (notif) => _buildNotificationCardForHome(notif),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _openNotificationsPage(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "Tüm duyuruları gör",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 10,
                  color: Colors.blue.shade600,
                ),
              ],
            ),
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
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('saved_email');
            await prefs.remove('saved_password');
            await prefs.setBool('remember_me', false);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          "Veli Paneli",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _dataFuture = _verileriParalelGetir();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
          }

          if (snapshot.hasError || (snapshot.data?['success'] == false)) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text("Hata: ${snapshot.error ?? snapshot.data?['error']}"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _dataFuture = _verileriParalelGetir();
                      });
                    },
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            );
          }

          final cocuklarList = snapshot.data?['cocuklar'] as List<Users>? ?? [];

          if (cocuklarList.isEmpty) {
            return _buildEmptyState();
          }

          if (cocuklar != cocuklarList) {
            cocuklar = cocuklarList;
            if (cocuklar.isNotEmpty &&
                _statsCache.containsKey(cocuklar[0].app)) {
              _seciliCocukIstatistik = _statsCache[cocuklar[0].app]!;
            }
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _dataFuture = _verileriParalelGetir();
              });
              await _dataFuture;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  CarouselSlider(
                    options: CarouselOptions(
                      height: 200,
                      enlargeCenterPage: true,
                      enableInfiniteScroll: false,
                      viewportFraction: 0.85,
                      onPageChanged: (index, _) async {
                        setState(() {
                          _seciliCocukIndex = index;
                          final seciliCocuk = cocuklar[index];
                          if (_statsCache.containsKey(seciliCocuk.app)) {
                            _seciliCocukIstatistik =
                                _statsCache[seciliCocuk.app]!;
                          }
                        });
                      },
                    ),
                    items: cocuklar.map((c) => _buildSportCard(c)).toList(),
                  ),
                  const SizedBox(height: 20),
                  _buildStatsCard(),
                  const SizedBox(height: 16),
                  if (_notificationsLoaded && _recentNotifications.isNotEmpty)
                    _buildNotificationsSection(),
                  const SizedBox(height: 16),
                  _buildMenuGrid(cocuklar[_seciliCocukIndex]),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _cocukEkleDialog,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.orange),
          SizedBox(height: 16),
          Text("Bilgileriniz yükleniyor..."),
        ],
      ),
    );
  }

  Widget _buildSportCard(Users cocuk) {
    return GestureDetector(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "SPORCU",
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(Icons.nfc, color: Colors.orange, size: 20),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "${cocuk.first_name} ${cocuk.last_name}".toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Detayları Görüntüle",
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    double rate = _seciliCocukIstatistik['rate'] ?? 0;
    int attended = _seciliCocukIstatistik['attended'] ?? 0;
    int total = _seciliCocukIstatistik['total'] ?? 0;
    Color rateColor = rate >= 80
        ? Colors.green
        : (rate >= 50 ? Colors.orange : Colors.red);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.indigo, Colors.indigoAccent],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                "Toplam Ders",
                "$total",
                Icons.calendar_today,
                Colors.white,
              ),
              _buildStatItem(
                "Katılım",
                "$attended",
                Icons.check_circle,
                Colors.green.shade300,
              ),
              _buildStatItem(
                "Oran",
                "%${rate.toStringAsFixed(0)}",
                Icons.pie_chart,
                rateColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: rate / 100,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            borderRadius: BorderRadius.circular(10),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildMenuGrid(Users cocuk) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              "Hızlı İşlemler",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildMenuItem(
                "Ödemeler",
                Icons.account_balance_wallet,
                Colors.orange,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VeliOdemeSayfasi(cocuk: cocuk),
                  ),
                ),
              ),
              _buildMenuItem(
                "Yoklama Geçmişi",
                Icons.calendar_month,
                Colors.blue,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VeliYoklamaSayfasi(cocuk: cocuk),
                  ),
                ),
              ),
              _buildMenuItem(
                "Duyurular",
                Icons.campaign,
                Colors.purple,
                () => _openNotificationsPage(context),
              ),
              _buildMenuItem(
                "Antrenör Notları",
                Icons.assignment,
                Colors.teal,
                () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Yakında...")));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.orange),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('saved_email');
            await prefs.remove('saved_password');
            await prefs.setBool('remember_me', false);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          "Veli Paneli",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _dataFuture = _verileriParalelGetir();
              });
            },
          ),
        ],
      ),
      body: Center(
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
                Icons.people_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Bağlı Sporcu Bulunamadı",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              "Sağ alt köşedeki + butonu ile\nsporcu ekleyebilirsiniz",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _cocukEkleDialog,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}
