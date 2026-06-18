import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class PtWeeklyProgram extends StatelessWidget {
  final Users user;
  final Coach coach;

  const PtWeeklyProgram({super.key, required this.user, required this.coach});

  List<Map<String, dynamic>> _parseSchedule(String schedule) {
    final List<Map<String, dynamic>> result = [];
    final dayMap = {
      'pazartesi': 1,
      'salı': 2,
      'çarşamba': 3,
      'perşembe': 4,
      'cuma': 5,
      'cumartesi': 6,
      'pazar': 7,
    };

    if (schedule.isEmpty) return result;
    schedule = schedule.trim();

    final format1Regex = RegExp(
      r'(\w+)\s*:\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})',
      caseSensitive: false,
    );

    final format1Matches = format1Regex.allMatches(schedule);
    if (format1Matches.isNotEmpty) {
      for (final match in format1Matches) {
        final day = match.group(1)!.toLowerCase().trim();
        final start = match.group(2)!.trim();
        final end = match.group(3)!.trim();
        if (dayMap.containsKey(day)) {
          result.add({'day': dayMap[day], 'start': start, 'end': end});
        }
      }
      return result;
    }

    if (schedule.contains(',')) {
      final parts = schedule.split(',');
      if (parts.length >= 2) {
        final daysPart = parts[0].trim();
        final timePart = parts.sublist(1).join(',').trim();

        final timeMatch = RegExp(
          r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})',
        ).firstMatch(timePart);

        if (timeMatch != null) {
          final start = timeMatch.group(1)!;
          final end = timeMatch.group(2)!;

          final days = daysPart
              .split('-')
              .map((d) => d.trim().toLowerCase())
              .where((d) => dayMap.containsKey(d))
              .toList();

          for (final day in days) {
            result.add({'day': dayMap[day]!, 'start': start, 'end': end});
          }
        }
      }
    }

    return result;
  }

  String _getWeekRange() {
    final now = DateTime.now();
    final daysToSubtract = now.weekday - 1;
    final monday = now.subtract(Duration(days: daysToSubtract));
    final sunday = monday.add(const Duration(days: 6));
    final formatter = DateFormat('d MMMM yyyy', 'tr_TR');
    return "${formatter.format(monday)} - ${formatter.format(sunday)}";
  }

  String _getTodayName() {
    const days = [
      "Pazartesi",
      "Salı",
      "Çarşamba",
      "Perşembe",
      "Cuma",
      "Cumartesi",
      "Pazar",
    ];
    final now = DateTime.now();
    return days[now.weekday - 1];
  }

  Future<Map<String, dynamic>> _getWeeklyProgram() async {
    try {
      final allGroups = await GoogleSheetService.getGroupsCached();

      // 🔥 Antrenörün tüm gruplarını al
      final myGroups = allGroups
          .where((g) => g.coach_id == coach.coach_id)
          .toList();

      if (myGroups.isEmpty) {
        return {'hasGroup': false};
      }

      const days = [
        "Pazartesi",
        "Salı",
        "Çarşamba",
        "Perşembe",
        "Cuma",
        "Cumartesi",
        "Pazar",
      ];

      // 🔥 Tüm grupların programlarını birleştir
      final Map<String, List<Map<String, dynamic>>> groupedSchedule = {};

      for (var group in myGroups) {
        if (group.schedule.isNotEmpty) {
          final schedules = _parseSchedule(group.schedule);

          for (var schedule in schedules) {
            final dayInt = schedule['day'] as int;
            final dayIndex = dayInt - 1;
            final dayName = days[dayIndex];

            final training = {
              'time': '${schedule['start']} - ${schedule['end']}',
              'groupName': group.name,
              'groupId': group.groups_id,
            };

            if (!groupedSchedule.containsKey(dayName)) {
              groupedSchedule[dayName] = [];
            }
            groupedSchedule[dayName]!.add(training);
          }
        }
      }

      // Saate göre sırala
      for (var day in groupedSchedule.keys) {
        groupedSchedule[day]!.sort((a, b) {
          return a['time'].compareTo(b['time']);
        });
      }

      return {
        'hasGroup': true,
        'groups': myGroups,
        'groupedSchedule': groupedSchedule,
      };
    } catch (e) {
      return {'hasGroup': false, 'error': e.toString()};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Haftalık Antrenman Programı",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              GoogleSheetService.invalidateCache('groups');
              GoogleSheetService.invalidateCache('group_students');
              (context as Element).reassemble();
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getWeeklyProgram(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text("Antrenman programı yükleniyor..."),
                ],
              ),
            );
          }

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
                      GoogleSheetService.invalidateCache('group_students');
                      (context as Element).reassemble();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;

          if (data.containsKey('error')) {
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
                  Text(data['error']),
                ],
              ),
            );
          }

          final hasGroup = data['hasGroup'] as bool;

          if (!hasGroup) {
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
                    "Size ait bir grup bulunamadı",
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

          final groups = data['groups'] as List<Group>;
          final groupedSchedule =
              data['groupedSchedule']
                  as Map<String, List<Map<String, dynamic>>>;

          // Program kontrolü
          bool hasAnyTraining = false;
          for (var trainings in groupedSchedule.values) {
            if (trainings.isNotEmpty) {
              hasAnyTraining = true;
              break;
            }
          }

          if (!hasAnyTraining) {
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
                      Icons.sports,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Antrenman programı henüz eklenmemiş",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Gruplarınız için bir program oluşturulduğunda burada görünecektir",
                    style: TextStyle(color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              GoogleSheetService.invalidateCache('groups');
              GoogleSheetService.invalidateCache('group_students');
              (context as Element).reassemble();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(groups),
                  const SizedBox(height: 20),
                  const Text(
                    "Haftalık Program",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(7, (index) {
                    const days = [
                      "Pazartesi",
                      "Salı",
                      "Çarşamba",
                      "Perşembe",
                      "Cuma",
                      "Cumartesi",
                      "Pazar",
                    ];
                    final dayName = days[index];
                    final trainings = groupedSchedule[dayName] ?? [];
                    final isToday = dayName == _getTodayName();
                    return _buildDayCard(dayName, trainings, isToday);
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 🔥 YENİ: Birden fazla grubu gösteren header
  Widget _buildHeaderCard(List<Group> groups) {
    final groupCount = groups.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.orangeAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupCount > 1
                          ? "$groupCount Grubunuz Var"
                          : "1 Grubunuz Var",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getWeekRange(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 🔥 YENİ: Grupların listesi
          if (groupCount > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: groups.map((group) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    group.name,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayCard(
    String dayName,
    List<Map<String, dynamic>> trainings,
    bool isToday,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday ? Colors.orange : Colors.grey.shade200,
          width: isToday ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isToday
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isToday ? Icons.today : Icons.calendar_today,
                  size: 18,
                  color: isToday ? Colors.orange : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  dayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.orange : Colors.grey.shade800,
                  ),
                ),
                if (isToday)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Bugün",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                if (trainings.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${trainings.length} antrenman",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trainings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: trainings.asMap().entries.map((entry) {
                  final index = entry.key;
                  final training = entry.value;
                  final isFirst = index == 0;

                  return Column(
                    children: [
                      if (!isFirst) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          height: 1,
                          color: Colors.grey.shade200,
                        ),
                      ],
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.sports,
                                  color: Colors.orange,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    training['groupName'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        training['time'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w500,
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
                    ],
                  );
                }).toList(),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  "Bu günde antrenman yok",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
