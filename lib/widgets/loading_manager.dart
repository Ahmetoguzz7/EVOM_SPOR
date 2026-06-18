// lib/widgets/loading_manager.dart
import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/managerpage/manager_interface.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class AdminLoadingScreen extends StatefulWidget {
  final Users user;
  final String currentUserRole;
  const AdminLoadingScreen({
    super.key,
    required this.currentUserRole,
    required this.user,
  });

  @override
  State<AdminLoadingScreen> createState() => _AdminLoadingScreenState();
}

class _AdminLoadingScreenState extends State<AdminLoadingScreen>
    with SingleTickerProviderStateMixin {
  final AppRepository _repo = AppRepository();
  double _progress = 0.0;
  String _currentStep = "Başlatılıyor";
  String _detailMessage = "Sistem kontrol ediliyor...";
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String? _error;
  int _retryCount = 0;
  static const int MAX_RETRY = 2;
  bool _isLoading = true;

  final List<MapEntry<String, String>> _loadingSteps = [
    const MapEntry(
      "🔐 Hesap Doğrulanıyor",
      "Kullanıcı bilgileriniz kontrol ediliyor...",
    ),
    const MapEntry("👥 Kullanıcılar", "Tüm kullanıcı kayıtları taranıyor..."),
    const MapEntry("🏫 Şubeler", "Şube bilgileri yükleniyor..."),
    const MapEntry("👨‍🏫 Antrenörler", "Antrenör listesi hazırlanıyor..."),
    const MapEntry("👥 Gruplar", "Antrenman grupları yükleniyor..."),
    const MapEntry("💰 Ödemeler", "Finansal veriler işleniyor..."),
    const MapEntry("📅 Yoklamalar", "Yoklama kayıtları analiz ediliyor..."),
    const MapEntry("📢 Duyurular", "Bildirimler hazırlanıyor..."),
    const MapEntry("🖼️ Görseller", "Profil fotoğrafları ön yükleniyor..."),
    const MapEntry("✅ Hazır!", "Yönetim paneline yönlendiriliyorsunuz..."),
  ];

  final List<String> _tips = [
    "💡 İpucu: Yeni öğrenci kayıtlarını düzenli olarak kontrol edin!",
    "💡 İpucu: Ödeme takibini aksatmayın, otomatik hatırlatmalar gönderin!",
    "💡 İpucu: Antrenör performanslarını düzenli değerlendirin!",
    "💡 İpucu: Grupları güncel tutarak öğrenci dağılımını optimize edin!",
    "💡 İpucu: Duyuruları zamanında yaparak iletişimi güçlendirin!",
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startSimulatedProgress();
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startSimulatedProgress() {
    // Simüle edilmiş progress - her 200ms'de artar
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return false;
      if (_progress >= 0.95) return false;
      if (!_isLoading) return false;
      setState(() {
        _progress = (_progress + 0.02).clamp(0.0, 0.95);
        _updateLoadingStep(_progress);
      });
      return true;
    });
  }

  void _updateLoadingStep(double progress) {
    int stepIndex = (progress * _loadingSteps.length).floor();
    if (stepIndex >= _loadingSteps.length) stepIndex = _loadingSteps.length - 1;
    setState(() {
      _currentStep = _loadingSteps[stepIndex].key;
      _detailMessage = _loadingSteps[stepIndex].value;
    });
  }

  String _getRandomTip() {
    return _tips[DateTime.now().millisecondsSinceEpoch % _tips.length];
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "GÜNAYDIN";
    if (hour < 18) return "TÜNAYDIN";
    return "İYİ AKŞAMLAR";
  }

  Future<void> _loadData() async {
    try {
      // Verileri yükle (onProgress yok, direkt yükle)
      if (!_repo.isLoaded) {
        await _repo.loadAllData().timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw Exception("Bağlantı zaman aşımına uğradı"),
        );
      }

      // Fotoğrafları ön yükle
      await _repo.preloadProfilePhotosAsync(context);

      _isLoading = false;

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _updateLoadingStep(1.0);
        });

        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboard(currentUserRole: ''),
          ),
        );
      }
    } catch (e) {
      print("❌ Admin veri yükleme hatası: $e");
      _retryCount++;

      if (_retryCount < MAX_RETRY) {
        setState(() {
          _detailMessage =
              "Bağlantı sorunu, tekrar deneniyor... ($_retryCount/$MAX_RETRY)";
          _progress = 0.0;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _loadData();
        });
      } else {
        _showErrorDialog();
      }
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text("Bağlantı Hatası"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Veriler birden fazla kez denenmesine rağmen yüklenemedi.",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "İnternet bağlantınızı kontrol edin ve uygulamayı yeniden başlatın.",
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Sorun devam ederse:\n• İnternet bağlantınızı kontrol edin\n• Uygulamayı tamamen kapatıp açın\n• Daha sonra tekrar deneyin",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => exit(0),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("UYGULAMAYI KAPAT"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _retryCount = 0;
              _progress = 0.0;
              _isLoading = true;
              _startSimulatedProgress();
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("TEKRAR DENE"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                "Bağlantı Hatası",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Colors.grey[400])),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _progress = 0.0;
                    _currentStep = "Başlatılıyor";
                    _retryCount = 0;
                    _isLoading = true;
                  });
                  _startSimulatedProgress();
                  _loadData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                child: const Text("Tekrar Dene"),
              ),
            ],
          ),
        ),
      );
    }

    final tip = _getRandomTip();
    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.indigo.withOpacity(0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                              size: 65,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${widget.user.first_name} ${widget.user.last_name}",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            color: Colors.indigo.shade400,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${(_progress * 100).toInt()}%",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade300,
                                ),
                              ),
                            ),
                            Text(
                              "Adım ${((_progress * _loadingSteps.length).toInt() + 1).clamp(1, _loadingSteps.length)}/${_loadingSteps.length}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _currentStep,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 22),
                          child: Text(
                            _detailMessage,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.withOpacity(0.2),
                          Colors.orange.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.lightbulb,
                            color: Colors.amber,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                              height: 1.4,
                            ),
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
      ),
    );
  }
}
