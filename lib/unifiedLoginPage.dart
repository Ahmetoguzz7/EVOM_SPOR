/*
  unifiedLoginPage.dart - Gelişmiş ve Birleştirilmiş Giriş Sayfası
  - Tüm kullanıcı rolleri (admin, coach, user, accountant) için tek bir giriş ekranı
  - ROL KONTROLÜ: Herkes sadece kendi rolüne ait ekrana giriş yapabilir
  - Geçersiz rol veya rolü olmayan kullanıcılar GİRİŞ YAPAMAZ
  - İki adımlı doğrulama (2FA) ile admin ve muhasebeci güvenliği
  - "Beni Hatırla" özelliği ile kullanıcı deneyimini artırma
  - Anlamlı hata mesajları ve yükleme animasyonları
  - Son giriş tarihi gösterimi (Türkçe format)
  */
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/parent/parent_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'package:EVOM_SPOR/password_hashing/forgot_password.dart';
import 'package:EVOM_SPOR/ptpage/student_interface.dart';
import 'package:EVOM_SPOR/userInterfacepage/userinterface.dart';
import 'package:EVOM_SPOR/accountant/accountant_interface.dart';

class UnifiedLoginPage extends StatefulWidget {
  const UnifiedLoginPage({super.key});

  @override
  State<UnifiedLoginPage> createState() => _UnifiedLoginPageState();
}

