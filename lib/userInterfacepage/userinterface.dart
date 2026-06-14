import 'dart:async';

import 'package:EVOM_SPOR/userInterfacepage/ptantrenmanprogram.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/main.dart';
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:EVOM_SPOR/userInterfacepage/attendance.dart';
import 'package:EVOM_SPOR/userInterfacepage/attendancedetail.dart';
import 'package:EVOM_SPOR/userInterfacepage/notifications/pt_natifications.dart';
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalTrainer extends StatefulWidget {
  final Users users;
  final Sports sport;
  final Coach coachData;

  const PersonalTrainer({
    super.key,
    required this.users,
    required this.sport,
    required this.coachData,
  });

  @override
  State<PersonalTrainer> createState() => _PersonalTrainerState();
}

class _PersonalTrainerState extends State<PersonalTrainer> {
  final AppRepository _repo = AppRepository();

  // Veriler için state değişkenleri
  List<Group> _myGroups = [];
  List<Users> _myStudents = [];
  List<Payment> _myPayments = [];
  List<Notifications> _recentNotifications = [];
  int _allNotificationsCount = 0;
  int _unreadNotificationCount = 0;
  bool _isLoading = true;
  String? _error;
  List<Group> _todaysGroups = [];

  // Öğrenci sayıları için cache
  Map<String, int> _studentCountByGroup = {};

