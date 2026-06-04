import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/password_hashing/password_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final PasswordService _passwordService = PasswordService();

  bool _isLoading = false;
  bool _codeSent = false;
  String _generatedCode = "";
  String _foundUserId = "";
  String _foundUserName = "";

  String _generateCode() {
    return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar("Lütfen e-posta adresinizi girin!", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Kullanıcıyı bul
      final allUsers = await GoogleSheetService.getUsers();
      final user = allUsers.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase(),
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

      if (user.app.isEmpty) {
        _showSnackBar(
          "❌ Bu e-posta adresine kayıtlı kullanıcı bulunamadı!",
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
      }

      // Kod üret
      _generatedCode = _generateCode();
      _foundUserId = user.app;
      _foundUserName = "${user.first_name} ${user.last_name}";

      // Kodu kaydet (15 dk geçerli)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('reset_code_${user.app}', _generatedCode);
      await prefs.setInt(
        'reset_code_expiry_${user.app}',
        DateTime.now().millisecondsSinceEpoch + (15 * 60 * 1000),
      );

      setState(() {
        _codeSent = true;
        _isLoading = false;
      });

      _showSnackBar("✅ Kod oluşturuldu! Lütfen aşağıdaki kodu not alın.");
    } catch (e) {
      _showSnackBar("Bir hata oluştu: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _verifyCode() async {
    final enteredCode = _codeController.text.trim();
    if (enteredCode.isEmpty) {
      _showSnackBar("Lütfen kodu girin!", isError: true);
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('reset_code_$_foundUserId');
    final expiry = prefs.getInt('reset_code_expiry_$_foundUserId') ?? 0;

    if (savedCode == null) {
      _showSnackBar("Kod bulunamadı! Lütfen yeni kod isteyin.", isError: true);
      return false;
    }

    if (DateTime.now().millisecondsSinceEpoch > expiry) {
      _showSnackBar(
        "Kodun süresi doldu! Lütfen yeni kod isteyin.",
        isError: true,
      );
      return false;
    }

    if (enteredCode != savedCode) {
      _showSnackBar("❌ Hatalı kod! Tekrar deneyin.", isError: true);
      return false;
    }

    return true;
  }

  Future<void> _resetPassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar("Lütfen yeni şifrenizi girin!", isError: true);
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar("Şifre en az 6 karakter olmalıdır!", isError: true);
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar("Şifreler eşleşmiyor!", isError: true);
      return;
    }

    // Kodu doğrula
    final isValid = await _verifyCode();
    if (!isValid) return;

    setState(() => _isLoading = true);

    // Yeni şifreyi hash'le ve kaydet
    final hashedPassword = _passwordService.hashPassword(newPassword);
    final success = await GoogleSheetService.updatePassword(
      _foundUserId,
      hashedPassword,
    );

    setState(() => _isLoading = false);

    if (success) {
      // Kodu temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('reset_code_$_foundUserId');
      await prefs.remove('reset_code_expiry_$_foundUserId');

      _showSnackBar("✅ Şifreniz başarıyla değiştirildi!");
      Navigator.pop(context);
    } else {
      _showSnackBar("❌ Şifre değiştirilemedi! Tekrar deneyin.", isError: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Şifremi Unuttum",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_reset, size: 80, color: Colors.indigo),
            const SizedBox(height: 20),
            const Text(
              "Şifrenizi mi unuttunuz?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "E-posta adresinizi girerek şifre sıfırlama kodunuzu alabilirsiniz.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // Email
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_codeSent,
              decoration: InputDecoration(
                labelText: "E-posta Adresi",
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (!_codeSent)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Kod Gönder",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),

            if (_codeSent) ...[
              // 🔥 KODU EKRANDA GÖSTER
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade700, Colors.indigo.shade900],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.security, size: 48, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      "Şifre Sıfırlama Kodunuz",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _generatedCode,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Yukarıdaki kodu aşağıya giriniz",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "15 dakika geçerlidir",
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 4),
                decoration: InputDecoration(
                  labelText: "6 Haneli Kod",
                  hintText: "••••••",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Yeni Şifre",
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Yeni Şifre (Tekrar)",
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Şifreyi Sıfırla",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
