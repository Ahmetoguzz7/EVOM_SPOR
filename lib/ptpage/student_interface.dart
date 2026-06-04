/*
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/main.dart';
import 'package:EVOM_SPOR/parent/parent_page.dart';
import 'package:EVOM_SPOR/ptpage/student_attendance_page/student_attendance.dart';
import 'package:EVOM_SPOR/ptpage/student_info.dart';
import 'package:EVOM_SPOR/ptpage/student_pay.dart/student_pay.dart';
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:EVOM_SPOR/userInterfacepage/notifications/pt_natifications.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserInterface extends StatefulWidget {
  final Users user;

  const UserInterface({super.key, required this.user});

  @override
  State<UserInterface> createState() => _UserInterfaceState();
}

class _UserInterfaceState extends State<UserInterface> {
  // State değişkenleri
  bool _isLoading = true;
  String? _error;

  bool _isParent = false;
  List<Users> _bagliCocuklar = [];
  Users? _bagliVeli;
  Coach? _currentCoach;
  List<Payment> _allPayments = [];
  List<Group> _allGroups = [];
  List<GroupStudent> _allRelations = [];

  // Carousel için index
  int _currentChildIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAllDataInBackground();
  }

  // 🔥 TÜM VERİLERİ ARKA PLANDA YÜKLE (Sayfa hemen açılır)
  Future<void> _loadAllDataInBackground() async {
    try {
      final isParent =
          widget.user.role.toLowerCase() == 'parent' ||
          widget.user.role.toLowerCase() == 'veli';

      List<Users> bagliCocuklar = [];
      Users? bagliVeli;
      Coach? currentCoach;
      List<Payment> allPayments = [];
      List<Group> allGroups = [];
      List<GroupStudent> allRelations = [];

      // 🔥 PARALEL YÜKLEME - ÇOK HIZLI ⚡
      final results = await Future.wait([
        GoogleSheetService.getPaymentsCached(),
        GoogleSheetService.getGroupsCached(),
        GoogleSheetService.getGroupStudentsCached(),
        GoogleSheetService.getCoachesCached(),
        GoogleSheetService.getUsersCached(),
        GoogleSheetService.getParentStudents(), // 🔥 DÜZELTİLDİ
      ]);

      allPayments = results[0] as List<Payment>;
      allGroups = results[1] as List<Group>;
      allRelations = results[2] as List<GroupStudent>;
      final coaches = results[3] as List<Coach>;
      final allUsers = results[4] as List<Users>;
      final parentStudentList =
          results[5] as List<ParentStudent>; // 🔥 ParentStudent tipinde

      // Antrenör bilgisi
      currentCoach = coaches.firstWhere(
        (c) => c.user_id == widget.user.app,
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

      if (isParent) {
        // Veli için çocukları bul
        final myStudentIds = parentStudentList
            .where((ps) => ps.parent_id == widget.user.app)
            .map((ps) => ps.student_id)
            .toList();

        if (myStudentIds.isNotEmpty) {
          bagliCocuklar = allUsers
              .where((u) => myStudentIds.contains(u.app))
              .toList();
        }
      } else {
        // Öğrenci için veliyi bul
        final link = parentStudentList.firstWhere(
          (ps) => ps.student_id == widget.user.app,
          orElse: () => ParentStudent(
            parent_student_id: "",
            parent_id: "",
            student_id: "",
          ),
        );

        if (link.parent_id.isNotEmpty) {
          bagliVeli = allUsers.firstWhere(
            (u) => u.app == link.parent_id,
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
        }
      }

      if (mounted) {
        setState(() {
          _isParent = isParent;
          _bagliCocuklar = bagliCocuklar;
          _bagliVeli = bagliVeli;
          _currentCoach = currentCoach;
          _allPayments = allPayments;
          _allGroups = allGroups;
          _allRelations = allRelations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Veri yükleme hatası: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    GoogleSheetService.invalidateAllCache();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _loadAllDataInBackground();
  }

  Future<void> _openNotificationsPage(BuildContext context) async {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DuyurularPage(
          currentUser: widget.user,
          currentCoach: _currentCoach,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? _buildLoadingScreen()
          : _error != null
          ? _buildErrorScreen()
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: _isParent ? 200 : 180,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      onPressed: _logout,
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: _isParent
                          ? _buildParentHeader()
                          : _buildStudentHeader(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isParent && _bagliCocuklar.isNotEmpty)
                            _buildChildrenCarousel(),
                          if (!_isParent && _bagliVeli != null)
                            _buildSwitchToParentButton(),
                          const SizedBox(height: 16),
                          _buildMenuGrid(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.setBool('remember_me', false);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
        (route) => false,
      );
    }
  }

  Widget _buildLoadingScreen() {
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
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sports_basketball,
                      size: 45,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "EVOM_SPOR",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.orange[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Profiliniz Yükleniyor...",
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
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
              _error ?? "Bilinmeyen hata",
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
              onPressed: _refreshData,
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

  Widget _buildParentHeader() {
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
                    child: const Icon(
                      Icons.family_restroom,
                      size: 65,
                      color: Colors.white,
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
                          "${widget.user.first_name} ${widget.user.last_name}",
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
                          child: const Text(
                            "Veli Hesabı",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
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
                    _bagliCocuklar.length,
                    "ÇOCUK",
                    Icons.family_restroom,
                    Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentHeader() {
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
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage: widget.user.profile_photo_url.isNotEmpty
                          ? NetworkImage(widget.user.profile_photo_url)
                          : null,
                      child: widget.user.profile_photo_url.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 112,
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
                          "${widget.user.first_name} ${widget.user.last_name}",
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
                          child: const Text(
                            "Öğrenci",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_bagliVeli != null) ...[
                const SizedBox(height: 12),
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
                      const Icon(
                        Icons.family_restroom,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${_bagliVeli!.first_name} ${_bagliVeli!.last_name} (Veli)",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

  Widget _buildChildrenCarousel() {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 160,
            enlargeCenterPage: true,
            enableInfiniteScroll: false,
            onPageChanged: (index, _) {
              setState(() => _currentChildIndex = index);
            },
          ),
          items: _bagliCocuklar.map((child) => _buildChildCard(child)).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _bagliCocuklar.asMap().entries.map((entry) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(
                  _currentChildIndex == entry.key ? 1 : 0.3,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        if (_bagliCocuklar.isNotEmpty)
          _buildChildDashboard(_bagliCocuklar[_currentChildIndex]),
      ],
    );
  }

  Widget _buildChildCard(Users child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "SPORCU",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${child.first_name} ${child.last_name}".toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "ID: ${child.app}",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChildDashboard(Users child) {
    // Çocuğun ödeme bilgilerini hesapla
    final childPayments = _allPayments
        .where((p) => p.student_id == child.app)
        .toList();
    final paidAmount = childPayments.fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p.amount) ?? 0),
    );
    final monthlyFee = double.tryParse(child.amount) ?? 0;
    final isPaid = monthlyFee > 0 && paidAmount >= monthlyFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${child.first_name} Özeti",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  "Aylık Ücret",
                  "${monthlyFee.toStringAsFixed(0)} TL",
                  Icons.payments,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  "Aidat Durumu",
                  isPaid ? "Ödendi" : "Ödenmedi",
                  isPaid ? Icons.check_circle : Icons.warning_amber,
                  isPaid ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSwitchToParentButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserInterface(user: _bagliVeli!)),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.family_restroom, color: Colors.orange, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Bağlı Veli Hesabı",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      "${_bagliVeli!.first_name} ${_bagliVeli!.last_name}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.orange,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Hızlı İşlemler",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildMenuCard(
              "Ders Yoklama",
              Icons.check_circle_outline,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentAttendancePage(student: widget.user),
                ),
              ),
            ),
            _buildMenuCard(
              "Aylık Aidat",
              Icons.payments_outlined,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AidatPage(
                    user: widget.user,
                    tumOdemeler: _allPayments,
                    tumGruplar: _allGroups,
                    tumGroupStudents: _allRelations,
                  ),
                ),
              ),
            ),
            _buildMenuCard(
              "Duyurular",
              Icons.campaign_outlined,
              Colors.blue,
              () => _openNotificationsPage(context),
            ),
            _buildMenuCard(
              "Kişisel Bilgiler",
              Icons.badge_outlined,
              Colors.purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => KisiselBilgilerPage(user: widget.user),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard(
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
              blurRadius: 8,
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 32, color: color),
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
}
*/
/*
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/main.dart';
import 'package:EVOM_SPOR/parent/parent_page.dart';
import 'package:EVOM_SPOR/ptpage/student_attendance_page/student_attendance.dart';
import 'package:EVOM_SPOR/ptpage/student_info.dart';
import 'package:EVOM_SPOR/ptpage/student_pay.dart/student_pay.dart';
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:EVOM_SPOR/userInterfacepage/notifications/pt_natifications.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserInterface extends StatefulWidget {
  final Users user;

  const UserInterface({super.key, required this.user});

  @override
  State<UserInterface> createState() => _UserInterfaceState();
}

class _UserInterfaceState extends State<UserInterface> {
  // State değişkenleri
  bool _isLoading = true;
  String? _error;

  bool _isParent = false;
  List<Users> _bagliCocuklar = [];
  Users? _bagliVeli;
  Coach? _currentCoach;
  List<Payment> _allPayments = [];
  List<Group> _allGroups = [];
  List<GroupStudent> _allRelations = [];

  // Carousel için index
  int _currentChildIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAllDataInBackground();
  }

  // 🔥 TÜM VERİLERİ ARKA PLANDA YÜKLE (Sayfa hemen açılır)
  Future<void> _loadAllDataInBackground() async {
    try {
      final isParent =
          widget.user.role.toLowerCase() == 'parent' ||
          widget.user.role.toLowerCase() == 'veli';

      List<Users> bagliCocuklar = [];
      Users? bagliVeli;
      Coach? currentCoach;
      List<Payment> allPayments = [];
      List<Group> allGroups = [];
      List<GroupStudent> allRelations = [];

      // 🔥 PARALEL YÜKLEME - ÇOK HIZLI ⚡
      final results = await Future.wait([
        GoogleSheetService.getPaymentsCached(),
        GoogleSheetService.getGroupsCached(),
        GoogleSheetService.getGroupStudentsCached(),
        GoogleSheetService.getCoachesCached(),
        GoogleSheetService.getUsersCached(),
        GoogleSheetService.getParentStudents(),
      ]);

      allPayments = results[0] as List<Payment>;
      allGroups = results[1] as List<Group>;
      allRelations = results[2] as List<GroupStudent>;
      final coaches = results[3] as List<Coach>;
      final allUsers = results[4] as List<Users>;
      final parentStudentList = results[5] as List<ParentStudent>;

      // Antrenör bilgisi
      currentCoach = coaches.firstWhere(
        (c) => c.user_id == widget.user.app,
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

      if (isParent) {
        // Veli için çocukları bul
        final myStudentIds = parentStudentList
            .where((ps) => ps.parent_id == widget.user.app)
            .map((ps) => ps.student_id)
            .toList();

        if (myStudentIds.isNotEmpty) {
          bagliCocuklar = allUsers
              .where((u) => myStudentIds.contains(u.app))
              .toList();
        }
      } else {
        // Öğrenci için veliyi bul
        final link = parentStudentList.firstWhere(
          (ps) => ps.student_id == widget.user.app,
          orElse: () => ParentStudent(
            parent_student_id: "",
            parent_id: "",
            student_id: "",
          ),
        );

        if (link.parent_id.isNotEmpty) {
          bagliVeli = allUsers.firstWhere(
            (u) => u.app == link.parent_id,
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
        }
      }

      if (mounted) {
        setState(() {
          _isParent = isParent;
          _bagliCocuklar = bagliCocuklar;
          _bagliVeli = bagliVeli;
          _currentCoach = currentCoach;
          _allPayments = allPayments;
          _allGroups = allGroups;
          _allRelations = allRelations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Veri yükleme hatası: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    GoogleSheetService.invalidateAllCache();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _loadAllDataInBackground();
  }

  Future<void> _openNotificationsPage(BuildContext context) async {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DuyurularPage(
          currentUser: widget.user,
          currentCoach: _currentCoach,
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? _buildLoadingScreen()
          : _error != null
          ? _buildErrorScreen()
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: _isParent ? 200 : 180,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      onPressed: _logout,
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: _isParent
                          ? _buildParentHeader()
                          : _buildStudentHeader(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isParent && _bagliCocuklar.isNotEmpty)
                            _buildChildrenCarousel(),
                          if (!_isParent && _bagliVeli != null)
                            _buildSwitchToParentButton(),
                          const SizedBox(height: 16),
                          _buildMenuGrid(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.setBool('remember_me', false);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
        (route) => false,
      );
    }
  }

  Widget _buildLoadingScreen() {
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
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sports_basketball,
                      size: 45,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "EVOM_SPOR",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.orange[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Profiliniz Yükleniyor...",
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
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
              _error ?? "Bilinmeyen hata",
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
              onPressed: _refreshData,
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

  Widget _buildParentHeader() {
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
                  // KARE FOTOĞRAF
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey.shade200,
                      child: widget.user.profile_photo_url.isNotEmpty
                          ? Image.network(
                              widget.user.profile_photo_url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar(widget.user, 90);
                              },
                            )
                          : _buildDefaultAvatar(widget.user, 90),
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
                          "${widget.user.first_name} ${widget.user.last_name}",
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
                          child: const Text(
                            "Veli Hesabı",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
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
                    _bagliCocuklar.length,
                    "ÇOCUK",
                    Icons.family_restroom,
                    Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentHeader() {
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
                  // KARE FOTOĞRAF
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey.shade200,
                      child: widget.user.profile_photo_url.isNotEmpty
                          ? Image.network(
                              widget.user.profile_photo_url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar(widget.user, 90);
                              },
                            )
                          : _buildDefaultAvatar(widget.user, 90),
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
                          "${widget.user.first_name} ${widget.user.last_name}",
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
                          child: const Text(
                            "Öğrenci",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_bagliVeli != null) ...[
                const SizedBox(height: 12),
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
                      const Icon(
                        Icons.family_restroom,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${_bagliVeli!.first_name} ${_bagliVeli!.last_name} (Veli)",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

  Widget _buildChildrenCarousel() {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 120,
            enlargeCenterPage: true,
            enableInfiniteScroll: false,
            onPageChanged: (index, _) {
              setState(() => _currentChildIndex = index);
            },
          ),
          items: _bagliCocuklar.map((child) => _buildChildCard(child)).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _bagliCocuklar.asMap().entries.map((entry) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(
                  _currentChildIndex == entry.key ? 1 : 0.3,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        if (_bagliCocuklar.isNotEmpty)
          _buildChildDashboard(_bagliCocuklar[_currentChildIndex]),
      ],
    );
  }

  Widget _buildChildCard(Users child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
      child: Row(
        children: [
          // KARE FOTOĞRAF
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 60,
              height: 60,
              color: Colors.grey.shade200,
              child: child.profile_photo_url.isNotEmpty
                  ? Image.network(
                      child.profile_photo_url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar(child, 60);
                      },
                    )
                  : _buildDefaultAvatar(child, 60),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "SPORCU",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${child.first_name} ${child.last_name}".toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "ID: ${child.app}",
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildDashboard(Users child) {
    // Çocuğun ödeme bilgilerini hesapla
    final childPayments = _allPayments
        .where((p) => p.student_id == child.app)
        .toList();
    final paidAmount = childPayments.fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p.amount) ?? 0),
    );
    final monthlyFee = double.tryParse(child.amount) ?? 0;
    final isPaid = monthlyFee > 0 && paidAmount >= monthlyFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${child.first_name} Özeti",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  "Aylık Ücret",
                  "${monthlyFee.toStringAsFixed(0)} TL",
                  Icons.payments,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  "Aidat Durumu",
                  isPaid ? "Ödendi" : "Ödenmedi",
                  isPaid ? Icons.check_circle : Icons.warning_amber,
                  isPaid ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSwitchToParentButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserInterface(user: _bagliVeli!)),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.family_restroom, color: Colors.orange, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Bağlı Veli Hesabı",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      "${_bagliVeli!.first_name} ${_bagliVeli!.last_name}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.orange,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Hızlı İşlemler",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildMenuCard(
              "Ders Yoklama",
              Icons.check_circle_outline,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentAttendancePage(student: widget.user),
                ),
              ),
            ),
            _buildMenuCard(
              "Aylık Aidat",
              Icons.payments_outlined,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AidatPage(
                    user: widget.user,
                    tumOdemeler: _allPayments,
                    tumGruplar: _allGroups,
                    tumGroupStudents: _allRelations,
                  ),
                ),
              ),
            ),
            _buildMenuCard(
              "Duyurular",
              Icons.campaign_outlined,
              Colors.blue,
              () => _openNotificationsPage(context),
            ),
            _buildMenuCard(
              "Kişisel Bilgiler",
              Icons.badge_outlined,
              Colors.purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => KisiselBilgilerPage(user: widget.user),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard(
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
              blurRadius: 8,
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 32, color: color),
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
}
*/
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/main.dart';
import 'package:EVOM_SPOR/parent/parent_page.dart';
import 'package:EVOM_SPOR/ptpage/student_attendance_page/student_attendance.dart';
import 'package:EVOM_SPOR/ptpage/student_info.dart';
import 'package:EVOM_SPOR/ptpage/student_pay.dart/student_pay.dart';
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:EVOM_SPOR/userInterfacepage/notifications/pt_natifications.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserInterface extends StatefulWidget {
  final Users user;

  const UserInterface({super.key, required this.user});

  @override
  State<UserInterface> createState() => _UserInterfaceState();
}

