/*
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class KisiselBilgilerPage extends StatefulWidget {
  final Users user;

  const KisiselBilgilerPage({super.key, required this.user});

  @override
  State<KisiselBilgilerPage> createState() => _KisiselBilgilerPageState();
}

class _KisiselBilgilerPageState extends State<KisiselBilgilerPage> {
  late Future<Map<String, dynamic>> _userDetailsFuture;

  @override
  void initState() {
    super.initState();
    _userDetailsFuture = _loadUserDetails();
  }

  // 🔥 Ek bilgileri cache'den çek
  Future<Map<String, dynamic>> _loadUserDetails() async {
    try {
      // Şube bilgisini cache'den al
      Branches? branch;
      if (widget.user.branches_id.isNotEmpty) {
        final branches = await GoogleSheetService.getBranchesCached();
        branch = branches.firstWhere(
          (b) => b.branches_id == widget.user.branches_id,
          orElse: () => Branches(
            branches_id: "",
            name: "Belirtilmemiş",
            address: "",
            phone: "",
            email: "",

            created_at: "",
            is_active: '',
          ),
        );
      }

      return {'branch': branch};
    } catch (e) {
      print("Detay yükleme hatası: $e");
      return {'branch': null};
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return dateStr;
    }
  }

  String _getAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return "?";
    try {
      final date = DateTime.parse(birthDate);
      final now = DateTime.now();
      int age = now.year - date.year;
      if (now.month < date.month ||
          (now.month == date.month && now.day < date.day)) {
        age--;
      }
      return "$age yaşında";
    } catch (e) {
      return "?";
    }
  }

  String _getRoleText(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return 'Öğrenci';
      case 'coach':
        return 'Antrenör';
      case 'parent':
        return 'Veli';
      default:
        return role;
    }
  }

  String _getStatusText(String isActive) {
    return isActive.toLowerCase() == "true" ? "Aktif" : "Pasif";
  }

  String _getBranchName(Branches? branch) {
    if (branch == null) return widget.user.branches_id;
    return branch.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Profilim",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          // 🔄 Yenileme butonu
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              GoogleSheetService.invalidateCache('branches');
              setState(() {
                _userDetailsFuture = _loadUserDetails();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _userDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text("Profil bilgileri yükleniyor..."),
                ],
              ),
            );
          }

          final branch = snapshot.data?['branch'] as Branches?;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Üst profil kartı
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Profil fotoğrafı
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.transparent,
                            backgroundImage:
                                widget.user.profile_photo_url.isNotEmpty
                                ? NetworkImage(widget.user.profile_photo_url)
                                : null,
                            child: widget.user.profile_photo_url.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // İsim
                        Text(
                          "${widget.user.first_name} ${widget.user.last_name}",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Rol chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.orange,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.user.role.toLowerCase() == 'student'
                                    ? Icons.school
                                    : widget.user.role.toLowerCase() == 'coach'
                                    ? Icons.sports
                                    : Icons.family_restroom,
                                size: 14,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getRoleText(widget.user.role),
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // İstatistik kartları
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              _buildStatCard(
                                "Yaş",
                                _getAge(widget.user.b_date),
                                Icons.cake,
                                Colors.pink,
                              ),
                              _buildStatCard(
                                "Durum",
                                _getStatusText(widget.user.is_active),
                                Icons.verified,
                                Colors.green,
                              ),
                              _buildStatCard(
                                "Şube",
                                _getBranchName(branch),
                                Icons.location_on,
                                Colors.blue,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
                // Bilgi kartları
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoCard(
                        title: "Kişisel Bilgiler",
                        icon: Icons.person_outline,
                        color: Colors.blue,
                        children: [
                          _infoRow(
                            "Ad Soyad",
                            "${widget.user.first_name} ${widget.user.last_name}",
                            Icons.person,
                          ),
                          _infoRow(
                            "Doğum Tarihi",
                            _formatDate(widget.user.b_date),
                            Icons.cake,
                          ),
                          _infoRow(
                            "Yaş",
                            _getAge(widget.user.b_date),
                            Icons.timeline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        title: "İletişim Bilgileri",
                        icon: Icons.contact_phone,
                        color: Colors.green,
                        children: [
                          _infoRow("E-posta", widget.user.email, Icons.email),
                          _infoRow("Telefon", widget.user.phone, Icons.phone),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        title: "Hesap Bilgileri",
                        icon: Icons.account_circle,
                        color: Colors.purple,
                        children: [
                          _infoRow(
                            "Sistem ID",
                            widget.user.app,
                            Icons.fingerprint,
                          ),
                          _infoRow(
                            "Şube",
                            _getBranchName(branch),
                            Icons.business,
                          ),
                          _infoRow(
                            "Kayıt Tarihi",
                            _formatDate(widget.user.created_at),
                            Icons.calendar_today,
                          ),
                          _infoRow(
                            "Hesap Durumu",
                            _getStatusText(widget.user.is_active),
                            Icons.verified_user,
                          ),
                        ],
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
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
          // Kart başlığı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
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
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          // İçerik
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.indigo),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 250,
                child: Text(
                  value.isEmpty ? "Belirtilmemiş" : value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
*/
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class KisiselBilgilerPage extends StatefulWidget {
  final Users user;

  const KisiselBilgilerPage({super.key, required this.user});

  @override
  State<KisiselBilgilerPage> createState() => _KisiselBilgilerPageState();
}

