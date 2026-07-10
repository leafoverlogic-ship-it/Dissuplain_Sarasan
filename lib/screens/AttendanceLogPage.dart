import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../CommonFooter.dart';
import '../CommonHeader.dart';
import '../utils/browser_download.dart';

class AttendanceLogPage extends StatefulWidget {
  const AttendanceLogPage({super.key});

  @override
  State<AttendanceLogPage> createState() => _AttendanceLogPageState();
}

class _AttendanceLogPageState extends State<AttendanceLogPage> {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  StreamSubscription<DatabaseEvent>? _usersSub;
  StreamSubscription<DatabaseEvent>? _logsSub;

  List<_AttendanceUser> _users = const [];
  Map<String, Set<String>> _presentDateKeysByUser = const {};
  bool _isExporting = false;
  bool _isFullScreen = false;

  static final DateTime _featureStart = DateTime(2026, 7, 9);

  @override
  void initState() {
    super.initState();
    _listenUsers();
    _listenActivityLogs();
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _logsSub?.cancel();
    super.dispose();
  }

  void _listenUsers() {
    _usersSub = _db.ref('Users').onValue.listen((event) {
      final users = <_AttendanceUser>[];
      final raw = event.snapshot.value;

      void add(Map<dynamic, dynamic> m) {
        final id = _s(
          m['SalesPersonID'] ?? m['salesPersonID'] ?? m['salesPersonId'],
        );
        if (id.isEmpty) return;
        final name = _s(
          m['SalesPersonName'] ?? m['salesPersonName'] ?? m['name'],
        );
        final role = _s(
          m['salesPersonRoleID'] ??
              m['salesPersonRoleId'] ??
              m['SalesPersonRoleID'],
        );
        final createdAt = _toDate(m['createdAt']);

        final disabled = _toDisabled(m['disabled']);
        if (disabled) return;

        users.add(
          _AttendanceUser(
            salesPersonId: id,
            salesPersonName: name.isEmpty ? id : name,
            roleId: role,
            createdAt: createdAt,
          ),
        );
      }

      if (raw is Map) {
        raw.forEach((_, v) {
          if (v is Map) add(v);
        });
      } else if (raw is List) {
        for (final v in raw) {
          if (v is Map) add(v);
        }
      }

      users.sort(
        (a, b) => a.salesPersonName.toLowerCase().compareTo(
          b.salesPersonName.toLowerCase(),
        ),
      );

      if (!mounted) return;
      setState(() => _users = users);
    });
  }

  void _listenActivityLogs() {
    _logsSub = _db.ref('ActivityLogs').onValue.listen((event) {
      final presentByUser = <String, Set<String>>{};
      final raw = event.snapshot.value;

      void addLog(Map<dynamic, dynamic> m) {
        final userId = _s(
          m['userId'] ?? m['SalesPersonID'] ?? m['salesPersonId'],
        );
        if (userId.isEmpty) return;

        final type = _s(m['type']).toLowerCase();
        final isAttendanceCall =
            type == 'new call' ||
            type == 'follow up call' ||
            type == 'followup call';
        if (!isAttendanceCall) return;

        final date = _toDate(m['dateTimeMillis']) ?? _toDate(m['createdAt']);
        if (date == null) return;

        final day = DateTime(date.year, date.month, date.day);
        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        if (day.isAfter(todayOnly)) return;
        if (day.isBefore(_featureStart)) return;

        final key = _dateKey(day);
        (presentByUser[userId] ??= <String>{}).add(key);
      }

      if (raw is Map) {
        raw.forEach((_, v) {
          if (v is Map) addLog(v);
        });
      } else if (raw is List) {
        for (final v in raw) {
          if (v is Map) addLog(v);
        }
      }

      if (!mounted) return;
      setState(() => _presentDateKeysByUser = presentByUser);
    });
  }

  DateTime _effectiveStartDate(_AttendanceUser user) {
    final userStart = user.createdAt;
    if (userStart == null) return _featureStart;
    final normalized = DateTime(userStart.year, userStart.month, userStart.day);
    return normalized.isAfter(_featureStart) ? normalized : _featureStart;
  }