class _UserInterfaceState extends State<UserInterface> {
  // State değişkenleri
  bool _isLoading = true;
  String? _error;

  bool _isParent = false;
  List<Users> _bagliCocuklar = [];
  Users? _bagliVeli;
  Coach? _currentCoach;
  List<Payment> _allPayments = [];
  List<Group> _allGroups = [];
  List<GroupStudent> _allRelations = [];

  // Carousel için index
  int _currentChildIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAllDataInBackground();
  }

  // 🔥 TÜM VERİLERİ ARKA PLANDA YÜKLE (Sayfa hemen açılır)
  Future<void> _loadAllDataInBackground() async {
    try {
      final isParent =
          widget.user.role.toLowerCase() == 'parent' ||
          widget.user.role.toLowerCase() == 'veli';

      List<Users> bagliCocuklar = [];
      Users? bagliVeli;
      Coach? currentCoach;
      List<Payment> allPayments = [];
      List<Group> allGroups = [];
      List<GroupStudent> allRelations = [];

      // 🔥 PARALEL YÜKLEME - ÇOK HIZLI ⚡
      final results = await Future.wait([
        GoogleSheetService.getPaymentsCached(),
        GoogleSheetService.getGroupsCached(),
        GoogleSheetService.getGroupStudentsCached(),
        GoogleSheetService.getCoachesCached(),
        GoogleSheetService.getUsersCached(),
        GoogleSheetService.getParentStudents(),
      ]);

      allPayments = results[0] as List<Payment>;
      allGroups = results[1] as List<Group>;
      allRelations = results[2] as List<GroupStudent>;
      final coaches = results[3] as List<Coach>;
      final allUsers = results[4] as List<Users>;
      final parentStudentList = results[5] as List<ParentStudent>;

      // Antrenör bilgisi
      currentCoach = coaches.firstWhere(
        (c) => c.user_id == widget.user.app,
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

      if (isParent) {
        // Veli için çocukları bul
        final myStudentIds = parentStudentList
            .where((ps) => ps.parent_id == widget.user.app)
            .map((ps) => ps.student_id)
            .toList();

        if (myStudentIds.isNotEmpty) {
          bagliCocuklar = allUsers
              .where((u) => myStudentIds.contains(u.app))
              .toList();
        }
      } else {
        // Öğrenci için veliyi bul
        final link = parentStudentList.firstWhere(
          (ps) => ps.student_id == widget.user.app,
          orElse: () => ParentStudent(
            parent_student_id: "",
            parent_id: "",
            student_id: "",
          ),
        );

        if (link.parent_id.isNotEmpty) {
          bagliVeli = allUsers.firstWhere(
            (u) => u.app == link.parent_id,
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
        }
      }

      if (mounted) {
        setState(() {
          _isParent = isParent;
          _bagliCocuklar = bagliCocuklar;
          _bagliVeli = bagliVeli;
          _currentCoach = currentCoach;
          _allPayments = allPayments;
          _allGroups = allGroups;
          _allRelations = allRelations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Veri yükleme hatası: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    GoogleSheetService.invalidateAllCache();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _loadAllDataInBackground();
  }

  Future<void> _openNotificationsPage(BuildContext context) async {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DuyurularPage(
          currentUser: widget.user,
          currentCoach: _currentCoach,
        ),
      ),
    );
  }

  // 🔥 DÜZELTİLMİŞ FOTOĞRAF METODU (CachedNetworkImage ile)
  Widget _buildProfileImage(String? imageUrl, double size, Users user) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
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
          ),
          errorWidget: (context, url, error) => _buildDefaultAvatar(user, size),
        ),
      );
    } else {
      return _buildDefaultAvatar(user, size);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),

      body: _isLoading
          ? _buildLoadingScreen()
          : _error != null
          ? _buildErrorScreen()
          : RefreshIndicator(
              onRefresh: _refreshData,

              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: _isParent ? 220 : 200,
                    // expandedHeight: _isParent ? 200 : 180,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      onPressed: _logout,
                    ),
                    //Boşluk bırak
                    title: const SizedBox.shrink(), // Boş title
                    // 🔥 SAĞ TARAFTA DA BUTON YOKSA BOŞLUK
                    // Boşluk için actions'a boş bir widget ekle
                    actions: [
                      const SizedBox(width: 48), // Logout butonuna denk boşluk
                    ],

                    // Logout butonu kadar boşluk
                    // Logout butonu kadar boşluk
                    flexibleSpace: FlexibleSpaceBar(
                      background: _isParent
                          ? _buildParentHeader()
                          : _buildStudentHeader(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /* if (_isParent && _bagliCocuklar.isNotEmpty)
                            _buildChildrenCarousel(),
                          if (!_isParent && _bagliVeli != null)
                            _buildSwitchToParentButton(),*/
                          const SizedBox(height: 16),
                          _buildMenuGrid(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.setBool('remember_me', false);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
        (route) => false,
      );
    }
  }

  Widget _buildLoadingScreen() {
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
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sports_basketball,
                      size: 45,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              " EVOM SPOR - Öğrenci / Antrenör Girişi",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.orange[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Profiliniz Yükleniyor...",
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
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
              _error ?? "Bilinmeyen hata",
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
              onPressed: _refreshData,
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

  Widget _buildParentHeader() {
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
                  // KARE FOTOĞRAF
                  _buildProfileImage(
                    widget.user.profile_photo_url,
                    90,
                    widget.user,
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
                          "${widget.user.first_name} ${widget.user.last_name}",
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
                          child: const Text(
                            "Veli Hesabı",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
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
                    _bagliCocuklar.length,
                    "ÇOCUK",
                    Icons.family_restroom,
                    Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentHeader() {
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
                  // KARE FOTOĞRAF
                  _buildProfileImage(
                    widget.user.profile_photo_url,
                    90,
                    widget.user,
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
                          "${widget.user.first_name} ${widget.user.last_name}",
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
                          child: const Text(
                            "Öğrenci",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_bagliVeli != null) ...[
                const SizedBox(height: 12),
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
                      const Icon(
                        Icons.family_restroom,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${_bagliVeli!.first_name} ${_bagliVeli!.last_name} (Veli)",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

  Widget _buildChildrenCarousel() {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 120,
            enlargeCenterPage: true,
            enableInfiniteScroll: false,
            onPageChanged: (index, _) {
              setState(() => _currentChildIndex = index);
            },
          ),
          items: _bagliCocuklar.map((child) => _buildChildCard(child)).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _bagliCocuklar.asMap().entries.map((entry) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(
                  _currentChildIndex == entry.key ? 1 : 0.3,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        if (_bagliCocuklar.isNotEmpty)
          _buildChildDashboard(_bagliCocuklar[_currentChildIndex]),
      ],
    );
  }

  Widget _buildChildCard(Users child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
      child: Row(
        children: [
          // KARE FOTOĞRAF
          _buildProfileImage(child.profile_photo_url, 60, child),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "SPORCU",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${child.first_name} ${child.last_name}".toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "ID: ${child.app}",
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildDashboard(Users child) {
    // Çocuğun ödeme bilgilerini hesapla
    final childPayments = _allPayments
        .where((p) => p.student_id == child.app)
        .toList();
    final paidAmount = childPayments.fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p.amount) ?? 0),
    );
    final monthlyFee = double.tryParse(child.amount) ?? 0;
    final isPaid = monthlyFee > 0 && paidAmount >= monthlyFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${child.first_name} Özeti",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  "Aylık Ücret",
                  "${monthlyFee.toStringAsFixed(0)} TL",
                  Icons.payments,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  "Aidat Durumu",
                  isPaid ? "Ödendi" : "Ödenmedi",
                  isPaid ? Icons.check_circle : Icons.warning_amber,
                  isPaid ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSwitchToParentButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserInterface(user: _bagliVeli!)),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.family_restroom, color: Colors.orange, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Bağlı Veli Hesabı",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      "${_bagliVeli!.first_name} ${_bagliVeli!.last_name}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.orange,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Hızlı İşlemler",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildMenuCard(
              "Ders Yoklama",
              Icons.check_circle_outline,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentAttendancePage(student: widget.user),
                ),
              ),
            ),
            _buildMenuCard(
              "Aylık Aidat",
              Icons.payments_outlined,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AidatPage(
                    user: widget.user,
                    tumOdemeler: _allPayments,
                    tumGruplar: _allGroups,
                    tumGroupStudents: _allRelations,
                  ),
                ),
              ),
            ),
            _buildMenuCard(
              "Duyurular",
              Icons.campaign_outlined,
              Colors.blue,
              () => _openNotificationsPage(context),
            ),
            _buildMenuCard(
              "Kişisel Bilgiler",
              Icons.badge_outlined,
              Colors.purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => KisiselBilgilerPage(user: widget.user),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard(
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
              blurRadius: 8,
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 32, color: color),
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
}
