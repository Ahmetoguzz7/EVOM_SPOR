/*import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class AdvancedSignUpPage extends StatefulWidget {
  const AdvancedSignUpPage({super.key});

  @override
  State<AdvancedSignUpPage> createState() => _AdvancedSignUpPageState();
}

class _AdvancedSignUpPageState extends State<AdvancedSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _formKeyParent = GlobalKey<FormState>();

  // MODE: "register" veya "update"
  String _mode = "register";

  // Güncelleme için seçilen kullanıcı
  Users? _selectedUser;
  List<Users> _searchResults = [];
  String _searchQuery = "";
  bool _isSearching = false;

  // Kişisel bilgiler
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _createdDateController = TextEditingController();
  final TextEditingController _healthProblemsController =
      TextEditingController();

  // Veli bilgileri (isteğe bağlı)
  final TextEditingController _parentNameController = TextEditingController();
  final TextEditingController _parentSurnameController =
      TextEditingController();
  final TextEditingController _parentPhoneController = TextEditingController();
  final TextEditingController _parentEmailController = TextEditingController();

  // Seçimler
  String _selectedRole = 'student';
  String _selectedBranchId = '';
  String _selectedSportId = '';
  String _selectedGroupId = '';
  bool _hasParent = false;
  File? _profileImage;
  String _existingPhotoUrl = "";
  bool _isLoading = false;

  // Listeler
  List<Branches> _branches = [];
  List<Sports> _sports = [];
  List<Group> _groups = [];
  List<Users> _existingUsers = [];

  // =========================================================================
  // TARİH FONKSİYONLARI
  // =========================================================================

  String _formatDateForDB(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatDisplayDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      GoogleSheetService.getBranchesCached(),
      GoogleSheetService.getSportsCached(),
      GoogleSheetService.getGroupsCached(),
      GoogleSheetService.getUsersCached(),
    ]);

    _branches = results[0] as List<Branches>;
    _sports = results[1] as List<Sports>;
    _groups = results[2] as List<Group>;
    _existingUsers = results[3] as List<Users>;

    if (_branches.isNotEmpty) _selectedBranchId = _branches.first.branches_id;
    if (_sports.isNotEmpty) _selectedSportId = _sports.first.sports_id;
    if (_groups.isNotEmpty) _selectedGroupId = _groups.first.groups_id;

    setState(() => _isLoading = false);
  }

  void _searchUser(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _searchResults = [];
      } else {
        _searchResults = _existingUsers.where((user) {
          final role = user.role.toLowerCase();
          final isAllowedRole =
              role == "student" ||
              role == "öğrenci" ||
              role == "parent" ||
              role == "veli" ||
              role == "coach" ||
              role == "antrenör" ||
              role == "admin" ||
              role == "yönetici" ||
              role == "accountant" ||
              role == "muhasebeci";

          if (!isAllowedRole) return false;

          final fullName = "${user.first_name} ${user.last_name}".toLowerCase();
          final email = user.email.toLowerCase();
          final searchLower = query.toLowerCase();

          return fullName.contains(searchLower) || email.contains(searchLower);
        }).toList();

        print("🔍 Arama sonucu: ${_searchResults.length} kullanıcı bulundu");
      }
    });
  }

  void _loadUserToForm(Users user) {
    setState(() {
      _selectedUser = user;
      _nameController.text = user.first_name;
      _surnameController.text = user.last_name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
      _passwordController.text = "";

      String birthDate = user.b_date;
      if (birthDate.contains('T')) birthDate = birthDate.split('T')[0];
      _birthDateController.text = birthDate;

      String createdDate = user.created_at;
      if (createdDate.contains('T')) createdDate = createdDate.split('T')[0];
      _createdDateController.text = createdDate;

      _selectedBranchId = user.branches_id;
      _selectedRole = user.role;
      _selectedGroupId = _groups.isNotEmpty ? _groups.first.groups_id : "";
      _healthProblemsController.text = "";
      _existingPhotoUrl = user.profile_photo_url;
      _profileImage = null;
      _searchQuery = "";
      _searchResults = [];
      _isSearching = false;
    });

    _showSnackBar("${user.first_name} ${user.last_name} yükleniyor...");
  }

  Future<void> _updateUser() async {
    if (_selectedUser == null) {
      _showSnackBar("Lütfen önce bir kullanıcı seçin!", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    String? photoUrl = _existingPhotoUrl;
    if (_profileImage != null) {
      try {
        final fileName =
            "profile_${_selectedUser!.app}_${DateTime.now().millisecondsSinceEpoch}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          _profileImage!,
          fileName,
          "profile_photos",
          targetUserId: _selectedUser!.app,
          targetField: "profile_photo_url",
        );
      } catch (e) {
        print("Fotoğraf güncelleme hatası: $e");
      }
    }

    Map<String, dynamic> updatedData = {
      "app": _selectedUser!.app,
      "first_name": _nameController.text.trim(),
      "last_name": _surnameController.text.trim(),
      "email": _emailController.text.trim(),
      "phone": _phoneController.text.trim(),
      "role": _selectedRole,
      "branches_id": _selectedBranchId,
      "b_date": _birthDateController.text.trim(),
      "created_at": _createdDateController.text.trim(),
      "amount": "",
      "profile_photo_url": photoUrl ?? "",
    };

    if (_passwordController.text.trim().isNotEmpty) {
      updatedData["password_hash"] = _passwordController.text.trim();
    }

    bool success = await GoogleSheetService.updateUser(updatedData);

    setState(() => _isLoading = false);

    if (success) {
      _showSnackBar("✅ Kullanıcı bilgileri güncellendi!");
      await _loadData();
      _clearForm();
      setState(() {
        _selectedUser = null;
        _existingPhotoUrl = "";
      });
    } else {
      _showSnackBar("❌ Güncelleme başarısız!", isError: true);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _surnameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _birthDateController.clear();
    _createdDateController.clear();
    _healthProblemsController.clear();
    _selectedBranchId = _branches.isNotEmpty ? _branches.first.branches_id : "";
    _selectedSportId = _sports.isNotEmpty ? _sports.first.sports_id : "";
    _selectedGroupId = _groups.isNotEmpty ? _groups.first.groups_id : "";
    _profileImage = null;
    _existingPhotoUrl = "";
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 7)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Doğum Tarihi Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = _formatDateForDB(picked);
      });
    }
  }

  Future<void> _selectCreatedDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Kayıt Tarihi Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked != null) {
      setState(() {
        _createdDateController.text = _formatDateForDB(picked);
      });
    }
  }

  Future<bool> _checkEmailExists(String email) async {
    if (email.isEmpty) return false;
    return _existingUsers.any(
      (u) => u.email.toLowerCase() == email.toLowerCase(),
    );
  }

  // =========================================================================
  // 🔥 DÜZELTİLMİŞ KAYIT METODU - GRUP ATAMASI ÇALIŞIYOR!
  // =========================================================================
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final emailExists = await _checkEmailExists(email);
    if (emailExists) {
      _showSnackBar("❌ Bu e-posta adresi zaten kayıtlı!", isError: true);
      return;
    }

    if (_hasParent && !_formKeyParent.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String? photoUrl = "";
    if (_profileImage != null) {
      try {
        final fileName = "profile_${DateTime.now().millisecondsSinceEpoch}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          _profileImage!,
          fileName,
          "profile_photos",
        );
        print("✅ Fotoğraf yüklendi: $photoUrl");
      } catch (e) {
        print("Resim yükleme hatası: $e");
        photoUrl = "";
      }
    }

    // KULLANICI BİLGİLERİ
    Map<String, dynamic> userInfo = {
      "app": "",
      "branches_id": _selectedBranchId,
      "first_name": _nameController.text.trim(),
      "last_name": _surnameController.text.trim(),
      "email": email,
      "phone": _phoneController.text.trim(),
      "password_hash": _passwordController.text.trim(),
      "role": _selectedRole,
      "profile_photo_url": photoUrl ?? "",
      "amount": "0",
      "b_date": _birthDateController.text.trim().isEmpty
          ? DateTime.now().toIso8601String().substring(0, 10)
          : _birthDateController.text.trim(),
      "created_at": _createdDateController.text.trim().isEmpty
          ? DateTime.now().toIso8601String().substring(0, 10)
          : _createdDateController.text.trim(),
      "last_login": "",
      "is_active": "TRUE",
    };

    Map<String, dynamic> allData = {
      "user_info": userInfo,
      "sports_id": _selectedSportId,
    };

    if (_healthProblemsController.text.trim().isNotEmpty) {
      allData["health_problems"] = _healthProblemsController.text.trim();
    }

    if (_hasParent) {
      allData["parent_info"] = {
        "first_name": _parentNameController.text.trim(),
        "last_name": _parentSurnameController.text.trim(),
        "phone": _parentPhoneController.text.trim(),
        "email": _parentEmailController.text.trim(),
      };
    }

    // 🔥 GRUP ID'SİNİ KAYIT VERİSİNE EKLE
    final selectedGroupIdForSave =
        _selectedGroupId.isNotEmpty && _selectedGroupId != "none"
        ? _selectedGroupId
        : "";

    if (selectedGroupIdForSave.isNotEmpty) {
      allData["group_id"] = selectedGroupIdForSave;
      print("📌 Kayıt olacak grup ID: $selectedGroupIdForSave");
    }

    // KAYDI GERÇEKLEŞTİR
    bool result = await GoogleSheetService.registerEverywhere(allData);

    // 🔥 KAYIT BAŞARILIYSA VE GRUP SEÇİLDİYSE, GRUP ATAMASINI YAP
    if (result && selectedGroupIdForSave.isNotEmpty) {
      print("🔄 Grup ataması yapılıyor...");

      // Yeni kullanıcıyı bulmak için biraz bekle (Apps Script'in kaydı tamamlaması için)
      await Future.delayed(const Duration(milliseconds: 1000));

      // Kullanıcıyı e-posta ile bul
      final allUsers = await GoogleSheetService.getUsersCached(
        forceRefresh: true,
      );
      final newUser = allUsers.firstWhere(
        (u) => u.email.toLowerCase() == email,
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

      if (newUser.app.isNotEmpty) {
        print(
          "✅ Yeni kullanıcı bulundu: ${newUser.app} - ${newUser.first_name}",
        );

        // Öğrenciyi gruba ekle
        final groupResult = await GoogleSheetService.assignStudentToGroup(
          newUser.app,
          selectedGroupIdForSave,
        );

        if (groupResult) {
          print("✅ Öğrenci başarıyla gruba eklendi!");
          _showSnackBar("✅ Kayıt başarılı! Öğrenci gruba eklendi.");
        } else {
          print("⚠️ Kayıt başarılı ama grup ataması yapılamadı!");
          _showSnackBar(
            "⚠️ Kayıt başarılı ama grup ataması yapılamadı. Lütfen manuel ekleyin.",
            isError: false,
          );
        }
      } else {
        print("❌ Yeni kullanıcı bulunamadı!");
        _showSnackBar("✅ Kayıt başarılı! Grubu manuel olarak atayabilirsiniz.");
      }
    } else if (result) {
      _showSnackBar("✅ Kayıt başarılı!");
    } else {
      _showSnackBar("❌ Kayıt başarısız!", isError: true);
    }

    setState(() => _isLoading = false);

    if (result && mounted) {
      _clearForm();
      await _loadData();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getRoleText(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return 'Öğrenci';
      case 'öğrenci':
        return 'Öğrenci';
      case 'parent':
        return 'Veli';
      case 'veli':
        return 'Veli';
      case 'coach':
        return 'Antrenör';
      case 'antrenör':
        return 'Antrenör';
      case 'admin':
        return 'Admin';
      case 'yönetici':
        return 'Admin';
      case 'accountant':
        return 'Muhasebeci';
      case 'muhasebeci':
        return 'Muhasebeci';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Kullanıcı Yönetimi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading && _branches.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1E293B)),
                  SizedBox(height: 16),
                  Text("Veriler yükleniyor..."),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // MODE SEÇİCİ TOGGLE
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _mode = "register";
                                _selectedUser = null;
                                _clearForm();
                                _isSearching = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _mode == "register"
                                    ? const Color(0xFF1E293B)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_add,
                                    size: 20,
                                    color: _mode == "register"
                                        ? Colors.white
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Yeni Kayıt",
                                    style: TextStyle(
                                      color: _mode == "register"
                                          ? Colors.white
                                          : Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _mode = "update";
                                _clearForm();
                                _isSearching = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _mode == "update"
                                    ? const Color(0xFF1E293B)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: _mode == "update"
                                        ? Colors.white
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Güncelle",
                                    style: TextStyle(
                                      color: _mode == "update"
                                          ? Colors.white
                                          : Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_mode == "update") ...[
                    _buildSearchSection(),
                    const SizedBox(height: 20),
                  ],

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPhotoSection(),
                        const SizedBox(height: 20),
                        _buildPersonalInfoSection(),
                        const SizedBox(height: 20),
                        _buildSelectionSection(),
                        const SizedBox(height: 20),
                        if (_selectedRole == 'student' ||
                            _selectedRole == 'öğrenci')
                          _buildHealthSection(),
                        const SizedBox(height: 20),
                        if (_selectedRole == 'student' ||
                            _selectedRole == 'öğrenci')
                          _buildParentSection(),
                        const SizedBox(height: 20),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Color(0xFF1E293B)),
                SizedBox(width: 10),
                Text(
                  "Kullanıcı Ara",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: _searchUser,
                  decoration: InputDecoration(
                    hintText: "İsim, soyisim veya e-posta ile ara...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchUser(""),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        final roleText = _getRoleText(user.role);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: Text(user.first_name[0].toUpperCase()),
                          ),
                          title: Text("${user.first_name} ${user.last_name}"),
                          subtitle: Text("${user.email} • $roleText"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _loadUserToForm(user),
                        );
                      },
                    ),
                  ),
                if (_searchQuery.isNotEmpty && _searchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Text(
                        "⚠️ '$_searchQuery' ile eşleşen kullanıcı bulunamadı",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
                border: Border.all(color: const Color(0xFF1E293B), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                image: _profileImage != null
                    ? DecorationImage(
                        image: FileImage(_profileImage!),
                        fit: BoxFit.cover,
                      )
                    : (_existingPhotoUrl.isNotEmpty && _profileImage == null)
                    ? DecorationImage(
                        image: NetworkImage(_existingPhotoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (_profileImage == null && _existingPhotoUrl.isEmpty)
                  ? const Icon(
                      Icons.camera_alt,
                      size: 40,
                      color: Color(0xFF1E293B),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library, size: 18),
            label: Text(
              _existingPhotoUrl.isNotEmpty
                  ? "Fotoğrafı Değiştir"
                  : "Profil Fotoğrafı Seç",
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
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
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.person, color: Color(0xFF1E293B)),
                SizedBox(width: 10),
                Text(
                  "Kişisel Bilgiler",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTextField(_nameController, "Ad", Icons.person_outline),
                const SizedBox(height: 12),
                _buildTextField(
                  _surnameController,
                  "Soyad",
                  Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _emailController,
                  "E-posta",
                  Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _phoneController,
                  "Telefon",
                  Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _passwordController,
                  "Şifre",
                  Icons.lock,
                  isPassword: true,
                  isRequired: _mode == "register",
                ),
                const SizedBox(height: 12),
                _buildDateField(),
                const SizedBox(height: 12),
                _buildCreatedDateField(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectBirthDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            const Icon(Icons.cake, color: Color(0xFF1E293B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _birthDateController.text.isEmpty
                    ? "Doğum Tarihi Seçin"
                    : _formatDisplayDate(_birthDateController.text),
                style: TextStyle(
                  color: _birthDateController.text.isEmpty
                      ? Colors.grey.shade500
                      : Colors.black,
                ),
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedDateField() {
    return InkWell(
      onTap: _selectCreatedDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            const Icon(Icons.create, color: Color(0xFF1E293B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _createdDateController.text.isEmpty
                    ? "Kayıt Tarihi Seçin"
                    : _formatDisplayDate(_createdDateController.text),
                style: TextStyle(
                  color: _createdDateController.text.isEmpty
                      ? Colors.grey.shade500
                      : Colors.black,
                ),
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionSection() {
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
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.settings, color: Color(0xFF1E293B)),
                SizedBox(width: 10),
                Text(
                  "Kayıt Bilgileri",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildRoleSelection(),
                const SizedBox(height: 16),
                _buildDropdown(
                  label: "Şube Seç",
                  value: _selectedBranchId,
                  items: _branches
                      .map(
                        (b) => DropdownMenuItem(
                          value: b.branches_id,
                          child: Text(b.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedBranchId = v!),
                ),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: "Spor Dalı",
                  value: _selectedSportId,
                  items: _sports
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.sports_id,
                          child: Text(s.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSportId = v!),
                ),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: "Bağlı Grup",
                  value: _selectedGroupId.isEmpty ? "none" : _selectedGroupId,
                  items: [
                    const DropdownMenuItem(
                      value: "none",
                      child: Text("-- Grup Seçilmedi --"),
                    ),
                    ..._groups.map(
                      (g) => DropdownMenuItem(
                        value: g.groups_id,
                        child: Text(g.name),
                      ),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedGroupId = v == "none" ? "" : v!),
                ),
                if (_selectedGroupId.isNotEmpty && _selectedGroupId != "none")
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Kayıt sırasında öğrenci bu gruba eklenecektir.",
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 11,
                            ),
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
    );
  }

  Widget _buildRoleSelection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildRadioTile(
            title: "Öğrenci / Sporcu",
            subtitle: "Gelişim takibi ve programlar için",
            value: 'student',
          ),
          const Divider(height: 1),
          _buildRadioTile(
            title: "Veli",
            subtitle: "Sporcu ödemeleri ve yoklama takibi için",
            value: 'parent',
          ),
          const Divider(height: 1),
          _buildRadioTile(
            title: "Antrenör / Koç",
            subtitle: "Sporcu yönetimi ve ders takibi için",
            value: 'coach',
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required String value,
  }) {
    return RadioListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      groupValue: _selectedRole,
      activeColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      onChanged: (val) => setState(() => _selectedRole = val.toString()),
    );
  }

  Widget _buildHealthSection() {
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
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.health_and_safety, color: Color(0xFF1E293B)),
                SizedBox(width: 10),
                Text(
                  "Sağlık Bilgileri",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _healthProblemsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    "Varsa sağlık problemlerini belirtin (alerji, astım, kalp rahatsızlığı vb.)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E293B),
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(
                  Icons.medical_services,
                  color: Color(0xFF1E293B),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentSection() {
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
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.family_restroom, color: Color(0xFF1E293B)),
                const SizedBox(width: 10),
                const Text(
                  "Veli Bilgileri",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Switch(
                  value: _hasParent,
                  onChanged: (val) => setState(() => _hasParent = val),
                  activeColor: const Color(0xFF1E293B),
                ),
                Text(_hasParent ? "Eklenecek" : "Atlanacak"),
              ],
            ),
          ),
          if (_hasParent)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKeyParent,
                child: Column(
                  children: [
                    _buildTextField(
                      _parentNameController,
                      "Veli Adı",
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _parentSurnameController,
                      "Veli Soyadı",
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _parentPhoneController,
                      "Veli Telefon",
                      Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _parentEmailController,
                      "Veli E-posta",
                      Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  "Veli bilgisi eklenmeyecek.\nİsterseniz daha sonra ekleyebilirsiniz.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _isLoading
            ? null
            : (_mode == "register" ? _handleRegister : _updateUser),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _mode == "register" ? "HESAP OLUŞTUR" : "BİLGİLERİ GÜNCELLE",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    bool isRequired = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E293B), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E293B), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: isRequired
          ? (v) => v == null || v.isEmpty ? "Bu alan zorunlu" : null
          : null,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    final bool hasValidValue = items.any((item) => item.value == value);
    final String? selectedValue = hasValidValue ? value : null;

    return DropdownButtonFormField<String>(
      value: selectedValue,
      hint: Text(label),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(
          Icons.arrow_drop_down_circle,
          color: Color(0xFF1E293B),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E293B), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: items,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down),
      dropdownColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _birthDateController.dispose();
    _createdDateController.dispose();
    _healthProblemsController.dispose();
    _parentNameController.dispose();
    _parentSurnameController.dispose();
    _parentPhoneController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }
}
*/
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class AdvancedSignUpPage extends StatefulWidget {
  const AdvancedSignUpPage({super.key});

  @override
  State<AdvancedSignUpPage> createState() => _AdvancedSignUpPageState();
}

