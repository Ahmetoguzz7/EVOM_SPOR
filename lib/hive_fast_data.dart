// ============================================================
// ZORUNLU GÜNCELLEME EKRANI
// Kapatılamaz, geri gidilemez.
// Verileri parametre olarak alabilir, yoksa kendisi çeker.
// ============================================================

import 'package:EVOM_SPOR/main.dart';
import 'package:flutter/material.dart';

class ForceUpdateScreen extends StatefulWidget {
  final Map<String, dynamic>? updateData;

  const ForceUpdateScreen({super.key, this.updateData});

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  String _latestVersion = '';
  String _downloadUrl = '';
  String _releaseNotes = '';
  bool _loading = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    // Eğer tetiklenen fonksiyondan veri hazır geldiyse direkt kullan, yoksa istek at
    if (widget.updateData != null) {
      _parseUpdateData(widget.updateData!);
    } else {
      _loadUpdateInfo();
    }
  }

  void _parseUpdateData(Map<String, dynamic> data) {
    setState(() {
      _latestVersion = data['version'] ?? 'Bilinmiyor';
      _downloadUrl = data['downloadUrl'] ?? '';
      _releaseNotes = data['releaseNotes'] ?? 'Yeni sürüm mevcut.';
      _loading = false;
    });
  }

  Future<void> _loadUpdateInfo() async {
    final latestData = await getLatestReleaseFromGitHub();
    if (mounted) {
      if (latestData != null) {
        _parseUpdateData(latestData);
      } else {
        // Ağ hatası veya API limiti durumunda güvenli çıkış için loading'i kapatıyoruz
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _doUpdate() async {
    if (_downloadUrl.isEmpty) {
      await showSimpleNotification("Hata", "İndirme bağlantısı bulunamadı.");
      return;
    }
    setState(() => _downloading = true);
    await downloadAndInstallApk(_downloadUrl);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Donanımsal ve yazılımsal geri tuşunu tamamen engeller
      child: Scaffold(
        backgroundColor: const Color(0xFF1a237e),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // İkon Bölümü
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.system_update_alt,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Başlıklar
                      const Text(
                        'Güncelleme Gerekli',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Uygulamaya devam edebilmek için\ngüncelleme yapmanız zorunludur.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Sürüm ve Yenilikler Kartı
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.new_releases,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Yeni Sürüm: v$_latestVersion',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            if (_releaseNotes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(color: Colors.white24),
                              const SizedBox(height: 8),
                              const Text(
                                '✨ Yenilikler:',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _releaseNotes,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Güncelle Butonu
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _downloading ? null : _doUpdate,
                          icon: _downloading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.indigo,
                                  ),
                                )
                              : const Icon(
                                  Icons.download,
                                  color: Colors.indigo,
                                ),
                          label: Text(
                            _downloading ? 'İndiriliyor...' : 'Şimdi Güncelle',
                            style: const TextStyle(
                              color: Colors.indigo,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Alt Bilgi Notu
                      Text(
                        'Bu güncelleme zorunludur.\nGüncelleme yapmadan devam edilemez.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
