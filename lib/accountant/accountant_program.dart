import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';

class WeeklyTrainingScreen extends StatefulWidget {
  final List<Group> groups;
  final List<GroupStudent> relations;
  final List<Users> students;

  const WeeklyTrainingScreen({
    Key? key,
    required this.groups,
    required this.relations,
    required this.students,
  }) : super(key: key);

  @override
  State<WeeklyTrainingScreen> createState() => _WeeklyTrainingScreenState();
}

class _WeeklyTrainingScreenState extends State<WeeklyTrainingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _weeklySchedule = [];
  List<Users> _todaysStudents = [];
  String _selectedDay = "";
  Map<String, List<Map<String, dynamic>>> _groupedSchedule = {};

  // Günler (Türkçe sıralı)
  final List<String> _days = [
    "Pazartesi",
    "Salı",
    "Çarşamba",
    "Perşembe",
    "Cuma",
    "Cumartesi",
    "Pazar",
  ];

  // Renkler
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _surfaceLight = Color(0xFFF1F5F9);
  static const Color _accent = Color(0xFF0EA5E9);
  static const Color _accentDark = Color(0xFF0284C7);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF22C55E);
  static const Color _warning = Color(0xFFF97316);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _purple = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSchedule();
    _selectedDay = _getTodayName();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🔥 GELİŞMİŞ SCHEDULE PARSE
  List<Map<String, dynamic>> _parseSchedule(String scheduleStr) {
    final List<Map<String, dynamic>> result = [];
    if (scheduleStr.isEmpty) return result;

    final parts = scheduleStr.split(',');
    if (parts.length != 2) return result;

    final daysPart = parts[0].trim().toLowerCase();
    final timePart = parts[1].trim();

    final dayNames = daysPart.split('-');

    final Map<String, String> dayMap = {
      'pazartesi': 'Pazartesi',
      'sali': 'Salı',
      'çarşamba': 'Çarşamba',
      'carsamba': 'Çarşamba',
      'perşembe': 'Perşembe',
      'persembe': 'Perşembe',
      'cuma': 'Cuma',
      'cumartesi': 'Cumartesi',
      'pazar': 'Pazar',
    };

    for (var day in dayNames) {
      final formattedDay = dayMap[day] ?? day;
      result.add({'day': formattedDay, 'time': timePart});
    }

    return result;
  }

  void _loadSchedule() {
    _weeklySchedule = [];
    _todaysStudents = [];

    final todayName = _getTodayName();

    for (var group in widget.groups) {
      if (group.schedule.isEmpty) continue;

      final schedules = _parseSchedule(group.schedule);

      for (var schedule in schedules) {
        final day = schedule['day'];
        final time = schedule['time'];

        _weeklySchedule.add({
          'day': day,
          'dayIndex': _days.indexOf(day),
          'time': time,
          'groupName': group.name,
          'groupId': group.groups_id,
        });

        if (day == todayName) {
          final students = _getStudentsInGroup(group.groups_id);
          _todaysStudents.addAll(students);
        }
      }
    }

    _weeklySchedule.sort((a, b) => a['dayIndex'].compareTo(b['dayIndex']));

    // Günlere göre grupla
    _groupedSchedule = {};
    for (var item in _weeklySchedule) {
      final day = item['day'];
      if (!_groupedSchedule.containsKey(day)) {
        _groupedSchedule[day] = [];
      }
      _groupedSchedule[day]!.add(item);
    }

    _todaysStudents = _todaysStudents.toSet().toList();
  }

  List<Users> _getStudentsInGroup(String groupId) {
    final studentIds = widget.relations
        .where((r) => r.groups_id == groupId && r.is_active == "TRUE")
        .map((r) => r.student_id)
        .toList();

    return widget.students.where((s) => studentIds.contains(s.app)).toList();
  }

  String _getTodayName() {
    final now = DateTime.now();
    return _days[now.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Text(
          "Antrenman Programı",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: _textPrimary,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildDaySelector(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildWeeklyScheduleTab(), _buildTodayStudentsTab()],
      ),
    );
  }

  // 🔥 GÜN SEÇİCİ (Yatay scroll)
  Widget _buildDaySelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
          final isToday = day == _getTodayName();
          final hasTraining = _groupedSchedule.containsKey(day);
          final isSelected = _selectedDay == day;

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _accent : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? Colors.transparent : _border,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isToday ? _accent : _textSecondary),
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  if (hasTraining && !isSelected)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyScheduleTab() {
    if (_weeklySchedule.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 64, color: _textTertiary),
            const SizedBox(height: 16),
            Text(
              "Henüz program eklenmemiş",
              style: TextStyle(color: _textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Excel'de schedule sütununa program ekleyin",
              style: TextStyle(color: _textTertiary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final selectedDayItems = _groupedSchedule[_selectedDay] ?? [];
    final isToday = _selectedDay == _getTodayName();

    return Column(
      children: [
        // Seçili gün başlığı
        Container(
          padding: const EdgeInsets.all(16),
          color: _surface,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isToday
                      ? _accent.withOpacity(0.1)
                      : _purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isToday ? Icons.today : Icons.calendar_today,
                  color: isToday ? _accent : _purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedDay,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isToday ? _accent : _textPrimary,
                      ),
                    ),
                    Text(
                      "${selectedDayItems.length} antrenman",
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Bugün",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Antrenman listesi
        Expanded(
          child: selectedDayItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sports, size: 48, color: _textTertiary),
                      const SizedBox(height: 12),
                      Text(
                        "Bu günde antrenman yok",
                        style: TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: selectedDayItems.length,
                  itemBuilder: (context, index) {
                    final item = selectedDayItems[index];
                    final groupId = item['groupId'];
                    final studentCount = _getStudentsInGroup(groupId).length;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showGroupDetail(
                            groupId,
                            item['groupName'],
                            item['time'],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_accent, _accentDark],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.sports,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['groupName'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: _textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            item['time'],
                                            style: TextStyle(
                                              color: _accent,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(
                                            Icons.people,
                                            size: 14,
                                            color: _textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "$studentCount öğrenci",
                                            style: TextStyle(
                                              color: _textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _accent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.chevron_right,
                                    color: _accent,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showGroupDetail(String groupId, String groupName, String time) {
    final students = _getStudentsInGroup(groupId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, sc) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_accent, _accentDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.sports,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Saat: $time",
                            style: TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: _textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: _border, height: 1),
              Expanded(
                child: students.isEmpty
                    ? const Center(
                        child: Text(
                          "Bu grupta öğrenci yok",
                          style: TextStyle(color: _textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: sc,
                        padding: const EdgeInsets.all(16),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: _surfaceLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    student.first_name.isNotEmpty
                                        ? student.first_name[0].toUpperCase()
                                        : "?",
                                    style: TextStyle(
                                      color: _accent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                "${student.first_name} ${student.last_name}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                student.email,
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayStudentsTab() {
    if (_todaysStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports, size: 64, color: _textTertiary),
            const SizedBox(height: 16),
            Text(
              "Bugün antrenmanı olan öğrenci yok",
              style: TextStyle(color: _textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _todaysStudents.length,
      itemBuilder: (context, index) {
        final student = _todaysStudents[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  student.first_name.isNotEmpty
                      ? student.first_name[0].toUpperCase()
                      : "?",
                  style: TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
            title: Text(
              "${student.first_name} ${student.last_name}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              student.email,
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Bugün",
                style: TextStyle(
                  color: _accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