class _AdvancedSignUpPageState extends State<AdvancedSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _formKeyParent = GlobalKey<FormState>();

  // MODE: "register" veya "update"
  String _mode = "register";

  // Güncelleme için seçilen kullanıcı
  Users? _selectedUser;
  List<Users> _searchResults = [];
  String _searchQuery = "";
  bool _isSearching = false;

  // Kişisel bilgiler
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _createdDateController = TextEditingController();
  final TextEditingController _healthProblemsController =
      TextEditingController();

  // Veli bilgileri (isteğe bağlı)
  final TextEditingController _parentNameController = TextEditingController();
  final TextEditingController _parentSurnameController =
      TextEditingController();
  final TextEditingController _parentPhoneController = TextEditingController();
  final TextEditingController _parentEmailController = TextEditingController();

  // Seçimler
  String _selectedRole = 'student';
  String _selectedBranchId = '';
  String _selectedSportId = '';
  String _selectedGroupId = '';
  bool _hasParent = false;
  File? _profileImage;
  String _existingPhotoUrl = "";
  bool _isLoading = false;
  bool _isBackgroundProcessing = false; // Arka plan işlemi için

  // Listeler
  List<Branches> _branches = [];
  List<Sports> _sports = [];
  List<Group> _groups = [];
  List<Users> _existingUsers = [];

  // =========================================================================
  // TARİH FONKSİYONLARI
  // =========================================================================

  String _formatDateForDB(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatDisplayDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Belirtilmemiş";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd/MM/yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      GoogleSheetService.getBranchesCached(),
      GoogleSheetService.getSportsCached(),
      GoogleSheetService.getGroupsCached(),
      GoogleSheetService.getUsersCached(),
    ]);

    _branches = results[0] as List<Branches>;
    _sports = results[1] as List<Sports>;
    _groups = results[2] as List<Group>;
    _existingUsers = results[3] as List<Users>;

    if (_branches.isNotEmpty) _selectedBranchId = _branches.first.branches_id;
    if (_sports.isNotEmpty) _selectedSportId = _sports.first.sports_id;
    if (_groups.isNotEmpty) _selectedGroupId = _groups.first.groups_id;

    setState(() => _isLoading = false);
  }

  // 🔄 Arka planda verileri yenile
  Future<void> _refreshDataInBackground() async {
    setState(() => _isBackgroundProcessing = true);

    try {
      // Tüm verileri force refresh ile yenile
      final results = await Future.wait([
        GoogleSheetService.getBranchesCached(forceRefresh: true),
        GoogleSheetService.getSportsCached(forceRefresh: true),
        GoogleSheetService.getGroupsCached(forceRefresh: true),
        GoogleSheetService.getUsersCached(forceRefresh: true),
      ]);

      _branches = results[0] as List<Branches>;
      _sports = results[1] as List<Sports>;
      _groups = results[2] as List<Group>;
      _existingUsers = results[3] as List<Users>;

      if (_branches.isNotEmpty && _selectedBranchId.isEmpty) {
        _selectedBranchId = _branches.first.branches_id;
      }
      if (_sports.isNotEmpty && _selectedSportId.isEmpty) {
        _selectedSportId = _sports.first.sports_id;
      }

      print("✅ Arka plan veri yenileme tamamlandı!");
    } catch (e) {
      print("❌ Arka plan veri yenileme hatası: $e");
    } finally {
      if (mounted) {
        setState(() => _isBackgroundProcessing = false);
      }
    }
  }

  // 🎉 Sağ üstten bildirim göster
  void _showSuccessNotification(String title, String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _searchUser(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _searchResults = [];
      } else {
        _searchResults = _existingUsers.where((user) {
          final role = user.role.toLowerCase();
          final isAllowedRole =
              role == "student" ||
              role == "öğrenci" ||
              role == "parent" ||
              role == "veli" ||
              role == "coach" ||
              role == "antrenör" ||
              role == "admin" ||
              role == "yönetici" ||
              role == "accountant" ||
              role == "muhasebeci";

          if (!isAllowedRole) return false;

          final fullName = "${user.first_name} ${user.last_name}".toLowerCase();
          final email = user.email.toLowerCase();
          final searchLower = query.toLowerCase();

          return fullName.contains(searchLower) || email.contains(searchLower);
        }).toList();

        print("🔍 Arama sonucu: ${_searchResults.length} kullanıcı bulundu");
      }
    });
  }

  void _loadUserToForm(Users user) {
    setState(() {
      _selectedUser = user;
      _nameController.text = user.first_name;
      _surnameController.text = user.last_name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
      _passwordController.text = "";

      String birthDate = user.b_date;
      if (birthDate.contains('T')) birthDate = birthDate.split('T')[0];
      _birthDateController.text = birthDate;

      String createdDate = user.created_at;
      if (createdDate.contains('T')) createdDate = createdDate.split('T')[0];
      _createdDateController.text = createdDate;

      _selectedBranchId = user.branches_id;
      _selectedRole = user.role;
      _selectedGroupId = _groups.isNotEmpty ? _groups.first.groups_id : "";
      _healthProblemsController.text = "";
      _existingPhotoUrl = user.profile_photo_url;
      _profileImage = null;
      _searchQuery = "";
      _searchResults = [];
      _isSearching = false;
    });

    _showSnackBar("${user.first_name} ${user.last_name} yükleniyor...");
  }

  Future<void> _updateUser() async {
    if (_selectedUser == null) {
      _showSnackBar("Lütfen önce bir kullanıcı seçin!", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    String? photoUrl = _existingPhotoUrl;
    if (_profileImage != null) {
      try {
        final fileName =
            "profile_${_selectedUser!.app}_${DateTime.now().millisecondsSinceEpoch}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          _profileImage!,
          fileName,
          "profile_photos",
          targetUserId: _selectedUser!.app,
          targetField: "profile_photo_url",
        );
      } catch (e) {
        print("Fotoğraf güncelleme hatası: $e");
      }
    }

    Map<String, dynamic> updatedData = {
      "app": _selectedUser!.app,
      "first_name": _nameController.text.trim(),
      "last_name": _surnameController.text.trim(),
      "email": _emailController.text.trim(),
      "phone": _phoneController.text.trim(),
      "role": _selectedRole,
      "branches_id": _selectedBranchId,
      "b_date": _birthDateController.text.trim(),
      "created_at": _createdDateController.text.trim(),
      "amount": "",
      "profile_photo_url": photoUrl ?? "",
    };

    if (_passwordController.text.trim().isNotEmpty) {
      updatedData["password_hash"] = _passwordController.text.trim();
    }

    bool success = await GoogleSheetService.updateUser(updatedData);

    if (success) {
      // Arka planda verileri yenile
      _refreshDataInBackground();
      _showSuccessNotification(
        "✅ Güncelleme Başarılı",
        "${_selectedUser!.first_name} ${_selectedUser!.last_name} bilgileri güncellendi.",
      );
      _clearForm();
      setState(() {
        _selectedUser = null;
        _existingPhotoUrl = "";
        _isLoading = false;
      });

      // 1 saniye sonra sayfayı kapat
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      setState(() => _isLoading = false);
      _showSnackBar("❌ Güncelleme başarısız!", isError: true);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _surnameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _birthDateController.clear();
    _createdDateController.clear();
    _healthProblemsController.clear();
    _selectedBranchId = _branches.isNotEmpty ? _branches.first.branches_id : "";
    _selectedSportId = _sports.isNotEmpty ? _sports.first.sports_id : "";
    _selectedGroupId = _groups.isNotEmpty ? _groups.first.groups_id : "";
    _profileImage = null;
    _existingPhotoUrl = "";
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 7)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Doğum Tarihi Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = _formatDateForDB(picked);
      });
    }
  }

  Future<void> _selectCreatedDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Kayıt Tarihi Seç',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked != null) {
      setState(() {
        _createdDateController.text = _formatDateForDB(picked);
      });
    }
  }

  Future<bool> _checkEmailExists(String email) async {
    if (email.isEmpty) return false;
    return _existingUsers.any(
      (u) => u.email.toLowerCase() == email.toLowerCase(),
    );
  }

  // =========================================================================
  // 🔥 GÜNCELLENMİŞ KAYIT METODU - ARKA PLAN İŞLEMİ VE BİLDİRİM
  // =========================================================================
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final emailExists = await _checkEmailExists(email);
    if (emailExists) {
      _showSnackBar("❌ Bu e-posta adresi zaten kayıtlı!", isError: true);
      return;
    }

    if (_hasParent && !_formKeyParent.currentState!.validate()) return;

    // Loading göster
    setState(() => _isLoading = true);

    String? photoUrl = "";
    if (_profileImage != null) {
      try {
        final fileName = "profile_${DateTime.now().millisecondsSinceEpoch}.jpg";
        photoUrl = await GoogleSheetService.uploadImageToDrive(
          _profileImage!,
          fileName,
          "profile_photos",
        );
        print("✅ Fotoğraf yüklendi: $photoUrl");
      } catch (e) {
        print("Resim yükleme hatası: $e");
        photoUrl = "";
      }
    }

    // KULLANICI BİLGİLERİ
    Map<String, dynamic> userInfo = {
      "app": "",
      "branches_id": _selectedBranchId,
      "first_name": _nameController.text.trim(),
      "last_name": _surnameController.text.trim(),
      "email": email,
      "phone": _phoneController.text.trim(),
      "password_hash": _passwordController.text.trim(),
      "role": _selectedRole,
      "profile_photo_url": photoUrl ?? "",
      "amount": "0",
      "b_date": _birthDateController.text.trim().isEmpty
          ? DateTime.now().toIso8601String().substring(0, 10)
          : _birthDateController.text.trim(),
      "created_at": _createdDateController.text.trim().isEmpty
          ? DateTime.now().toIso8601String().substring(0, 10)
          : _createdDateController.text.trim(),
      "last_login": "",
      "is_active": "TRUE",
    };

    Map<String, dynamic> allData = {
      "user_info": userInfo,
      "sports_id": _selectedSportId,
    };

    if (_healthProblemsController.text.trim().isNotEmpty) {
      allData["health_problems"] = _healthProblemsController.text.trim();
    }

    if (_hasParent) {
      allData["parent_info"] = {
        "first_name": _parentNameController.text.trim(),
        "last_name": _parentSurnameController.text.trim(),
        "phone": _parentPhoneController.text.trim(),
        "email": _parentEmailController.text.trim(),
      };
    }

    final selectedGroupIdForSave =
        _selectedGroupId.isNotEmpty && _selectedGroupId != "none"
        ? _selectedGroupId
        : "";

    if (selectedGroupIdForSave.isNotEmpty) {
      allData["group_id"] = selectedGroupIdForSave;
      print("📌 Kayıt olacak grup ID: $selectedGroupIdForSave");
    }

    // KAYDI GERÇEKLEŞTİR
    bool result = await GoogleSheetService.registerEverywhere(allData);

    if (result && selectedGroupIdForSave.isNotEmpty) {
      print("🔄 Grup ataması yapılıyor...");
      await Future.delayed(const Duration(milliseconds: 1000));

      final allUsers = await GoogleSheetService.getUsersCached(
        forceRefresh: true,
      );
      final newUser = allUsers.firstWhere(
        (u) => u.email.toLowerCase() == email,
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

      if (newUser.app.isNotEmpty) {
        print(
          "✅ Yeni kullanıcı bulundu: ${newUser.app} - ${newUser.first_name}",
        );
        final groupResult = await GoogleSheetService.assignStudentToGroup(
          newUser.app,
          selectedGroupIdForSave,
        );
        if (groupResult) {
          print("✅ Öğrenci başarıyla gruba eklendi!");
        } else {
          print("⚠️ Kayıt başarılı ama grup ataması yapılamadı!");
        }
      }
    }

    // ⭐ KRİTİK: Arka planda verileri yenile
    await _refreshDataInBackground();

    // ⭐ Loading'i kapat
    if (mounted) {
      setState(() => _isLoading = false);
    }

    // ⭐ Başarılı bildirimi göster
    if (result && mounted) {
      final studentName =
          "${_nameController.text.trim()} ${_surnameController.text.trim()}";
      _showSuccessNotification(
        "🎉 Kayıt Başarılı!",
        "$studentName başarıyla kaydedildi. Veriler arka planda güncelleniyor.",
      );

      // Formu temizle
      _clearForm();

      // 1.5 saniye sonra sayfayı kapat (bildirim görünsün diye)
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          // Sayfayı kapatmadan önce son bir kez daha verileri yenile
          _refreshDataInBackground();
          Navigator.of(context).pop();
        }
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
      _showSnackBar("❌ Kayıt başarısız!", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getRoleText(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return 'Öğrenci';
      case 'öğrenci':
        return 'Öğrenci';
      case 'parent':
        return 'Veli';
      case 'veli':
        return 'Veli';
      case 'coach':
        return 'Antrenör';
      case 'antrenör':
        return 'Antrenör';
      case 'admin':
        return 'Admin';
      case 'yönetici':
        return 'Admin';
      case 'accountant':
        return 'Muhasebeci';
      case 'muhasebeci':
        return 'Muhasebeci';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Kullanıcı Yönetimi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          // Arka plan işlemi varsa göster
          if (_isBackgroundProcessing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading && _branches.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1E293B)),
                  SizedBox(height: 16),
                  Text("Veriler yükleniyor..."),
                ],
              ),
            )
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // MODE SEÇİCİ TOGGLE
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _mode = "register";
                                    _selectedUser = null;
                                    _clearForm();
                                    _isSearching = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _mode == "register"
                                        ? const Color(0xFF1E293B)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_add,
                                        size: 20,
                                        color: _mode == "register"
                                            ? Colors.white
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Yeni Kayıt",
                                        style: TextStyle(
                                          color: _mode == "register"
                                              ? Colors.white
                                              : Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _mode = "update";
                                    _clearForm();
                                    _isSearching = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _mode == "update"
                                        ? const Color(0xFF1E293B)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        size: 20,
                                        color: _mode == "update"
                                            ? Colors.white
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Güncelle",
                                        style: TextStyle(
                                          color: _mode == "update"
                                              ? Colors.white
                                              : Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_mode == "update") ...[
                        _buildSearchSection(),
                        const SizedBox(height: 20),
                      ],

                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPhotoSection(),
                            const SizedBox(height: 20),
                            _buildPersonalInfoSection(),
                            const SizedBox(height: 20),
                            _buildSelectionSection(),
                            const SizedBox(height: 20),
                            if (_selectedRole == 'student' ||
                                _selectedRole == 'öğrenci')
                              _buildHealthSection(),
                            const SizedBox(height: 20),
                            if (_selectedRole == 'student' ||
                                _selectedRole == 'öğrenci')
                              _buildParentSection(),
                            const SizedBox(height: 20),
                            _buildSubmitButton(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Arka plan işlemi sırasında overlay
                if (_isBackgroundProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF1E293B),
                              ),
                              SizedBox(height: 16),
                              Text(
                                "Veriler arka planda güncelleniyor...",
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Color(0xFF1E293B)),
                SizedBox(width: 10),
                Text(
                  "Kullanıcı Ara",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: _searchUser,
                  decoration: InputDecoration(
                    hintText: "İsim, soyisim veya e-posta ile ara...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchUser(""),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        final roleText = _getRoleText(user.role);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: Text(user.first_name[0].toUpperCase()),
                          ),
                          title: Text("${user.first_name} ${user.last_name}"),
                          subtitle: Text("${user.email} • $roleText"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _loadUserToForm(user),
                        );
                      },
                    ),
                  ),
                if (_searchQuery.isNotEmpty && _searchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Text(
                        "⚠️ '$_searchQuery' ile eşleşen kullanıcı bulunamadı",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
                border: Border.all(color: const Color(0xFF1E293B), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                image: _profileImage != null
                    ? DecorationImage(
                        image: FileImage(_profileImage!),
                        fit: BoxFit.cover,
                      )
                    : (_existingPhotoUrl.isNotEmpty && _profileImage == null)
                    ? DecorationImage(
                        image: NetworkImage(_existingPhotoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (_profileImage == null && _existingPhotoUrl.isEmpty)
                  ? const Icon(
                      Icons.camera_alt,
                      size: 40,
                      color: Color(0xFF1E293B),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library, size: 18),
            label: Text(
              _existingPhotoUrl.isNotEmpty
                  ? "Fotoğrafı Değiştir"
                  : "Profil Fotoğrafı Seç",
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
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
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.person, color: Color(0xFF1E293B)),
                SizedBox(width: 10),
                Text(
                  "Kişisel Bilgiler",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTextField(_nameController, "Ad", Icons.person_outline),
                const SizedBox(height: 12),
                _buildTextField(
                  _surnameController,
                  "Soyad",
                  Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _emailController,
                  "E-posta",
                  Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _phoneController,
                  "Telefon",
                  Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _passwordController,
                  "Şifre",
                  Icons.lock,
                  isPassword: true,
                  isRequired: _mode == "register",
                ),
                const SizedBox(height: 12),
                _buildDateField(),
                const SizedBox(height: 12),
                _buildCreatedDateField(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectBirthDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            const Icon(Icons.cake, color: Color(0xFF1E293B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _birthDateController.text.isEmpty
                    ? "Doğum Tarihi Seçin"
                    : _formatDisplayDate(_birthDateController.text),
                style: TextStyle(
                  color: _birthDateController.text.isEmpty
                      ? Colors.grey.shade500
                      : Colors.black,
                ),
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedDateField() {
    return InkWell(
      onTap: _selectCreatedDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            const Icon(Icons.create, color: Color(0xFF1E293B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _createdDateController.text.isEmpty
                    ? "Kayıt Tarihi Seçin"
                    : _formatDisplayDate(_createdDateController.text),
                style: TextStyle(
                  color: _createdDateController.text.isEmpty
                      ? Colors.grey.shade500
                      : Colors.black,
                ),
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionSection() {
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
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.settings, color: Color(0xFF1E293B)),
                SizedBox(width: 10),
                Text(
                  "Kayıt Bilgileri",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildRoleSelection(),
                const SizedBox(height: 16),
                _buildDropdown(
                  label: "Şube Seç",
                  value: _selectedBranchId,
                  items: _branches
                      .map(
                        (b) => DropdownMenuItem(
                          value: b.branches_id,
                          child: Text(b.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedBranchId = v!),
                ),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: "Spor Dalı",
                  value: _selectedSportId,
                  items: _sports
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.sports_id,
                          child: Text(s.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSportId = v!),
                ),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: "Bağlı Grup",
                  value: _selectedGroupId.isEmpty ? "none" : _selectedGroupId,
                  items: [
                    const DropdownMenuItem(
                      value: "none",
                      child: Text("-- Grup Seçilmedi --"),
                    ),
                    ..._groups.map(
                      (g) => DropdownMenuItem(
                        value: g.groups_id,
                        child: Text(g.name),
                      ),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedGroupId = v == "none" ? "" : v!),
                ),
                if (_selectedGroupId.isNotEmpty && _selectedGroupId != "none")
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Kayıt sırasında öğrenci bu gruba eklenecektir.",
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 11,
                            ),
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
    );
  }

  Widget _buildRoleSelection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildRadioTile(
            title: "Öğrenci / Sporcu",
            subtitle: "Gelişim takibi ve programlar için",
            value: 'student',
          ),
          const Divider(height: 1),
          _buildRadioTile(
            title: "Veli",
            subtitle: "Sporcu ödemeleri ve yoklama takibi için",
            value: 'parent',
          ),
          const Divider(height: 1),
          _buildRadioTile(
            title: "Antrenör / Koç",
            subtitle: "Sporcu yönetimi ve ders takibi için",
            value: 'coach',
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required String value,
  }) {
    return RadioListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      groupValue: _selectedRole,
      activeColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      onChanged: (val) => setState(() => _selectedRole = val.toString()),
    );
  }

  Widget _buildHealthSection() {
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
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.health_and_safety, color: Color(0xFF1E293B)),
                SizedBox(width: 10),
                Text(
                  "Sağlık Bilgileri",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _healthProblemsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    "Varsa sağlık problemlerini belirtin (alerji, astım, kalp rahatsızlığı vb.)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E293B),
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(
                  Icons.medical_services,
                  color: Color(0xFF1E293B),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentSection() {
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
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.family_restroom, color: Color(0xFF1E293B)),
                const SizedBox(width: 10),
                const Text(
                  "Veli Bilgileri",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Switch(
                  value: _hasParent,
                  onChanged: (val) => setState(() => _hasParent = val),
                  activeColor: const Color(0xFF1E293B),
                ),
                Text(_hasParent ? "Eklenecek" : "Atlanacak"),
              ],
            ),
          ),
          if (_hasParent)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKeyParent,
                child: Column(
                  children: [
                    _buildTextField(
                      _parentNameController,
                      "Veli Adı",
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _parentSurnameController,
                      "Veli Soyadı",
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _parentPhoneController,
                      "Veli Telefon",
                      Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _parentEmailController,
                      "Veli E-posta",
                      Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  "Veli bilgisi eklenmeyecek.\nİsterseniz daha sonra ekleyebilirsiniz.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _isLoading || _isBackgroundProcessing
            ? null
            : (_mode == "register" ? _handleRegister : _updateUser),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _mode == "register" ? "HESAP OLUŞTUR" : "BİLGİLERİ GÜNCELLE",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    bool isRequired = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E293B), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E293B), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: isRequired
          ? (v) => v == null || v.isEmpty ? "Bu alan zorunlu" : null
          : null,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    final bool hasValidValue = items.any((item) => item.value == value);
    final String? selectedValue = hasValidValue ? value : null;

    return DropdownButtonFormField<String>(
      value: selectedValue,
      hint: Text(label),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(
          Icons.arrow_drop_down_circle,
          color: Color(0xFF1E293B),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E293B), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: items,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down),
      dropdownColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _birthDateController.dispose();
    _createdDateController.dispose();
    _healthProblemsController.dispose();
    _parentNameController.dispose();
    _parentSurnameController.dispose();
    _parentPhoneController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }
}
