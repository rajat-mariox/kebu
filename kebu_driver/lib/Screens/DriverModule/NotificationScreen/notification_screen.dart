import 'package:flutter/material.dart';
import 'package:kebu_driver/Screens/DriverModule/BookingDetailScreen/booking_detail_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:kebu_driver/Utils/AppColors/app_colors.dart';

class DriverNotificationScreen extends StatefulWidget {
  const DriverNotificationScreen({super.key});

  @override
  State<DriverNotificationScreen> createState() =>
      _DriverNotificationScreenState();
}

class _DriverNotificationScreenState extends State<DriverNotificationScreen> {
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await DriverApiService.getNotifications();
    if (!mounted) return;
    if (res.success && res.data is Map) {
      setState(() {
        _notifications = (res.data['notifications'] as List?) ?? [];
        _unreadCount = (res.data['unreadCount'] as int?) ?? 0;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    await DriverApiService.markAllNotificationsRead();
    _load();
  }

  Future<void> _markOneRead(String id) async {
    await DriverApiService.markNotificationRead(id);
    _load();
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}min';
      if (diff.inHours < 24) return '${diff.inHours}hr';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}w';
    } catch (_) {
      return '';
    }
  }

  String _dateGroup(String? dateStr) {
    if (dateStr == null) return 'Earlier';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final notifDay = DateTime(date.year, date.month, date.day);
      if (notifDay == today) return 'Today';
      if (notifDay == yesterday) return 'Yesterday';
      if (now.difference(date).inDays < 7) return 'This Week';
      return 'Earlier';
    } catch (_) {
      return 'Earlier';
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<dynamic>>{};
    for (final n in _notifications) {
      final g = _dateGroup(n['createdAt']);
      grouped.putIfAbsent(g, () => []).add(n);
    }
    const orderedGroups = ['Today', 'Yesterday', 'This Week', 'Earlier'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Gradient header
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 50, 16, 18),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: 20),
                ),
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (_unreadCount > 0)
                  InkWell(
                    onTap: _markAllRead,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Mark all read',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          itemCount: orderedGroups.length,
                          itemBuilder: (context, gi) {
                            final groupName = orderedGroups[gi];
                            final items = grouped[groupName];
                            if (items == null || items.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                      20, gi == 0 ? 4 : 16, 20, 8),
                                  child: Text(
                                    groupName,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: List.generate(items.length,
                                        (i) {
                                      final n = items[i];
                                      final isLast = i == items.length - 1;
                                      return Column(
                                        children: [
                                          _tile(n),
                                          if (!isLast)
                                            Divider(
                                              height: 1,
                                              color: Colors.grey
                                                  .withValues(alpha: 0.15),
                                              indent: 18,
                                              endIndent: 18,
                                            ),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> n) {
    final isRead = n['isRead'] == true;
    final timeAgo = _timeAgo(n['createdAt']);
    return InkWell(
      onTap: () {
        if (!isRead) _markOneRead(n['_id']?.toString() ?? '');
        // If this notification points at a booking (every ride status
        // notification does — accepted, arrived, started, completed,
        // cancelled), open the detail screen for it.
        final data = n['data'];
        final bookingId = (data is Map ? data['bookingId'] : null)?.toString();
        if (bookingId != null && bookingId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookingDetailScreen(bookingId: bookingId),
            ),
          );
        }
      },
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.brandGradient,
              ),
              child: const Icon(Icons.notifications,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n['title']?.toString() ?? 'Notification',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: Colors.black87),
                        ),
                      ),
                      Text(timeAgo,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n['message']?.toString() ?? '',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                        height: 1.35),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.pinkColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No notifications yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text('Ride updates will appear here',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