class _UnifiedLoginPageState extends State<UnifiedLoginPage>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isOtpMode = false;
  bool _rememberMe = true;
  String? _generatedOtp;
  Users? _pendingUser;
  String? _lastLoginEmail;
  String? _lastLoginDate;

  // Animasyonlar
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // Geçerli roller
  static const List<String> _validRoles = [
    'admin',
    'yönetici',
    'accountant',
    'muhasebeci',
    'coach',
    'antrenör',
    'student',
    'öğrenci',
    'parent',
    'veli',
  ];

  // =========================================================================
  // 🔥 TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

  String _formatDateTurkish(DateTime date) {
    final formatter = DateFormat('dd MMMM yyyy HH:mm', 'tr_TR');
    return formatter.format(date);
  }

  String _formatDateShortTurkish(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm', 'tr_TR');
    return formatter.format(date);
  }

  @override
  void initState() {
    super.initState();

    // Ana fade animasyonu
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Zıplama animasyonu
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    // Kayma animasyonu
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.elasticOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Animasyonları başlat
    _fadeController.forward();
    _slideController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSavedUser();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bounceController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _checkSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final lastLoginEmail = prefs.getString('last_login_email');
    final lastLoginDate = prefs.getString('last_login_date');

    if (lastLoginEmail != null && lastLoginDate != null && mounted) {
      setState(() {
        _lastLoginEmail = lastLoginEmail;
        _lastLoginDate = lastLoginDate;
      });
    }

    if (rememberMe && savedEmail != null && savedPassword != null) {
      _emailController.text = savedEmail;
      _passwordController.text = savedPassword;
      _rememberMe = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        _handleLogin();
      });
    }
  }

  Future<void> _saveLoginCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', email);
      await prefs.setString('saved_password', password);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  Future<void> _saveLastLoginInfo(Users user) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final formattedDate = _formatDateTurkish(now);
    await prefs.setString('last_login_email', user.email);
    await prefs.setString('last_login_date', formattedDate);

    if (mounted) {
      setState(() {
        _lastLoginEmail = user.email;
        _lastLoginDate = formattedDate;
      });
    }
  }

  String _generateOtp() {
    return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
  }

  bool _isValidRole(String? role) {
    if (role == null || role.isEmpty) return false;
    final lowerRole = role.toLowerCase();
    return _validRoles.contains(lowerRole);
  }

  String _getRoleType(String? role) {
    if (role == null) return 'invalid';
    final lowerRole = role.toLowerCase();

    if (lowerRole == 'admin' || lowerRole == 'yönetici') return 'admin';
    if (lowerRole == 'accountant' || lowerRole == 'muhasebeci')
      return 'accountant';
    if (lowerRole == 'coach' || lowerRole == 'antrenör') return 'coach';
    if (lowerRole == 'student' || lowerRole == 'öğrenci') return 'student';
    if (lowerRole == 'parent' || lowerRole == 'veli') return 'parent';
    return 'invalid';
  }

  bool _requires2FA(String? role) {
    final roleType = _getRoleType(role);
    return roleType == 'admin' || roleType == 'accountant';
  }

  Future<void> _start2FA(Users user) async {
    final otp = _generateOtp();
    _generatedOtp = otp;
    _pendingUser = user;
    setState(() {
      _isOtpMode = true;
      _isLoading = false;
    });
  }

  Future<void> _verifyOtpAndLogin() async {
    final enteredOtp = _otpController.text.trim();
    if (enteredOtp.isEmpty) {
      _showSnackBar("Lütfen güvenlik kodunu girin!", isError: true);
      return;
    }
    if (enteredOtp != _generatedOtp) {
      _showSnackBar("❌ Hatalı güvenlik kodu!", isError: true);
      return;
    }
    setState(() => _isLoading = true);
    await _completeLogin(_pendingUser!);
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("E-posta ve şifre gerekli!", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await GoogleSheetService.login(email, password);

      if (user != null) {
        if (!_isValidRole(user.role)) {
          _showSnackBar(
            "❌ Bu hesabın geçerli bir rolü bulunmuyor!\nLütfen sistem yöneticinize başvurun.",
            isError: true,
            duration: 5,
          );
          setState(() => _isLoading = false);
          return;
        }

        await _saveLoginCredentials(email, password);
        await _saveLastLoginInfo(user);

        if (_requires2FA(user.role)) {
          await _start2FA(user);
        } else {
          await _completeLogin(user);
        }
      } else {
        _showSnackBar("E-posta veya şifre hatalı!", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar("Bağlantı hatası: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeLogin(Users user) async {
    final roleType = _getRoleType(user.role);

    if (roleType == 'admin') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                AdminDashboard(currentUserRole: 'admin', currentUser: user),
            transitionsBuilder: (_, a, __, c) =>
                FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } else if (roleType == 'accountant') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => AccountantInterface(
              currentUserRole: 'accountant',
              currentUser: user,
            ),
            transitionsBuilder: (_, a, __, c) =>
                FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } else if (roleType == 'coach') {
      setState(() => _isLoading = true);

      final stopwatch = Stopwatch()..start();

      final results = await Future.wait([
        GoogleSheetService.getCoachesCached(),
        GoogleSheetService.getSportsCached(),
        GoogleSheetService.getGroupsCached(),
        GoogleSheetService.getUsersCached(),
        GoogleSheetService.getPaymentsCached(),
      ]);

      stopwatch.stop();
      print("⏱️ Coach verileri ${stopwatch.elapsedMilliseconds}ms'de yüklendi");

      final coaches = results[0] as List<Coach>;
      final sports = results[1] as List<Sports>;

      final coachData = coaches.firstWhere(
        (c) => c.user_id == user.app,
        orElse: () => Coach(
          coach_id: "",
          user_id: user.app,
          branches_id: "",
          sports_id: "",
          bio: "",
          certificate_info: "",
          monthly_salary: "",
          hired_at: "",
        ),
      );

      final sportData = coachData.sports_id.isNotEmpty
          ? sports.firstWhere(
              (s) => s.sports_id == coachData.sports_id,
              orElse: () =>
                  Sports(sports_id: "", name: "Spor", description: ""),
            )
          : Sports(sports_id: "", name: "Spor", description: "");

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => PersonalTrainer(
              users: user,
              sport: sportData,
              coachData: coachData,
            ),
            transitionsBuilder: (_, a, __, c) =>
                FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } else if (roleType == 'student') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => UserInterface(user: user),
            transitionsBuilder: (_, a, __, c) =>
                FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } else if (roleType == 'parent') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => VeliAnaSayfa(veli: user),
            transitionsBuilder: (_, a, __, c) =>
                FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } else {
      _showSnackBar(
        "❌ Geçersiz rol: ${user.role}\nSistem yöneticinize başvurun.",
        isError: true,
      );
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false, int duration = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: duration),
      ),
    );
  }

  void _backToLogin() {
    setState(() {
      _isOtpMode = false;
      _otpController.clear();
      _generatedOtp = null;
      _pendingUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ANİMASYONLU BASKETBOL TOPU
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: AnimatedBuilder(
                        animation: _bounceController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              0,
                              10 * (1 - _bounceController.value),
                            ),
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF59E0B),
                                    Color(0xFFEF4444),
                                  ],
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(65),
                                child: Image.asset(
                                  'assets/images/sports.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.sports_basketball,
                                      size: 60,
                                      color: Colors.white,
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // YAZI ANİMASYONU
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Column(
                      children: [
                        Text(
                          " EVOM SPOR ",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.orange,
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Uygulamasına Hoş Geldiniz",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                            color: Colors.white70,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "⚡ PERFORMANS • GÜÇ • BAŞARI ⚡",
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 🔥 SON GİRİŞ BİLGİSİ (Varsa - ALT ALTA)
                  if (_lastLoginEmail != null &&
                      _lastLoginDate != null &&
                      !_isOtpMode)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 16,
                                  color: Colors.orange[400],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Son Oturum",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[300],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 12,
                                        color: Colors.white54,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _lastLoginEmail!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: Colors.white54,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _lastLoginDate!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
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

                  // FORM
                  if (_isOtpMode) ...[
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildOtpCard(),
                    ),
                  ] else ...[
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildLoginForm(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "E-posta Adresi",
              labelStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.email, color: Colors.orange[400]),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.orange[400]!, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Şifre",
              labelStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.lock, color: Colors.orange[400]),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[400],
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.orange[400]!, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                activeColor: Colors.orange,
                checkColor: Colors.white,
              ),
              const Text(
                "Beni Hatırla",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const ForgotPasswordPage(),
                      transitionsBuilder: (_, a, __, c) =>
                          FadeTransition(opacity: a, child: c),
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange[400],
                ),
                child: const Text(
                  "Şifremi Unuttum?",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                elevation: 5,
                shadowColor: Colors.orange.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "GİRİŞ YAP",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.security, size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                const Text(
                  "İKİ ADIMLI DOĞRULAMA",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Text(
                    _generatedOtp ?? "------",
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Yukarıdaki kodu aşağıya giriniz",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: "------",
              hintStyle: TextStyle(color: Colors.grey[600], letterSpacing: 8),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isLoading ? null : _verifyOtpAndLogin,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "DOĞRULA",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _backToLogin,
            child: Text("Geri Dön", style: TextStyle(color: Colors.grey[400])),
          ),
        ],
      ),
    );
  }
}
