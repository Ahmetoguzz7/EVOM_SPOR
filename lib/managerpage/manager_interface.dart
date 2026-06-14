import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/managerpage/antremanprogram.dart';
import 'package:EVOM_SPOR/managerpage/payment_history.dart';
import 'package:EVOM_SPOR/managerpage/student_P&A.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/loginpage/login.dart';
import 'package:EVOM_SPOR/managerpage/manager_group.dart';
import 'package:EVOM_SPOR/managerpage/manager_notifications.dart';
import 'package:EVOM_SPOR/managerpage/manager_student_attandance.dart';
import 'package:EVOM_SPOR/managerpage/manager_student_search.dart';

import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboard extends StatefulWidget {
  final String currentUserRole;
  final Users? currentUser;

  const AdminDashboard({
    Key? key,
    required this.currentUserRole,
    this.currentUser,
  }) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<Map<String, dynamic>> _dashboardData;

  // 🔥 AppRepository kullan
  final AppRepository _repo = AppRepository();

  // Antrenman programı için değişkenler (cache için)
  List<Group> _allGroups = [];
  List<GroupStudent> _allRelations = [];
  List<Users> _allStudents = [];
  List<Coach> _allCoachesList = [];
  List<Users> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _dashboardData = _loadAllDataWithRepo();
  }

  // 🚀 AppRepository ile veri çekme
  Future<Map<String, dynamic>> _loadAllDataWithRepo() async {
    final stopwatch = Stopwatch()..start();

    try {
      // Repository'yi yükle (ilk seferde internetten çeker, sonra cache'den)
      if (!_repo.isLoaded) {
        await _repo.loadAllData();
      }

      _allGroups = _repo.allGroups;
      _allRelations = _repo.allGroupStudents;
      _allStudents = _repo.allUsers
          .where((u) => u.role.toLowerCase() == "student")
          .toList();
      _allCoachesList = _repo.allCoaches;
      _allUsers = _repo.allUsers;

      stopwatch.stop();
      print(
        "⏱️ Tüm veriler AppRepository ile ${stopwatch.elapsedMilliseconds}ms'de yüklendi",
      );

      // Toplam koç sayısı (Coach modelinden)
      final totalCoaches = _allCoachesList.length;

      // Toplam öğrenci sayısı
      final totalStudents = _allStudents.length;

      // Toplam grup sayısı
      final totalGroups = _allGroups.length;

      // Aylık gelir hesaplama
      final now = DateTime.now();
      final currentMonth =
          "${now.year}-${now.month.toString().padLeft(2, '0')}";

      double income = 0;
      for (var p in _repo.allPayments) {
        if (p.status == "paid" && p.due_date.startsWith(currentMonth)) {
          income += double.tryParse(p.amount) ?? 0;
        }
      }

      // Son 7 gün duyurular
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final recent = _repo.allNotifications.where((n) {
        try {
          final date = DateTime.parse(n.sent_at);
          return date.isAfter(sevenDaysAgo);
        } catch (e) {
          return false;
        }
      }).toList();
      recent.sort((a, b) => b.sent_at.compareTo(a.sent_at));

      // Doğum günleri
      final birthdays = <Users>[];
      for (var user in _allUsers) {
        if (user.role.toLowerCase() == "student" && user.b_date.isNotEmpty) {
          try {
            final birthDate = DateTime.parse(user.b_date);
            final today = DateTime(now.year, now.month, now.day);
            final thisYearBirthday = DateTime(
              now.year,
              birthDate.month,
              birthDate.day,
            );

            if (thisYearBirthday.isAfter(today)) {
              final daysLeft = thisYearBirthday.difference(today).inDays;
              if (daysLeft <= 7) {
                birthdays.add(user);
              }
            }
          } catch (e) {
            continue;
          }
        }
      }
      birthdays.sort((a, b) {
        try {
          final dateA = DateTime.parse(a.b_date);
          final dateB = DateTime.parse(b.b_date);
          final nowDate = DateTime.now();
          final daysA = DateTime(
            nowDate.year,
            dateA.month,
            dateA.day,
          ).difference(nowDate).inDays;
          final daysB = DateTime(
            nowDate.year,
            dateB.month,
            dateB.day,
          ).difference(nowDate).inDays;
          return daysA.compareTo(daysB);
        } catch (e) {
          return 0;
        }
      });

      return {
        'totalStudents': totalStudents,
        'totalCoaches': totalCoaches,
        'totalGroups': totalGroups,
        'monthlyIncome': income,
        'recentNotifications': recent,
        'upcomingBirthdays': birthdays,
      };
    } catch (e, stackTrace) {
      print("❌ Veri yükleme hatası: $e");
      print(stackTrace);
      return {
        'totalStudents': 0,
        'totalCoaches': 0,
        'totalGroups': 0,
        'monthlyIncome': 0.0,
        'recentNotifications': <Notifications>[],
        'upcomingBirthdays': <Users>[],
      };
    }
  }

  Widget _buildTodayTrainingCard() {
    final todaysGroups = _getTodaysGroups();
    final todayName = _getTodayName();

    if (todaysGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          const Row(
            children: [
              Icon(Icons.sports, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                "🏃 Bugünkü Antrenman Programı",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Antrenman Listesi
          ...todaysGroups.map((group) {
            final scheduleToday = _getGroupScheduleForDay(group, todayName);

            // Antrenör ismini al
            String coachName = "Atanmamış";
            final coachUser = _allUsers.firstWhere(
              (user) => user.app.toString() == group.coach_id.toString(),
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
            if (coachUser.first_name.isNotEmpty) {
              coachName = "${coachUser.first_name} ${coachUser.last_name}"
                  .trim();
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                children: [
                  // Grup İkonu
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.group,
                      size: 24,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Bilgiler
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Grup Adı
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Antrenör (tek satırda)
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 12,
                              color: Colors.teal,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                coachName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.teal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Saat
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      scheduleToday,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Bugünkü grupları getir
  List<Group> _getTodaysGroups() {
    final todayName = _getTodayName();
    final todayGroups = <Group>[];

    for (var group in _allGroups) {
      if (group.schedule.toLowerCase().contains(todayName.toLowerCase())) {
        todayGroups.add(group);
      }
    }

    // Saate göre sırala
    todayGroups.sort((a, b) {
      final aTime = _getGroupStartTime(a, todayName);
      final bTime = _getGroupStartTime(b, todayName);
      return _timeToMinutes(aTime).compareTo(_timeToMinutes(bTime));
    });

    return todayGroups;
  }

  // Grubun belirli bir gündeki programını getir
  String _getGroupScheduleForDay(Group group, String dayName) {
    final schedule = group.schedule;
    final pattern = RegExp('$dayName:(\\d{2}:\\d{2})-(\\d{2}:\\d{2})');
    final match = pattern.firstMatch(schedule);
    if (match != null) {
      return "${match.group(1)} - ${match.group(2)}";
    }
    return "Saat belirtilmemiş";
  }

  // Grubun bugünkü başlangıç saatini al
  String _getGroupStartTime(Group group, String dayName) {
    final schedule = group.schedule;
    final pattern = RegExp('$dayName:(\\d{2}:\\d{2})-(\\d{2}:\\d{2})');
    final match = pattern.firstMatch(schedule);
    if (match != null) {
      return match.group(1) ?? "00:00";
    }
    return "23:59";
  }

  // Saat formatını karşılaştırma için dakikaya çevir
  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length == 2) {
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }
    return 0;
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

  int _getDaysUntilBirthday(String birthDateStr) {
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final now = DateTime.now();
      final thisYearBirthday = DateTime(
        now.year,
        birthDate.month,
        birthDate.day,
      );
      return thisYearBirthday.difference(now).inDays;
    } catch (e) {
      return 999;
    }
  }

  String _getDayText(int days) {
    if (days == 0) return "Bugün! 🎂";
    if (days == 1) return "Yarın 🎉";
    return "$days gün sonra";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "EVOM_SPOR",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
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
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSportLoadingScreen();
          }

          if (snapshot.hasError) {
            return _buildErrorScreen(snapshot.error);
          }

          final totalStudents = snapshot.data?['totalStudents'] ?? 0;
          final totalCoaches = snapshot.data?['totalCoaches'] ?? 0;
          final totalGroups = snapshot.data?['totalGroups'] ?? 0;
          final monthlyIncome = snapshot.data?['monthlyIncome'] ?? 0.0;
          final recentNotifications =
              snapshot.data?['recentNotifications'] ?? [];
          final upcomingBirthdays = snapshot.data?['upcomingBirthdays'] ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              await _repo.refreshAllData();
              setState(() {
                _dashboardData = _loadAllDataWithRepo();
              });
              await _dashboardData;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatsRow(totalStudents, totalCoaches),
                  const SizedBox(height: 12),
                  _buildStatsRow2(totalGroups, monthlyIncome),
                  const SizedBox(height: 20),
                  _buildTodayTrainingCard(),
                  _buildAnnouncementsCard(recentNotifications),
                  const SizedBox(height: 16),
                  _buildBirthdaysCard(upcomingBirthdays),
                  const SizedBox(height: 24),
                  const Text(
                    "Yönetim Menüsü",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuGrid(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSportLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/sports.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              " EVOM SPOR - Yönetici Girişi",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.orange[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Veriler Yükleniyor...",
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              "Spor salonu bilgileriniz hazırlanıyor",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(Object? error) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              "Bağlantı Hatası",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                setState(() {
                  _dashboardData = _loadAllDataWithRepo();
                });
              },
              child: const Text(
                "Tekrar Dene",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(int totalStudents, int totalCoaches) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Öğrenci",
            "$totalStudents",
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            "Antrenör",
            "$totalCoaches",
            Icons.sports,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow2(int totalGroups, double monthlyIncome) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Grup",
            "$totalGroups",
            Icons.group,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            "Aylık Gelir",
            "${monthlyIncome.toStringAsFixed(0)}₺",
            Icons.attach_money,
            Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsCard(List<Notifications> recentNotifications) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.campaign, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                "Son Duyurular",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (recentNotifications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  "Son 7 günde duyuru yok",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Column(
              children: recentNotifications.take(3).map((notif) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 30,
                        decoration: BoxDecoration(
                          color: notif.type == "urgent"
                              ? Colors.red
                              : Colors.blue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              notif.message,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (notif.type == "urgent")
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Acil",
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildBirthdaysCard(List<Users> upcomingBirthdays) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cake, color: Colors.pink, size: 20),
              SizedBox(width: 8),
              Text(
                "Doğum Günleri",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (upcomingBirthdays.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  "Yakında doğum günü yok",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...upcomingBirthdays.take(3).map((student) {
              final daysLeft = _getDaysUntilBirthday(student.b_date);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: daysLeft <= 1
                      ? Colors.pink.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: daysLeft <= 1
                          ? Colors.pink
                          : Colors.orange,
                      child: Text(
                        student.first_name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${student.first_name} ${student.last_name}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _getDayText(daysLeft),
                            style: TextStyle(
                              fontSize: 10,
                              color: daysLeft <= 1
                                  ? Colors.pink.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.celebration,
                      size: 16,
                      color: daysLeft <= 1 ? Colors.pink : Colors.orange,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    final List<Map<String, dynamic>> allMenus = [
      {
        "title": "Öğrenci Ödeme\nSayfası",
        "subtitle": "Öğrencilerin aylık aidatlarını alabilirsiniz.",
        "icon": Icons.search,
        "color": Colors.teal,
        "route": "student_search",
      },
      {
        "title": "Öğrenci Arama & Kayıt Oluştur",
        "subtitle":
            "Yeni gelen öğrenci kaydı açabilir ya da var olan öğrencinin bilgilerini(şifre hariç) güncelleyebilirsiniz.",
        "icon": Icons.person_add,
        "color": Colors.green,
        "route": "register",
      },
      {
        "title": "Yoklama Al",
        "subtitle":
            "Öğrencilerin idmana katılıp/katılmadığının görüntüleme ve yoklama alabilirsiniz.",
        "icon": Icons.fact_check,
        "color": Colors.orange,
        "route": "attendance",
      },
      {
        "title": "Duyuru Gönder",
        "subtitle":
            "Herkes / Gruba/ Kişiye olacak şekilde duyuru atayabilirsiniz.",
        "icon": Icons.campaign,
        "color": Colors.purple,
        "route": "notification",
      },
      {
        "title": "Ödeme Hatırlatma",
        "subtitle":
            "Öğrencilerin kayıt olma tarihlerine göre ödeme yapılmayan öğrencileri takip edebilirsiniz.",
        "icon": Icons.notifications_active,
        "color": Colors.red,
        "route": "payment_reminder",
      },
      {
        "title": "Antrenman Programı",
        "subtitle":
            "Haftalık grupların antrenman programlarını takip edebilirsiniz ve yeni antrenman ekleyebilir/silebilirisiniz.",
        "icon": Icons.calendar_month,
        "color": Colors.teal,
        "route": "training_schedule",
      },

      {
        "title": "Raporlar",
        "icon": Icons.bar_chart,
        "color": Colors.indigo,
        "route": "reports",
      },
      {
        "title": "Grup Yönetimi",
        "subtitle":
            "Grupları görüntüleyebilir öğrencilerin gruplarını değiştirebiir ve yeni grup ekleyebilirsiniz.",
        "icon": Icons.groups,
        "color": Colors.blue,
        "route": "group",
      },
      {
        "title": "Öğrenci Aktif/Pasif",
        "subtitle":
            "Devam eden/etmeyen öğrencileri ayırabilir ve görüntüleyebilirsiniz.",
        "icon": Icons.person_add_disabled,
        "color": Colors.deepOrange,
        "route": "pasifaktif",
      },
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: allMenus.map((menu) {
        return _menuCard(
          menu["title"],
          menu["icon"],
          menu["color"],
          () => _navigateToRoute(menu["route"]),
        );
      }).toList(),
    );
  }

  Future<void> _navigateToRoute(String route) async {
    switch (route) {
      case "student_search":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                StudentSearchScreen(currentUser: widget.currentUser),
          ),
        );
        break;
      case "register":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdvancedSignUpPage()),
        );
        break;
      case "attendance":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TakeAttendanceScreen(
              currentUser:
                  widget.currentUser ??
                  Users(
                    app: "",
                    branches_id: "",
                    first_name: "Admin",
                    last_name: "",
                    email: "",
                    phone: "",
                    password_hash: "",
                    role: "admin",
                    profile_photo_url: "",
                    amount: "",
                    b_date: "",
                    created_at: "",
                    last_login: "",
                    is_active: "",
                  ),
            ),
          ),
        );
        break;
      case "notification":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                NotificationsScreen(currentUser: widget.currentUser),
          ),
        );
        break;
      case "payment_reminder":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaymentReminderScreen()),
        );
        break;
      case "training_schedule":
        final repo = AppRepository();
        if (!repo.isLoaded) {
          await repo.loadAllData();
        }

        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WeeklyTrainingScreen(
              groups: repo.allGroups,
              relations: repo.allGroupStudents,
              students: repo.allUsers, // Tüm kullanıcılar (koçlar için gerekli)
              coaches: repo.allCoaches, // Coach listesi
              onScheduleUpdated: (groupId, newSchedule) async {
                await GoogleSheetService.updateGroupSchedule(
                  groupId,
                  newSchedule,
                );
                await repo.refreshTable('groups');
              },
            ),
          ),
        );
        break;

      case "group":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GroupManagementScreen()),
        );

        break;
      case "reports":
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Raporlar özelliği yakında...")),
        );
        break;
      case "pasifaktif":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentActivationScreen()),
        );
        break;
    }
  }

  Widget _menuCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 8),
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
}
