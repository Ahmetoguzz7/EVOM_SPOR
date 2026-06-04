import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';
import 'package:EVOM_SPOR/userInterfacepage/attendancedetail.dart';

class GrupListesiSayfasi extends StatelessWidget {
  final Coach coache;
  final Users user;

  const GrupListesiSayfasi({
    super.key,
    required this.coache,
    required this.user,
  });

  String _getGroupTime(String schedule) {
    if (schedule.contains(RegExp(r'\d{1,2}:\d{2}'))) {
      final match = RegExp(r'\d{1,2}:\d{2}').firstMatch(schedule);
      if (match != null) return match.group(0)!;
    }
    return schedule;
  }

  // 🔥 FUTURE - CACHE'Lİ OLARAK VERİLERİ ÇEK
  Future<List<Group>> get _groupsFuture async {
    final allGroups = await GoogleSheetService.getGroupsCached();
    return allGroups.where((g) => g.coach_id == coache.coach_id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Gruplarım",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 🔄 YENİLEME BUTONU
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Cache'i temizle ve sayfayı yenile
              GoogleSheetService.invalidateCache('groups');
              (context as Element).reassemble();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Group>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          // 1️⃣ YÜKLENİYOR DURUMU
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text("Gruplar yükleniyor..."),
                ],
              ),
            );
          }

          // 2️⃣ HATA DURUMU
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text("Bir hata oluştu"),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString()),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      GoogleSheetService.invalidateCache('groups');
                      (context as Element).reassemble();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Tekrar Dene"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          // 3️⃣ VERİ GELDİ - LİSTEYİ GÖSTER
          final gruplar = snapshot.data ?? [];

          if (gruplar.isEmpty) {
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
                      Icons.group_off,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Henüz size atanmış bir grup bulunamadı",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Yöneticiniz sizi bir gruba atayınca burada görünecektir",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              GoogleSheetService.invalidateCache('groups');
              (context as Element).reassemble();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: gruplar.length,
              itemBuilder: (context, index) {
                final grup = gruplar[index];
                return _buildGroupCard(context, grup);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, Group grup) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    YoklamaSayfasi(selectedGroup: grup, currentUser: user),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Grup ikonu
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.indigo, Colors.indigoAccent],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.group, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                // Bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        grup.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getGroupTime(grup.schedule),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.payments,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Ok butonu
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.indigo,
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
