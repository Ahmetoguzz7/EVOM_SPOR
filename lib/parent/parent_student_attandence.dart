/*
  Bu sayfa, velilerin çocuklarının yoklama durumlarını görmeleri için tasarlanmıştır.
  Veliler, çocuklarının hangi günlerde antrenmana katıldığını veya katılmadığını görebilirler.
  Ayrıca, farklı zaman aralıklarına göre filtreleme yaparak geçmiş yoklamaları inceleyebilirler.
  Sayfa, çocukların yoklama durumlarını görsel olarak özetleyen bir kart ve aylık katılım grafiği içerir.
*/
/*
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class VeliYoklamaSayfasi extends StatefulWidget {
  final Users cocuk;
  const VeliYoklamaSayfasi({super.key, required this.cocuk});

  @override
  State<VeliYoklamaSayfasi> createState() => _VeliYoklamaSayfasiState();
}

class _VeliYoklamaSayfasiState extends State<VeliYoklamaSayfasi> {
  List<Attendance> tumYoklamalar = [];
  List<Attendance> filtrelenmisYoklamalar = [];
  bool isLoading = true;

  String _selectedFilter = "Son 30 Gün";
  final List<String> _filterOptions = [
    "Haftalık",
    "Son 30 Gün",
    "Aylık",
    "Yıllık",
    "Tümü",
  ];

  @override
  void initState() {
    super.initState();
    _yoklamalariGetir();
  }

  Future<void> _yoklamalariGetir() async {
    try {
      final allAttendances = await GoogleSheetService.getAttendances();
      final data = allAttendances
          .where((a) => a.student_id == widget.cocuk.app)
          .toList();

      data.sort((a, b) => b.attendance_date.compareTo(a.attendance_date));

      setState(() {
        tumYoklamalar = data;
        _applyFilter();
        isLoading = false;
      });
    } catch (e) {
      print("Yoklama hatası: $e");
      setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedFilter) {
      case "Haftalık":
        startDate = now.subtract(const Duration(days: 7));
        break;
      case "Son 30 Gün":
        startDate = now.subtract(const Duration(days: 30));
        break;
      case "Aylık":
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case "Yıllık":
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(2000);
    }

    if (_selectedFilter == "Tümü") {
      filtrelenmisYoklamalar = tumYoklamalar;
    } else {
      filtrelenmisYoklamalar = tumYoklamalar.where((a) {
        final date = DateTime.parse(a.attendance_date);
        return date.isAfter(startDate);
      }).toList();
    }

    setState(() {});
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatShortDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Map<String, Map<String, int>> _getMonthlyStats() {
    Map<String, Map<String, int>> monthly = {};
    for (var att in filtrelenmisYoklamalar) {
      if (att.attendance_date.length >= 7) {
        String monthKey = att.attendance_date.substring(0, 7);
        if (!monthly.containsKey(monthKey)) {
          monthly[monthKey] = {"attended": 0, "missed": 0};
        }
        if (att.status == "TRUE") {
          monthly[monthKey]!["attended"] = monthly[monthKey]!["attended"]! + 1;
        } else {
          monthly[monthKey]!["missed"] = monthly[monthKey]!["missed"]! + 1;
        }
      }
    }
    return monthly;
  }

  @override
  Widget build(BuildContext context) {
    int attended = filtrelenmisYoklamalar
        .where((a) => a.status == "TRUE")
        .length;
    int missed = filtrelenmisYoklamalar.length - attended;
    double rate = filtrelenmisYoklamalar.isEmpty
        ? 0
        : (attended / filtrelenmisYoklamalar.length) * 100;
    Color rateColor = rate >= 80
        ? Colors.green
        : (rate >= 50 ? Colors.orange : Colors.red);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${widget.cocuk.first_name} ${widget.cocuk.last_name}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text("Yoklama Durumu", style: TextStyle(fontSize: 12)),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
                _applyFilter();
              });
            },
            itemBuilder: (context) => _filterOptions.map((filter) {
              return PopupMenuItem(
                value: filter,
                child: Row(
                  children: [
                    Icon(
                      filter == _selectedFilter
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: filter == _selectedFilter
                          ? Colors.indigo
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(filter),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingScreen()
          : filtrelenmisYoklamalar.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                // Filtre bilgisi
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.indigo,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedFilter,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${filtrelenmisYoklamalar.length} kayıt",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Özet Kartı
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
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
                            "Toplam",
                            "${filtrelenmisYoklamalar.length}",
                            Icons.calendar_today,
                            Colors.white,
                          ),
                          _buildStatItem(
                            "Katıldı",
                            "$attended",
                            Icons.check_circle,
                            Colors.green.shade300,
                          ),
                          _buildStatItem(
                            "Katılmadı",
                            "$missed",
                            Icons.cancel,
                            Colors.red.shade300,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  const Text(
                                    "Katılım Oranı",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "%${rate.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: rateColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: rate / 100,
                                backgroundColor: Colors.white.withOpacity(0.3),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Aylık Grafik
                _buildMonthlyChart(),
                const SizedBox(height: 16),
                // Liste Başlığı
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 20, color: Colors.indigo),
                      SizedBox(width: 8),
                      Text(
                        "Yoklama Geçmişi",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Yoklama Listesi
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtrelenmisYoklamalar.length,
                    itemBuilder: (context, index) {
                      final yoklama = filtrelenmisYoklamalar[index];
                      final isPresent = yoklama.status == "TRUE";
                      return _buildAttendanceCard(yoklama, isPresent);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.indigo),
          SizedBox(height: 16),
          Text("Yoklama verileri yükleniyor..."),
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
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildMonthlyChart() {
    final monthlyStats = _getMonthlyStats();
    if (monthlyStats.isEmpty) return const SizedBox.shrink();

    var sortedKeys = monthlyStats.keys.toList()..sort();
    double maxBarHeight = 100.0;

    final monthNames = [
      "Oca",
      "Şub",
      "Mar",
      "Nis",
      "May",
      "Haz",
      "Tem",
      "Ağu",
      "Eyl",
      "Eki",
      "Kas",
      "Ara",
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
          const Row(
            children: [
              Icon(Icons.auto_graph, color: Colors.indigo, size: 22),
              SizedBox(width: 8),
              Text(
                "Aylık Katılım Grafiği",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sortedKeys.length,
              itemBuilder: (context, index) {
                final month = sortedKeys[index];
                final att = monthlyStats[month]!["attended"]!;
                final mis = monthlyStats[month]!["missed"]!;
                final total = att + mis;
                double attHeight = total == 0
                    ? 0
                    : (att / total) * maxBarHeight;

                final monthNum = int.parse(month.split('-')[1]);
                final monthName = monthNames[monthNum - 1];

                return Container(
                  width: 70,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            width: 30,
                            height: maxBarHeight,
                            decoration: BoxDecoration(
                              color: Colors.red.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          Container(
                            width: 30,
                            height: attHeight,
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        monthName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "$att/$total",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.green.shade400, "Katıldı"),
              const SizedBox(width: 20),
              _buildLegendItem(Colors.red.shade200, "Katılmadı"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildAttendanceCard(Attendance yoklama, bool isPresent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isPresent ? Icons.check_circle : Icons.cancel,
            color: isPresent ? Colors.green : Colors.red,
            size: 28,
          ),
        ),
        title: Text(
          _formatDate(yoklama.attendance_date),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: yoklama.note.isNotEmpty
            ? Text(
                yoklama.note,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              )
            : Text(
                isPresent ? "Antrenmana katıldı" : "Antrenmana katılmadı",
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPresent ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isPresent ? "VAR" : "YOK",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
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
              Icons.calendar_today,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz yoklama kaydı bulunmuyor",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "${widget.cocuk.first_name} için henüz yoklama alınmamış",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
*/
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class VeliYoklamaSayfasi extends StatefulWidget {
  final Users cocuk;
  const VeliYoklamaSayfasi({super.key, required this.cocuk});

  @override
  State<VeliYoklamaSayfasi> createState() => _VeliYoklamaSayfasiState();
}