  // =========================================================================
  // 🔥 TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

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
      return "Şimdi";
    }
  }

  String _formatDateLongTurkish(String dateStr) {
    if (dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr.split('T')[0];
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadDataFromRepository());
  }

  // 🔥🔥🔥 FİLTRELENMİŞ BİLDİRİMLER (ANTRENÖR İÇİN) 🔥🔥🔥
  List<Notifications> _getFilteredNotificationsForCoach() {
    final coachUserId = widget.coachData.user_id
        .toString()
        .trim()
        .toLowerCase();
    final coachId = widget.coachData.coach_id.toString().trim().toLowerCase();

    // Antrenörün gruplarını al
    final coachGroups = _repo.getGroupsByCoachId(coachId);
    final coachGroupIds = coachGroups.map((g) => g.groups_id).toSet();

    final filtered = _repo.allNotifications.where((d) {
      final recipientId = d.recipient_id?.toString().trim().toLowerCase() ?? '';
      final senderId = d.sender_id?.toString().trim().toLowerCase() ?? '';
      final groupId = d.groups_id?.toString().trim() ?? '';

      if (senderId == coachUserId) return false;
      if (recipientId == 'all' || recipientId == 'tümü') return true;
      if (recipientId == coachUserId || recipientId == coachId) return true;
      if (groupId.isNotEmpty && coachGroupIds.contains(groupId)) return true;

      return false;
    }).toList();

    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(a.sent_at ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b.sent_at ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  Future<void> _loadDataFromRepository() async {
    try {
      if (!_repo.isLoaded) {
        await _repo.loadCriticalData(
          onProgress: (p) {
            if (mounted && p < 0.95) {
              setState(() {});
            }
          },
        );
      }

      final myGroups = _repo.getGroupsByCoachId(widget.coachData.coach_id);
      final myStudents = _repo.getStudentsByCoachId(widget.coachData.coach_id);

      // TÜM FİLTRELENMİŞ BİLDİRİMLER (backend filtresi)
      final allFilteredNotifications = _getFilteredNotificationsForCoach();

      // 🔥 SADECE SON 7 GÜN FİLTRESİ
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final filteredByDate = allFilteredNotifications.where((notif) {
        if (notif.sent_at.isEmpty || notif.sent_at == 'null') {
          return false;
        }
        DateTime? notifDate = DateTime.tryParse(notif.sent_at);
        if (notifDate == null) {
          try {
            final parts = notif.sent_at.split('.');
            if (parts.length == 3) {
              notifDate = DateTime(
                int.parse(parts[2].split(' ')[0]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            }
          } catch (_) {
            return false;
          }
        }
        if (notifDate == null) return false;
        return notifDate.isAfter(sevenDaysAgo);
      }).toList();

      final unreadCount = filteredByDate
          .where((n) => n.is_read?.toLowerCase() != "true")
          .length;

      final todaysGroups = _repo.getTodaysGroupsForCoach(
        widget.coachData.coach_id,
      );

      final Map<String, int> studentCount = {};
      for (var group in myGroups) {
        final studentsInGroup = _repo
            .getGroupStudentsByGroupId(group.groups_id)
            .where((gs) => gs.is_active.toString().toUpperCase() == "TRUE")
            .length;
        studentCount[group.groups_id] = studentsInGroup;
      }

      final studentIds = myStudents.map((s) => s.app).toSet();
      final myPayments = _repo.allPayments
          .where((p) => studentIds.contains(p.student_id))
          .toList();

      if (mounted) {
        setState(() {
          _myGroups = myGroups;
          _myStudents = myStudents;
          _myPayments = myPayments;
          _studentCountByGroup = studentCount;
          _recentNotifications = filteredByDate.take(3).toList();
          _allNotificationsCount = filteredByDate.length;
          _unreadNotificationCount = unreadCount;
          _todaysGroups = todaysGroups;
          _isLoading = false;
        });
      }

      print(
        "✅ PersonalTrainer: ${_myGroups.length} grup, ${_myStudents.length} öğrenci, "
        "${_allNotificationsCount} bildirim (${_unreadNotificationCount} okunmamış) - Son 7 gün",
      );
    } catch (e) {
      print("❌ Veri yükleme hatası: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return DateTime(2000);
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime(2000);
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _repo.refreshAllData();
    await _loadDataFromRepository();
  }

  Future<void> _openNotificationsPage(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DuyurularPage(
          currentUser: widget.users,
          currentCoach: widget.coachData,
        ),
      ),
    );
  }

  // 🔥 ANA SAYFADA GÖSTERİLECEK BİLDİRİM KARTI (KÜÇÜLTÜLMÜŞ)
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
          // Sol çizgi
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

          // İkon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getIconColor(notif.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIcon(notif.type),
              color: _getIconColor(notif.type),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),

          // İçerik
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 260,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
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
              flexibleSpace: FlexibleSpaceBar(background: _buildHeader()),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isLoading) ...[
                      _buildTodayTrainingCard(),
                      const SizedBox(height: 20),
                    ],

                    const Text(
                      "Hızlı İşlemler",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            "Yoklama Al",
                            Icons.fact_check_rounded,
                            Colors.green,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GrupListesiSayfasi(
                                  user: widget.users,
                                  coache: widget.coachData,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            "Duyurular",
                            Icons.campaign,
                            Colors.blue,
                            () => _openNotificationsPage(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            "Haftalık\nProgram",
                            Icons.calendar_month,
                            Colors.orange,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PtWeeklyProgram(
                                  user: widget.users,
                                  coach: widget.coachData,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            "Profilim",
                            Icons.badge,
                            Colors.purple,
                            () => _showCoachDetails(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (_isLoading)
                      _buildLoadingSection()
                    else if (_error != null)
                      _buildErrorSection()
                    else if (_recentNotifications.isNotEmpty) ...[
                      _buildNotificationsSection(),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  // 🔥 GELİŞMİŞ: Bugünkü antrenman kartı
  Widget _buildTodayTrainingCard() {
    final todayName = _getTodayName();

    if (_todaysGroups.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade50, Colors.grey.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.free_breakfast,
                size: 28,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "🏖️ $todayName Dinlenme Günü",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Bugün antrenman programınız bulunmuyor. İyi dinlenmeler! 🧘",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.sports_basketball,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "🏃 BUGÜNKÜ ANTRENMANLARIN",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$todayName • ${_todaysGroups.length} antrenman",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people,
                            size: 14,
                            color: Colors.orange.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getTotalStudentsToday(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ..._todaysGroups.asMap().entries.map((entry) {
                      final group = entry.value;
                      final scheduleToday = _getGroupScheduleForDay(
                        group,
                        todayName,
                      );
                      final startTime = _getGroupStartTime(group, todayName);
                      final isSoon = _isTrainingSoon(startTime);
                      final studentCount =
                          _studentCountByGroup[group.groups_id] ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSoon
                                ? Colors.green.withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                            width: isSoon ? 1.5 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _showGroupDetails(group, scheduleToday);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 65,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSoon
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          _formatTimeTurkish(startTime),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isSoon
                                                ? Colors.green.shade400
                                                : Colors.orange.shade400,
                                          ),
                                        ),
                                        if (isSoon)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade400,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              "YAKINDA",
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                group.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                scheduleToday,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade400,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.people_outline,
                                              size: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "$studentCount öğrenci",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(
                                              Icons.schedule,
                                              size: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _getTrainingDuration(
                                                scheduleToday,
                                              ),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.5),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 14,
                                          color: Colors.green,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "Yoklama",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.green,
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
                    }).toList(),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Toplam ${_getTotalTrainingTime()} antrenman süresi",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PtWeeklyProgram(
                              user: widget.users,
                              coach: widget.coachData,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            "Haftalık Program",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: Colors.orange.shade400,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Center(
      child: Column(
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Veriler yükleniyor...",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 40),
          const SizedBox(height: 8),
          Text(
            "Veriler yüklenirken hata oluştu",
            style: TextStyle(color: Colors.red.shade700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _refreshData, child: const Text("Tekrar Dene")),
        ],
      ),
    );
  }

  // 🔥🔥🔥 BİLDİRİMLER BÖLÜMÜ (FİLTRE BUTONSUZ - SADECE SON 7 GÜN) 🔥🔥🔥
  Widget _buildNotificationsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                "Son 7 Günün Duyuruları",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              if (_unreadNotificationCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$_unreadNotificationCount okunmamış",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$_allNotificationsCount duyuru",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recentNotifications.map(
            (notif) => _buildNotificationCardForHome(notif),
          ),
          if (_allNotificationsCount > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => _openNotificationsPage(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Tüm duyuruları gör (${_allNotificationsCount - 3} daha)",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: Colors.blue.shade600,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalStudents = _myStudents.length;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage: widget.users.profile_photo_url.isNotEmpty
                          ? NetworkImage(widget.users.profile_photo_url)
                          : null,
                      child: widget.users.profile_photo_url.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 32,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hoş Geldin,",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "${widget.users.first_name} ${widget.users.last_name}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sports_basketball,
                                size: 12,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.sport.name,
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildStatCard(
                    totalStudents,
                    "ÖĞRENCİ",
                    Icons.people,
                    Colors.blue,
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    _myGroups.length,
                    "GRUP",
                    Icons.group,
                    Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(int value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 10),
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

  void _showCoachDetails(BuildContext context) {
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
            const Row(
              children: [
                Icon(Icons.badge, color: Colors.orange, size: 28),
                SizedBox(width: 10),
                Text(
                  "Antrenör Profili",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoRow(
              Icons.verified,
              "Sertifika",
              widget.coachData.certificate_info,
            ),
            const Divider(),
            _infoRow(
              Icons.payments,
              "Maaş",
              "${widget.coachData.monthly_salary} TL",
            ),
            const Divider(),
            _infoRow(
              Icons.calendar_today,
              "İşe Başlangıç",
              _formatDateLongTurkish(widget.coachData.hired_at),
            ),
            const Divider(),
            _infoRow(Icons.info, "Hakkımda", widget.coachData.bio),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.orange),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value.isNotEmpty ? value : "Belirtilmemiş")),
        ],
      ),
    );
  }

  // ============================================================
  // 🆕 YARDIMCI METODLAR
  // ============================================================

  String _formatTimeTurkish(String time) {
    return time;
  }

  String _getTotalTrainingTime() {
    int totalMinutes = 0;
    final todayName = _getTodayName();

    for (var group in _todaysGroups) {
      final schedule = _getGroupScheduleForDay(group, todayName);
      final times = schedule.split(' - ');
      if (times.length == 2) {
        final start = _timeToMinutes(times[0]);
        final end = _timeToMinutes(times[1]);
        totalMinutes += (end - start);
      }
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return "$hours saat ${minutes > 0 ? '$minutes dk' : ''}";
    }
    return "$minutes dk";
  }

  String _getTrainingDuration(String schedule) {
    final times = schedule.split(' - ');
    if (times.length == 2) {
      final start = _timeToMinutes(times[0]);
      final end = _timeToMinutes(times[1]);
      final diff = end - start;
      return "$diff dk";
    }
    return "Belirtilmemiş";
  }

  bool _isTrainingSoon(String startTime) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final trainingMinutes = _timeToMinutes(startTime);
    final diff = trainingMinutes - nowMinutes;
    return diff > 0 && diff <= 30;
  }

  String _getTotalStudentsToday() {
    int total = 0;
    for (var group in _todaysGroups) {
      total += _studentCountByGroup[group.groups_id] ?? 0;
    }
    return total.toString();
  }

  void _showGroupDetails(Group group, String scheduleToday) {
    final studentCount = _studentCountByGroup[group.groups_id] ?? 0;
    final startTime = _getGroupStartTime(group, _getTodayName());
    final endTime = scheduleToday.split(' - ').length == 2
        ? scheduleToday.split(' - ')[1]
        : "Belirtilmemiş";

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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.group, color: Colors.orange.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow(Icons.access_time, "Saat", "$startTime - $endTime"),
            const Divider(),
            _buildDetailRow(
              Icons.people,
              "Öğrenci Sayısı",
              "$studentCount öğrenci",
            ),
            const Divider(),
            _buildDetailRow(
              Icons.schedule,
              "Süre",
              _getTrainingDuration(scheduleToday),
            ),
            const Divider(),
            _buildDetailRow(
              Icons.location_on,
              "Lokasyon",
              _repo.getBranchById(group.branches_id)?.name ?? "Belirtilmemiş",
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: BorderSide(color: Colors.orange.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text("Kapat"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GrupListesiSayfasi(
                            user: widget.users,
                            coache: widget.coachData,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      "Yoklama Al",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  String _getTodayName() {
    final days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    final now = DateTime.now();
    return days[now.weekday - 1];
  }

  String _getGroupScheduleForDay(Group group, String dayName) {
    final schedule = group.schedule;
    final pattern = RegExp('$dayName:(\\d{2}:\\d{2})-(\\d{2}:\\d{2})');
    final match = pattern.firstMatch(schedule);
    if (match != null) {
      return "${match.group(1)} - ${match.group(2)}";
    }
    return "Saat belirtilmemiş";
  }

  String _getGroupStartTime(Group group, String dayName) {
    final schedule = group.schedule;
    final pattern = RegExp('$dayName:(\\d{2}:\\d{2})-(\\d{2}:\\d{2})');
    final match = pattern.firstMatch(schedule);
    if (match != null) {
      return match.group(1) ?? "00:00";
    }
    return "23:59";
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length == 2) {
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }
    return 0;
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
}
