import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

/// A weekday-aligned range calendar. Backend-driven: only [availableDays]
/// (and dates on/after [firstDate]) are selectable. Reports the chosen range
/// through [onChanged].
class RangeCalendar extends StatefulWidget {
  /// Earliest selectable day (defaults to today).
  final DateTime? firstDate;

  /// Set of selectable days (stripped to y/m/d). Null = all future days open.
  final Set<DateTime>? availableDays;

  final void Function(DateTime? start, DateTime? end)? onChanged;

  const RangeCalendar({
    super.key,
    this.firstDate,
    this.availableDays,
    this.onChanged,
  });

  @override
  State<RangeCalendar> createState() => _RangeCalendarState();
}

class _RangeCalendarState extends State<RangeCalendar> {
  DateTime? startDate;
  DateTime? endDate;

  late final DateTime _first;
  late final List<DateTime> days;

  static final Color _selected = HexColor('#DE3D8F');
  static final Color _range = HexColor('#FDECF5');

  @override
  void initState() {
    super.initState();
    _first = _strip(widget.firstDate ?? DateTime.now());
    days = _generateGrid(_first);
  }

  /// Six weeks (42 days) starting on the Monday of [anchor]'s week — enough to
  /// cover the ~30-day available window.
  List<DateTime> _generateGrid(DateTime anchor) {
    final weekStart = anchor.subtract(Duration(days: anchor.weekday - 1));
    return List.generate(
      42,
      (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
    );
  }

  DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSelectable(DateTime d) {
    d = _strip(d);
    if (d.isBefore(_first)) return false;
    if (widget.availableDays != null && !widget.availableDays!.contains(d)) {
      return false;
    }
    return true;
  }

  void onTap(DateTime d) {
    d = _strip(d);
    if (!_isSelectable(d)) return;
    setState(() {
      if (startDate == null || endDate != null) {
        startDate = d;
        endDate = null;
      } else if (d.isAfter(startDate!)) {
        endDate = d;
      } else {
        startDate = d;
        endDate = null;
      }
    });
    widget.onChanged?.call(startDate, endDate);
  }

  bool _isEdge(DateTime d) {
    d = _strip(d);
    return (startDate != null && d.isAtSameMomentAs(_strip(startDate!))) ||
        (endDate != null && d.isAtSameMomentAs(_strip(endDate!)));
  }

  bool _inRange(DateTime d) {
    if (startDate == null || endDate == null) return false;
    d = _strip(d);
    return !d.isBefore(_strip(startDate!)) && !d.isAfter(_strip(endDate!));
  }

  @override
  Widget build(BuildContext context) {
    const monthAbbr = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return Column(
      children: List.generate(6, (r) {
        final row = days.sublist(r * 7, r * 7 + 7);
        // Skip fully-out-of-window rows (all before first selectable day).
        if (row.every((d) => _strip(d).isBefore(_first))) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: row.map((dt) {
              final selectable = _isSelectable(dt);
              final edge = _isEdge(dt);
              final mid = _inRange(dt) && !edge;
              final showMonth = dt.day == 1;
              return GestureDetector(
                onTap: () => onTap(dt),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: edge
                        ? _selected
                        : (mid ? _range : Colors.transparent),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dt.day.toString().padLeft(2, '0'),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          height: 1.1,
                          color: edge
                              ? Colors.white
                              : selectable
                                  ? HexColor('#161938')
                                  : Colors.grey.shade400,
                          fontWeight:
                              edge ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (showMonth)
                        Text(
                          monthAbbr[dt.month - 1],
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            height: 1.0,
                            color: edge ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }),
    );
  }
}