  Future<void> _downloadThisMonthAttendance() async {
    if (_isExporting) return;

    if (_users.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active users available for export.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final now = DateTime.now();
      final monthDate = DateTime(now.year, now.month, 1);
      final html = _buildMonthlyAttendanceExcelHtml(monthDate);
      final fileName =
          'Attendance_${monthDate.year}_${monthDate.month.toString().padLeft(2, '0')}.xls';

      final ok = await downloadTextFile(
        fileName: fileName,
        content: html,
        mimeType: 'application/vnd.ms-excel;charset=utf-8',
      );

      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance Excel downloaded.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'Download could not be started.'
                  : 'This download is available on web builds.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _buildMonthlyAttendanceExcelHtml(DateTime monthDate) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final totalDays = DateTime(monthDate.year, monthDate.month + 1, 0).day;

    final buf = StringBuffer();
    buf.write('<html><head><meta charset="UTF-8">');
    buf.write('<style>');
    buf.write(
      'body{font-family:Calibri,Arial,sans-serif;padding:16px;color:#1d1d1f;}',
    );
    buf.write('h2{margin:0 0 4px 0;}');
    buf.write('p{margin:0 0 14px 0;color:#4f5965;}');
    buf.write(
      'table{border-collapse:collapse;width:100%;margin:0 0 18px 0;table-layout:fixed;}',
    );
    buf.write(
      'th,td{border:1px solid #cfd8dc;text-align:center;padding:6px;font-size:12px;}',
    );
    buf.write(
      '.userHead{background:#ecf2ff;text-align:left;font-weight:700;font-size:14px;padding:8px;}',
    );
    buf.write('.wk{background:#f4f7fb;font-weight:700;}');
    buf.write('.present{background:#128a3e;color:#ffffff;font-weight:700;}');
    buf.write('.absent{background:#d32f2f;color:#ffffff;font-weight:700;}');
    buf.write('.inactive{background:#eceff1;color:#7a8691;}');
    buf.write('.empty{background:#ffffff;}');
    buf.write(
      '.totalRow td{text-align:left;font-weight:700;background:#f8fafc;}',
    );
    buf.write('</style></head><body>');
    buf.write(
      '<h2>Attendance Log - ${_htmlEscape(_monthTitle(monthDate))}</h2>',
    );
    buf.write(
      '<p>Present days are marked in green and absent days in red. Totals are shown out of $totalDays days.</p>',
    );

    for (final user in _users) {
      final presentKeys =
          _presentDateKeysByUser[user.salesPersonId] ?? const <String>{};
      final startDate = _effectiveStartDate(user);
      final monthGrid = _buildMonthGrid(monthDate);

      int present = 0;

      buf.write('<table>');
      buf.write(
        '<tr><th class="userHead" colspan="7">${_htmlEscape(user.salesPersonName)} (${_htmlEscape(user.salesPersonId)})</th></tr>',
      );
      buf.write('<tr>');
      for (final w in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
        buf.write('<th class="wk">$w</th>');
      }
      buf.write('</tr>');

      for (final week in monthGrid) {
        buf.write('<tr>');
        for (final day in week) {
          if (day == null) {
            buf.write('<td class="empty"></td>');
            continue;
          }

          final date = DateTime(monthDate.year, monthDate.month, day);
          final isFuture = date.isAfter(todayDate);
          final notActiveYet = date.isBefore(startDate);
          final isActiveDay = !isFuture && !notActiveYet;
          final isPresent = isActiveDay && presentKeys.contains(_dateKey(date));

          String cls;
          if (!isActiveDay) {
            cls = 'inactive';
          } else if (isPresent) {
            cls = 'present';
            present++;
          } else {
            cls = 'absent';
          }

          buf.write('<td class="$cls">$day</td>');
        }
        buf.write('</tr>');
      }

      final absent = totalDays - present;
      buf.write(
        '<tr class="totalRow"><td colspan="7">Present Days: $present / $totalDays | Absent Days: $absent / $totalDays</td></tr>',
      );
      buf.write('</table>');
    }

    buf.write('</body></html>');
    return buf.toString();
  }

  List<List<int?>> _buildMonthGrid(DateTime monthDate) {
    final first = DateTime(monthDate.year, monthDate.month, 1);
    final totalDays = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday-based

    final cells = <int?>[];
    for (int i = 0; i < leading; i++) {
      cells.add(null);
    }
    for (int d = 1; d <= totalDays; d++) {
      cells.add(d);
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final weeks = <List<int?>>[];
    for (int i = 0; i < cells.length; i += 7) {
      weeks.add(cells.sublist(i, i + 7));
    }
    return weeks;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listBottomPadding = _isFullScreen ? 92.0 : 14.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: _isFullScreen ? null : CommonFooter(),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isFullScreen)
                  const CommonHeader(pageTitle: 'Attendance Log'),
                if (!_isFullScreen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Attendance Rule',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              _FullScreenToggleButton(
                                fullScreen: _isFullScreen,
                                onTap: () => setState(
                                  () => _isFullScreen = !_isFullScreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Present = made at least one New Call or Follow Up Call on that day. Absent = no calls on active days.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: const [
                              _LegendChip(
                                label: 'Present',
                                color: Color(0xFF2E7D32),
                              ),
                              _LegendChip(
                                label: 'Absent',
                                color: Color(0xFFC62828),
                              ),
                              _LegendChip(
                                label: 'Not active / before start',
                                color: Color(0xFF9E9E9E),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _DownloadAttendanceButton(
                            loading: _isExporting,
                            onTap: _downloadThisMonthAttendance,
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: _users.isEmpty
                      ? const Center(child: Text('No active users found.'))
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            _isFullScreen ? 8 : 12,
                            _isFullScreen ? 8 : 4,
                            _isFullScreen ? 8 : 12,
                            listBottomPadding,
                          ),
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return _UserAttendanceCard(
                              user: user,
                              presentDateKeys:
                                  _presentDateKeysByUser[user.salesPersonId] ??
                                  const <String>{},
                              startDate: _effectiveStartDate(user),
                            );
                          },
                        ),
                ),
              ],
            ),
            if (_isFullScreen)
              Positioned(
                top: 10,
                right: 10,
                child: _FullScreenToggleButton(
                  fullScreen: _isFullScreen,
                  onTap: () => setState(() => _isFullScreen = !_isFullScreen),
                ),
              ),
            if (_isFullScreen)
              Positioned(
                bottom: 14,
                right: 14,
                child: _DownloadAttendanceButton(
                  loading: _isExporting,
                  onTap: _downloadThisMonthAttendance,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserAttendanceCard extends StatefulWidget {
  final _AttendanceUser user;
  final Set<String> presentDateKeys;
  final DateTime startDate;

  const _UserAttendanceCard({
    required this.user,
    required this.presentDateKeys,
    required this.startDate,
  });

  @override
  State<_UserAttendanceCard> createState() => _UserAttendanceCardState();
}

class _UserAttendanceCardState extends State<_UserAttendanceCard> {
  int _monthOffset =
      0; // 0=current month, -1 previous, ... -11 oldest in window

  ({int present, int absent}) _monthStats(
    DateTime monthDate,
    DateTime todayDate,
  ) {
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    int present = 0;
    int absent = 0;
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(monthDate.year, monthDate.month, day);
      final isFuture = date.isAfter(todayDate);
      final notActiveYet = date.isBefore(widget.startDate);
      if (isFuture || notActiveYet) continue;
      if (widget.presentDateKeys.contains(_dateKey(date))) {
        present++;
      } else {
        absent++;
      }
    }
    return (present: present, absent: absent);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final monthDate = DateTime(
      todayDate.year,
      todayDate.month + _monthOffset,
      1,
    );
    final stats = _monthStats(monthDate, todayDate);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.user.salesPersonName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.user.salesPersonId} | Role ${widget.user.roleId.isEmpty ? '—' : widget.user.roleId}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.85),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _MiniMonthArrow(
                          icon: Icons.chevron_left,
                          enabled: _monthOffset > -11,
                          onTap: () => setState(() => _monthOffset--),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              _monthTitle(monthDate),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        _MiniMonthArrow(
                          icon: Icons.chevron_right,
                          enabled: _monthOffset < 0,
                          onTap: () => setState(() => _monthOffset++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LegendChip(
                          label: 'P ${stats.present}',
                          color: const Color(0xFF128A3E),
                        ),
                        const SizedBox(width: 8),
                        _LegendChip(
                          label: 'A ${stats.absent}',
                          color: const Color(0xFFD32F2F),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _MonthCalendar(
                      monthDate: monthDate,
                      presentDateKeys: widget.presentDateKeys,
                      startDate: widget.startDate,
                      todayDate: todayDate,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  final DateTime monthDate;
  final Set<String> presentDateKeys;
  final DateTime startDate;
  final DateTime todayDate;

  const _MonthCalendar({
    required this.monthDate,
    required this.presentDateKeys,
    required this.startDate,
    required this.todayDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(monthDate.year, monthDate.month, 1);
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday-based grid

    final cells = <Widget>[];

    for (int i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(monthDate.year, monthDate.month, day);
      final dateKey = _dateKey(date);

      final isFuture = date.isAfter(todayDate);
      final notActiveYet = date.isBefore(startDate);
      final isActiveDay = !isFuture && !notActiveYet;
      final isPresent = isActiveDay && presentDateKeys.contains(dateKey);
      final isAbsent = isActiveDay && !isPresent;

      Color bg;
      Color fg;
      if (!isActiveDay) {
        bg = theme.colorScheme.surfaceContainerHighest.withOpacity(0.20);
        fg = theme.colorScheme.onSurfaceVariant.withOpacity(0.7);
      } else if (isPresent) {
        bg = const Color(0xFF128A3E);
        fg = Colors.white;
      } else if (isAbsent) {
        bg = const Color(0xFFD32F2F);
        fg = Colors.white;
      } else {
        bg = theme.colorScheme.surfaceContainerHighest;
        fg = theme.colorScheme.onSurface;
      }

      final isToday =
          date.year == todayDate.year &&
          date.month == todayDate.month &&
          date.day == todayDate.day;

      cells.add(
        Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                    width: 1.3,
                  )
                : null,
          ),
          child: Text(
            '$day',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: fg,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        GridView.count(
          crossAxisCount: 7,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.7,
          children: const [
            _WeekdayHeader('M'),
            _WeekdayHeader('T'),
            _WeekdayHeader('W'),
            _WeekdayHeader('T'),
            _WeekdayHeader('F'),
            _WeekdayHeader('S'),
            _WeekdayHeader('S'),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.0,
          children: cells,
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String label;

  const _WeekdayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _MiniMonthArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _MiniMonthArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.55)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant.withOpacity(0.45),
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DownloadAttendanceButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;

  const _DownloadAttendanceButton({required this.loading, required this.onTap});

  @override
  State<_DownloadAttendanceButton> createState() =>
      _DownloadAttendanceButtonState();
}

class _FullScreenToggleButton extends StatelessWidget {
  final bool fullScreen;
  final VoidCallback onTap;

  const _FullScreenToggleButton({
    required this.fullScreen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = fullScreen ? 'Minimize' : 'Full Screen';
    final icon = fullScreen
        ? Icons.fullscreen_exit_rounded
        : Icons.fullscreen_rounded;

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}

class _DownloadAttendanceButtonState extends State<_DownloadAttendanceButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = const Color(0xFF0F766E);
    final hi = const Color(0xFF14B8A6);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _hovered ? [hi, base] : [base, const Color(0xFF0B5F59)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: base.withOpacity(_hovered ? 0.38 : 0.22),
              blurRadius: _hovered ? 14 : 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.loading ? null : widget.onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                  const SizedBox(width: 10),
                  Text(
                    widget.loading
                        ? 'Preparing Attendance Excel...'
                        : "Download This Month's Attendance",
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
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

class _AttendanceUser {
  final String salesPersonId;
  final String salesPersonName;
  final String roleId;
  final DateTime? createdAt;

  const _AttendanceUser({
    required this.salesPersonId,
    required this.salesPersonName,
    required this.roleId,
    required this.createdAt,
  });
}

String _s(dynamic v) => v?.toString().trim() ?? '';

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  final n = int.tryParse(v.toString());
  if (n != null && n > 0) return DateTime.fromMillisecondsSinceEpoch(n);
  return null;
}

bool _toDisabled(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final value = _s(raw).toLowerCase();
  return value == 'true' ||
      value == '1' ||
      value == 'yes' ||
      value == 'disabled';
}

String _dateKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String _monthTitle(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[d.month - 1]} ${d.year}';
}

String _htmlEscape(String? s) {
  final v = (s ?? '');
  return v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
