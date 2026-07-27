// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use
import 'package:intl/intl.dart';

class PerformanceCalculator {
  /// Calculates date boundaries for various report periods.
  static Map<String, DateTime> getPeriodBoundaries(String period, int weekStartDay) {
    DateTime now = DateTime.now();
    DateTime todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    DateTime start;

    switch (period) {
      case 'weekly':
        // آخری 7 دن
        start = now.subtract(const Duration(days: 6));
        break;
      case 'monthly':
        // آخری 30 دن
        start = now.subtract(const Duration(days: 29));
        break;
      case 'quarterly':
        // آخری 90 دن
        start = now.subtract(const Duration(days: 89));
        break;
      case 'semi_annually':
        // آخری 180 دن
        start = now.subtract(const Duration(days: 179));
        break;
      case 'annually':
        // پچھلے سال کی آج کی تاریخ سے آج تک (آخری 365 دن)
        start = now.subtract(const Duration(days: 364));
        break;
      case 'current_week':
      default:
        // رواں ہفتہ (ویک سٹارٹ ڈے سے آج تک)
        int currentDay = now.weekday % 7;
        int daysSinceStart = (currentDay - weekStartDay) % 7;
        if (daysSinceStart < 0) daysSinceStart += 7;
        start = now.subtract(Duration(days: daysSinceStart));
        break;
    }

    return {
      'start': DateTime(start.year, start.month, start.day),
      'end': todayEnd,
    };
  }

  /// Calculates the boundaries of the "current week" based on the [weekStartDay].
  /// 0 = Sunday, 6 = Saturday.
  static Map<String, DateTime> getWeekBoundaries(int weekStartDay) {
    return getPeriodBoundaries('current_week', weekStartDay);
  }

  static double getGradePoints(String? grade, double maxPoints) {
    if (grade == null) return 0;
    String g = grade.trim().toLowerCase();

    if (g == 'بہترین') return maxPoints;
    if (g == 'بہتر') return maxPoints * 0.8;
    if (g == 'رعایتی پاس') return maxPoints * 0.6;
    if (g == 'کچا') return maxPoints * 0.4;

    // ممتاز، بہترین، اعلیٰ، بہت اچھے (Excellent)
    if (g == 'excellent' ||
        g == 'ممتاز' ||
        g == 'بہترین' ||
        g == 'اعلیٰ' ||
        g == 'بہت اچھے') {
      return maxPoints;
    }
    // بہتر، اچھا، ٹھیک (Good)
    if (g == 'good' || g == 'بہتر' || g == 'اچھا' || g == 'ٹھیک') {
      return maxPoints * 0.8;
    }
    // معمولی، مناسب، درمیانہ (Average)
    if (g == 'average' || g == 'معمولی' || g == 'مناسب' || g == 'درمیانہ') {
      return maxPoints * 0.6;
    }
    // کمزور، توجہ طلب، بہت کمزور (Weak)
    if (g == 'weak' || g == 'کمزور' || g == 'توجہ طلب' || g == 'بہت کمزور') {
      return maxPoints * 0.4;
    }

    return 0;
  }

  static DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateFormat('d/M/yyyy').parse(dateStr);
    } catch (_) {
      try {
        return DateTime.parse(dateStr);
      } catch (_) {
        return null;
      }
    }
  }

  static Map<String, dynamic> calculateWeeklyPerformance({
    required List<Map<String, dynamic>> hifzRecords,
    List<Map<String, dynamic>>? qaidaRecords,
    required List<Map<String, dynamic>> attendanceRecords,
    required int weekStartDay,
  }) {
    var boundaries = getWeekBoundaries(weekStartDay);
    DateTime start = boundaries['start']!;
    DateTime end = boundaries['end']!;

    // Filter records for this week
    var weeklyHifz = hifzRecords.where((r) {
      DateTime? d = _parseDate(r['date']);
      return d != null &&
          d.isAfter(start.subtract(const Duration(seconds: 1))) &&
          d.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    var weeklyAttendance = attendanceRecords.where((r) {
      DateTime? d = _parseDate(r['date']);
      return d != null &&
          d.isAfter(start.subtract(const Duration(seconds: 1))) &&
          d.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    // 1. Attendance Calculation
    int present = 0;
    int lateCount = 0;
    int totalDaysMeasured = weeklyAttendance.length;
    for (var a in weeklyAttendance) {
      if (a['status'] == 'Present' || a['status'] == 'P') {
        present++;
        int delay = int.tryParse(a['delay_minutes']?.toString() ?? '0') ?? 0;
        if (delay > 0) lateCount++;
      }
    }
    double attendancePerc =
        totalDaysMeasured > 0 ? (present / totalDaysMeasured) * 100 : 0;

    var weeklyQaida = (qaidaRecords ?? []).where((r) {
      DateTime? d = _parseDate(r['date']);
      return d != null &&
          d.isAfter(start.subtract(const Duration(seconds: 1))) &&
          d.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    // 2. Academic Calculation
    // Logic: Avg(Sabaq Points) + Avg(Sabqi Points) + Avg(Manzil Points)
    double totalSabaq = 0;
    double totalSabqi = 0;
    double totalManzil = 0;
    int hifzCount = weeklyHifz.length;
    int qaidaCount = weeklyQaida.length;

    double academicScore = 0;
    if (qaidaCount > 0) {
      double totalQaidaPoints = 0;
      for (var q in weeklyQaida) {
        totalQaidaPoints += getGradePoints(q['grade_1'], 25);
        totalQaidaPoints += getGradePoints(q['grade_2'], 25);
        totalQaidaPoints += getGradePoints(q['grade_3'], 25);
        totalQaidaPoints += getGradePoints(q['grade_4'], 25);
      }
      academicScore = totalQaidaPoints / qaidaCount;
      hifzCount = qaidaCount; // Use hifzCount as generic record count for UI
    } else if (hifzCount > 0) {
      for (var h in weeklyHifz) {
        totalSabaq += getGradePoints(h['sabaq_grade'], 30);
        totalSabqi += getGradePoints(h['sabqi_grade'], 30);
        totalManzil += getGradePoints(h['manzil_grade'], 40);
      }
      academicScore = (totalSabaq + totalSabqi + totalManzil) / hifzCount;
    }

    return {
      'attendancePerc': attendancePerc.round(),
      'academicScore': academicScore.round(),
      'presentDays': present,
      'totalDays': totalDaysMeasured,
      'lateCount': lateCount,
      'hifzCount': hifzCount,
      'startDate': DateFormat('dd MMM').format(start),
      'endDate': DateFormat('dd MMM').format(end),
    };
  }
}