class _KisiselBilgilerPageState extends State<KisiselBilgilerPage> {
  late Future<Map<String, dynamic>> _userDetailsFuture;
  bool _isUploading = false;
  late Users _currentUser; // 🔥 Değiştirilebilir kullanıcı nesnesi

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user; // 🔥 Kopyala
    _userDetailsFuture = _loadUserDetails();
  }

  // Ek bilgileri cache'den çek
  Future<Map<String, dynamic>> _loadUserDetails() async {
    try {
      Branches? branch;
      if (_currentUser.branches_id.isNotEmpty) {
        final branches = await GoogleSheetService.getBranchesCached();
        branch = branches.firstWhere(
          (b) => b.branches_id == _currentUser.branches_id,
          orElse: () => Branches(
            branches_id: "",
            name: "Belirtilmemiş",
            address: "",
            phone: "",
            email: "",
            created_at: "",
            is_active: '',
          ),
        );
      }
      return {'branch': branch};
    } catch (e) {
      print("Detay yükleme hatası: $e");
      return {'branch': null};
    }
  }

  // 🔥 PROFİL FOTOĞRAFI DEĞİŞTİRME FONKSİYONU
  Future<void> _changeProfilePhoto() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              "Profil Fotoğrafı Değiştir",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text("Kamerayla Çek"),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text("Galeriden Seç"),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // Fotoğraf seç ve yükle
  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() => _isUploading = true);

      try {
        final File imageFile = File(pickedFile.path);
        final fileName =
            "user_${_currentUser.app}_${DateTime.now().millisecondsSinceEpoch}.jpg";

        // 🔥 Fotoğrafı yükle ve URL al
        final imageUrl = await GoogleSheetService.uploadImageToDrive(
          imageFile,
          fileName,
          "profile_photos",
          targetUserId: _currentUser.app,
          targetField: "profile_photo_url",
        );

        if (imageUrl != null && mounted) {
          // 🔥 Kullanıcı nesnesini güncelle
          setState(() {
            _currentUser = Users(
              app: _currentUser.app,
              first_name: _currentUser.first_name,
              last_name: _currentUser.last_name,
              email: _currentUser.email,
              phone: _currentUser.phone,
              b_date: _currentUser.b_date,
              role: _currentUser.role,
              branches_id: _currentUser.branches_id,
              created_at: _currentUser.created_at,
              is_active: _currentUser.is_active,
              profile_photo_url: imageUrl,
              password_hash: '',
              amount: '',
              last_login: '', // Yeni fotoğraf URL'si
              // _user veya _currentUser
            );
          });

          // Local'deki kayıtlı kullanıcıyı da güncelle
          await _updateSavedUser(imageUrl);

          // Cache'i temizle
          GoogleSheetService.invalidateCache('users');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Profil fotoğrafı güncellendi"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          throw Exception("Fotoğraf yüklenemedi");
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Fotoğraf yüklenirken hata: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  // Local'deki kullanıcıyı güncelle
  Future<void> _updateSavedUser(String newPhotoUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserJson = prefs.getString('logged_user');
      if (savedUserJson != null) {
        Map<String, dynamic> userMap = jsonDecode(savedUserJson);
        userMap['profile_photo_url'] = newPhotoUrl;
        await prefs.setString('logged_user', jsonEncode(userMap));
      }
    } catch (e) {
      print("Local kullanıcı güncelleme hatası: $e");
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return dateStr;
    }
  }

  String _getAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return "?";
    try {
      final date = DateTime.parse(birthDate);
      final now = DateTime.now();
      int age = now.year - date.year;
      if (now.month < date.month ||
          (now.month == date.month && now.day < date.day)) {
        age--;
      }
      return "$age yaşında";
    } catch (e) {
      return "?";
    }
  }

  String _getRoleText(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return 'Öğrenci';
      case 'coach':
        return 'Antrenör';
      case 'parent':
        return 'Veli';
      default:
        return role;
    }
  }

  String _getStatusText(String isActive) {
    return isActive.toLowerCase() == "true" ? "Aktif" : "Pasif";
  }

  String _getBranchName(Branches? branch) {
    if (branch == null) return _currentUser.branches_id;
    return branch.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Profilim",
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
              GoogleSheetService.invalidateCache('branches');
              GoogleSheetService.invalidateCache('users');
              setState(() {
                _userDetailsFuture = _loadUserDetails();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _userDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text("Profil bilgileri yükleniyor..."),
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
                    onPressed: () {
                      setState(() {
                        _userDetailsFuture = _loadUserDetails();
                      });
                    },
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            );
          }

          final branch = snapshot.data?['branch'] as Branches?;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Üst profil kartı
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // 🔥 PROFİL FOTOĞRAFI (TIKLANABİLİR)
                        GestureDetector(
                          onTap: _isUploading ? null : _changeProfilePhoto,
                          child: Stack(
                            children: [
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFF59E0B),
                                      Color(0xFFEF4444),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.transparent,
                                  backgroundImage:
                                      _currentUser.profile_photo_url.isNotEmpty
                                      ? NetworkImage(
                                          _currentUser.profile_photo_url,
                                        )
                                      : null,
                                  child: _currentUser.profile_photo_url.isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                              // Kamera ikonu
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              // Yükleme göstergesi
                              if (_isUploading)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "${_currentUser.first_name} ${_currentUser.last_name}",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.orange,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _currentUser.role.toLowerCase() == 'student'
                                    ? Icons.school
                                    : _currentUser.role.toLowerCase() == 'coach'
                                    ? Icons.sports
                                    : Icons.family_restroom,
                                size: 14,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getRoleText(_currentUser.role),
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              _buildStatCard(
                                "Yaş",
                                _getAge(_currentUser.b_date),
                                Icons.cake,
                                Colors.pink,
                              ),
                              _buildStatCard(
                                "Durum",
                                _getStatusText(_currentUser.is_active),
                                Icons.verified,
                                Colors.green,
                              ),
                              _buildStatCard(
                                "Şube",
                                _getBranchName(branch),
                                Icons.location_on,
                                Colors.blue,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoCard(
                        title: "Kişisel Bilgiler",
                        icon: Icons.person_outline,
                        color: Colors.blue,
                        children: [
                          _infoRow(
                            "Ad Soyad",
                            "${_currentUser.first_name} ${_currentUser.last_name}",
                            Icons.person,
                          ),
                          _infoRow(
                            "Doğum Tarihi",
                            _formatDate(_currentUser.b_date),
                            Icons.cake,
                          ),
                          _infoRow(
                            "Yaş",
                            _getAge(_currentUser.b_date),
                            Icons.timeline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        title: "İletişim Bilgileri",
                        icon: Icons.contact_phone,
                        color: Colors.green,
                        children: [
                          _infoRow("E-posta", _currentUser.email, Icons.email),
                          _infoRow("Telefon", _currentUser.phone, Icons.phone),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        title: "Hesap Bilgileri",
                        icon: Icons.account_circle,
                        color: Colors.purple,
                        children: [
                          _infoRow(
                            "Sistem ID",
                            _currentUser.app,
                            Icons.fingerprint,
                          ),
                          _infoRow(
                            "Şube",
                            _getBranchName(branch),
                            Icons.business,
                          ),
                          _infoRow(
                            "Kayıt Tarihi",
                            _formatDate(_currentUser.created_at),
                            Icons.calendar_today,
                          ),
                          _infoRow(
                            "Hesap Durumu",
                            _getStatusText(_currentUser.is_active),
                            Icons.verified_user,
                          ),
                        ],
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
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
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.indigo),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 250,
                child: Text(
                  value.isEmpty ? "Belirtilmemiş" : value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