class _VeliYoklamaSayfasiState extends State<VeliYoklamaSayfasi> {
  late Future<List<Attendance>> _attendanceFuture;

  List<Attendance> tumYoklamalar = [];
  List<Attendance> filtrelenmisYoklamalar = [];

  String _selectedFilter = "Son 30 Gün";
  final List<String> _filterOptions = [
    "Haftalık",
    "Son 30 Gün",
    "Aylık",
    "Yıllık",
    "Tümü",
  ];

  @override
  void initState() {
    super.initState();
    _attendanceFuture = _yoklamalariGetir();
  }

  Future<List<Attendance>> _yoklamalariGetir() async {
    try {
      final allAttendances = await GoogleSheetService.getAttendances();
      final data = allAttendances
          .where((a) => a.student_id == widget.cocuk.app)
          .toList();

      data.sort((a, b) => b.attendance_date.compareTo(a.attendance_date));

      return data;
    } catch (e) {
      print("Yoklama hatası: $e");
      return [];
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedFilter) {
      case "Haftalık":
        startDate = now.subtract(const Duration(days: 7));
        break;
      case "Son 30 Gün":
        startDate = now.subtract(const Duration(days: 30));
        break;
      case "Aylık":
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case "Yıllık":
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(2000);
    }

    if (_selectedFilter == "Tümü") {
      filtrelenmisYoklamalar = tumYoklamalar;
    } else {
      filtrelenmisYoklamalar = tumYoklamalar.where((a) {
        final date = DateTime.parse(a.attendance_date);
        return date.isAfter(startDate);
      }).toList();
    }

    setState(() {});
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatShortDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Map<String, Map<String, int>> _getMonthlyStats() {
    Map<String, Map<String, int>> monthly = {};
    for (var att in filtrelenmisYoklamalar) {
      if (att.attendance_date.length >= 7) {
        String monthKey = att.attendance_date.substring(0, 7);
        if (!monthly.containsKey(monthKey)) {
          monthly[monthKey] = {"attended": 0, "missed": 0};
        }
        if (att.status == "TRUE") {
          monthly[monthKey]!["attended"] = monthly[monthKey]!["attended"]! + 1;
        } else {
          monthly[monthKey]!["missed"] = monthly[monthKey]!["missed"]! + 1;
        }
      }
    }
    return monthly;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${widget.cocuk.first_name} ${widget.cocuk.last_name}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text("Yoklama Durumu", style: TextStyle(fontSize: 12)),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
                _applyFilter();
              });
            },
            itemBuilder: (context) => _filterOptions.map((filter) {
              return PopupMenuItem(
                value: filter,
                child: Row(
                  children: [
                    Icon(
                      filter == _selectedFilter
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: filter == _selectedFilter
                          ? Colors.indigo
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(filter),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: FutureBuilder<List<Attendance>>(
        future: _attendanceFuture,
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
                        _attendanceFuture = _yoklamalariGetir();
                      });
                    },
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data ?? [];

          // Veriler geldikten sonra state'i güncelle
          if (data != tumYoklamalar) {
            tumYoklamalar = data;
            _applyFilter();
          }

          if (filtrelenmisYoklamalar.isEmpty) {
            return _buildEmptyState();
          }

          int attended = filtrelenmisYoklamalar
              .where((a) => a.status == "TRUE")
              .length;
          int missed = filtrelenmisYoklamalar.length - attended;
          double rate = filtrelenmisYoklamalar.isEmpty
              ? 0
              : (attended / filtrelenmisYoklamalar.length) * 100;
          Color rateColor = rate >= 80
              ? Colors.green
              : (rate >= 50 ? Colors.orange : Colors.red);

          return Column(
            children: [
              // Filtre bilgisi
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedFilter,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${filtrelenmisYoklamalar.length} kayıt",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Özet Kartı
              Container(
                margin: const EdgeInsets.all(16),
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
                          "Toplam",
                          "${filtrelenmisYoklamalar.length}",
                          Icons.calendar_today,
                          Colors.white,
                        ),
                        _buildStatItem(
                          "Katıldı",
                          "$attended",
                          Icons.check_circle,
                          Colors.green.shade300,
                        ),
                        _buildStatItem(
                          "Katılmadı",
                          "$missed",
                          Icons.cancel,
                          Colors.red.shade300,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  "Katılım Oranı",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "%${rate.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: rateColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: rate / 100,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Aylık Grafik
              _buildMonthlyChart(),
              const SizedBox(height: 16),
              // Liste Başlığı
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 20, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text(
                      "Yoklama Geçmişi",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Yoklama Listesi
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtrelenmisYoklamalar.length,
                  itemBuilder: (context, index) {
                    final yoklama = filtrelenmisYoklamalar[index];
                    final isPresent = yoklama.status == "TRUE";
                    return _buildAttendanceCard(yoklama, isPresent);
                  },
                ),
              ),
            ],
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
          CircularProgressIndicator(color: Colors.indigo),
          SizedBox(height: 16),
          Text("Yoklama verileri yükleniyor..."),
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
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildMonthlyChart() {
    final monthlyStats = _getMonthlyStats();
    if (monthlyStats.isEmpty) return const SizedBox.shrink();

    var sortedKeys = monthlyStats.keys.toList()..sort();
    double maxBarHeight = 100.0;

    final monthNames = [
      "Oca",
      "Şub",
      "Mar",
      "Nis",
      "May",
      "Haz",
      "Tem",
      "Ağu",
      "Eyl",
      "Eki",
      "Kas",
      "Ara",
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
          const Row(
            children: [
              Icon(Icons.auto_graph, color: Colors.indigo, size: 22),
              SizedBox(width: 8),
              Text(
                "Aylık Katılım Grafiği",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sortedKeys.length,
              itemBuilder: (context, index) {
                final month = sortedKeys[index];
                final att = monthlyStats[month]!["attended"]!;
                final mis = monthlyStats[month]!["missed"]!;
                final total = att + mis;
                double attHeight = total == 0
                    ? 0
                    : (att / total) * maxBarHeight;

                final monthNum = int.parse(month.split('-')[1]);
                final monthName = monthNames[monthNum - 1];

                return Container(
                  width: 70,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            width: 30,
                            height: maxBarHeight,
                            decoration: BoxDecoration(
                              color: Colors.red.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          Container(
                            width: 30,
                            height: attHeight,
                            decoration: BoxDecoration(
                              color: Colors.green.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        monthName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "$att/$total",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.green.shade400, "Katıldı"),
              const SizedBox(width: 20),
              _buildLegendItem(Colors.red.shade200, "Katılmadı"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildAttendanceCard(Attendance yoklama, bool isPresent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isPresent ? Icons.check_circle : Icons.cancel,
            color: isPresent ? Colors.green : Colors.red,
            size: 28,
          ),
        ),
        title: Text(
          _formatDate(yoklama.attendance_date),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: yoklama.note.isNotEmpty
            ? Text(
                yoklama.note,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              )
            : Text(
                isPresent ? "Antrenmana katıldı" : "Antrenmana katılmadı",
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPresent ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isPresent ? "VAR" : "YOK",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
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
              Icons.calendar_today,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz yoklama kaydı bulunmuyor",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "${widget.cocuk.first_name} için henüz yoklama alınmamış",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
