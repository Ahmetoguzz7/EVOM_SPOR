import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/parent/parent_student_attandence.dart';
import 'package:EVOM_SPOR/parent/veli_payment_page.dart';
import 'package:EVOM_SPOR/ptpage/student_interface.dart';
import 'package:EVOM_SPOR/unifiedLoginPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VeliAnaSayfa extends StatefulWidget {
  final Users veli;
  const VeliAnaSayfa({super.key, required this.veli});

  @override
  State<VeliAnaSayfa> createState() => _VeliAnaSayfaState();
}

class _VeliAnaSayfaState extends State<VeliAnaSayfa> {
  late Future<List<Users>> _childrenFuture;
  List<Users> cocuklar = [];
  int _seciliCocukIndex = 0;

  // İstatistikler için
  Map<String, dynamic> _seciliCocukIstatistik = {};

  @override
  void initState() {
    super.initState();
    _childrenFuture = _cocuklariGetir();
  }

  Future<List<Users>> _cocuklariGetir() async {
    try {
      final studentsByParent = await GoogleSheetService.getStudentsByParent(
        widget.veli.app,
      );

      List<String> myIds = studentsByParent.map((ps) => ps.student_id).toList();

      if (myIds.isNotEmpty) {
        List<Users> allUsers = await GoogleSheetService.getUsers();
        cocuklar = allUsers.where((u) => myIds.contains(u.app)).toList();

        if (cocuklar.isNotEmpty) {
          await _loadSelectedChildStats(cocuklar[0]);
        }
      }
      return cocuklar;
    } catch (e) {
      print("Hata: $e");
      return [];
    }
  }

  Future<void> _loadSelectedChildStats(Users cocuk) async {
    try {
      final attendances = await GoogleSheetService.getAttendances();
      final cocukYoklamalari = attendances
          .where((a) => a.student_id == cocuk.app)
          .toList();

      int attended = cocukYoklamalari.where((a) => a.status == "TRUE").length;
      int total = cocukYoklamalari.length;
      double rate = total == 0 ? 0 : (attended / total) * 100;

      if (mounted) {
        setState(() {
          _seciliCocukIstatistik = {
            'attended': attended,
            'total': total,
            'rate': rate,
          };
        });
      }
    } catch (e) {
      print("İstatistik yüklenemedi: $e");
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
                            await GoogleSheetService.getUsers();
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
                                await GoogleSheetService.getUsers();
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
                          _childrenFuture = _cocuklariGetir();
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
      ),

      body: FutureBuilder<List<Users>>(
        future: _childrenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
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
                        _childrenFuture = _cocuklariGetir();
                      });
                    },
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            );
          }

          final cocuklar = snapshot.data ?? [];

          if (cocuklar.isEmpty) {
            return _buildEmptyState();
          }

          // Veriler geldikten sonra state'i güncelle (ilk yükleme için)
          if (this.cocuklar != cocuklar) {
            this.cocuklar = cocuklar;
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Sporcu Kartları Carousel
                CarouselSlider(
                  options: CarouselOptions(
                    height: 200,
                    enlargeCenterPage: true,
                    enableInfiniteScroll: false,
                    viewportFraction: 0.85,
                    onPageChanged: (index, _) async {
                      setState(() => _seciliCocukIndex = index);
                      await _loadSelectedChildStats(cocuklar[index]);
                    },
                  ),
                  items: cocuklar.map((c) => _buildSportCard(c)).toList(),
                ),
                const SizedBox(height: 20),
                // İstatistik Kartı
                _buildStatsCard(),
                const SizedBox(height: 20),
                // Menü Grid
                _buildMenuGrid(cocuklar[_seciliCocukIndex]),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
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
                "Gelişim Raporu",
                Icons.bar_chart,
                Colors.purple,
                () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Yakında...")));
                },
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
    );
  }
}
