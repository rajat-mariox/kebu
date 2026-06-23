import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic> notifications = [];
  int unreadCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final response = await CustomerFeaturesApiService.getNotifications();
    if (response.success && response.data != null && mounted) {
      setState(() {
        notifications = response.data['notifications'] ?? [];
        unreadCount = response.data['unreadCount'] ?? 0;
        isLoading = false;
      });
    } else if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    await CustomerFeaturesApiService.markAllNotificationsRead();
    _loadNotifications();
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}min';
      if (diff.inHours < 24) return '${diff.inHours} hr';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}w';
    } catch (_) {
      return '';
    }
  }

  String _getDateGroup(String? dateStr) {
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

  _NotifStyle _styleFor(String type) {
    switch (type.toUpperCase()) {
      case 'REMINDER':
        return _NotifStyle(
            bg: HexColor("#EEEEF7"),
            asset: "assets/notif_reminder.svg",
            isSvg: true);
      case 'MESSAGE':
        return _NotifStyle(
            bg: HexColor("#E8F0FE"),
            icon: Icons.chat_bubble_rounded,
            iconColor: HexColor("#2F80ED"));
      case 'ORDER':
        return _NotifStyle(
            bg: HexColor("#E1F4E5"),
            asset: "assets/notif_done.svg",
            isSvg: true);
      case 'OFFER':
        return _NotifStyle(
            bg: HexColor("#F4E1E1"), asset: "assets/notif_offer.png");
      case 'SYSTEM':
        return _NotifStyle(
            bg: HexColor("#F3E5F5"),
            icon: Icons.info_rounded,
            iconColor: HexColor("#7E57C2"));
      default:
        return _NotifStyle(
            bg: HexColor("#EEEEF7"),
            asset: "assets/notif_reminder.svg",
            isSvg: true);
    }
  }

  Widget _thumbIcon(_NotifStyle style) {
    if (style.asset != null) {
      if (style.isSvg) {
        return SvgPicture.asset(style.asset!, width: 32, height: 32);
      }
      return Image.asset(style.asset!, width: 34, height: 34);
    }
    return Icon(style.icon, color: style.iconColor, size: 28);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<dynamic>> grouped = {};
    for (final notif in notifications) {
      grouped.putIfAbsent(_getDateGroup(notif['createdAt']), () => []).add(notif);
    }
    final orderedGroups = ['Today', 'Yesterday', 'This Week', 'Earlier']
        .where((g) => grouped[g]?.isNotEmpty ?? false)
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          commonAppBar(
            height: 160,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 55, left: 12, right: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.arrow_back_ios_new,
                          size: 18, color: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "Notification",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Subtle mark-all action (kept for usability)
                  SizedBox(
                    width: 40,
                    child: unreadCount > 0
                        ? InkWell(
                            onTap: _markAllRead,
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.done_all_rounded,
                                  size: 22, color: Colors.white),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 120),
            width: MediaQuery.of(context).size.width,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(60),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : notifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 24),
                        itemCount: orderedGroups.length,
                        itemBuilder: (context, groupIndex) {
                          final groupName = orderedGroups[groupIndex];
                          final items = grouped[groupName]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                    30, groupIndex == 0 ? 20 : 16, 30, 4),
                                child: Text(
                                  groupName,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.35,
                                    color: HexColor("#1B1D21"),
                                  ),
                                ),
                              ),
                              ...items.map((n) => _buildNotificationTile(
                                  Map<String, dynamic>.from(n as Map))),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text(
              "No notifications yet",
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "We'll notify you when something arrives",
              style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notif) {
    final type = (notif['type'] ?? '').toString();
    final style = _styleFor(type);
    final isRead = notif['isRead'] ?? false;
    final timeAgo = _timeAgo(notif['createdAt']?.toString());
    final image = notif['image']?.toString();

    return InkWell(
      onTap: () async {
        if (!isRead && notif['_id'] != null) {
          await CustomerFeaturesApiService.markNotificationRead(
              notif['_id'].toString());
          _loadNotifications();
        }
      },
      child: Container(
        color: isRead ? Colors.transparent : HexColor("#FF155E").withOpacity(0.02),
        padding: const EdgeInsets.fromLTRB(26, 14, 26, 14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rounded-square thumbnail
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: style.bg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: (image != null && image.isNotEmpty)
                      ? Image.network(
                          image,
                          fit: BoxFit.cover,
                          width: 60,
                          height: 60,
                          errorBuilder: (_, __, ___) => _thumbIcon(style),
                        )
                      : _thumbIcon(style),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notif['title']?.toString() ?? 'Notification',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: -0.3,
                                color: HexColor("#171717"),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeAgo,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.3,
                              color: HexColor("#D9D9D9"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif['message']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                          color: HexColor("#8F92A1"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(
                height: 1, color: HexColor("#8F92A1").withOpacity(0.1)),
          ],
        ),
      ),
    );
  }
}

class _NotifStyle {
  final Color bg;
  final String? asset;
  final bool isSvg;
  final IconData? icon;
  final Color? iconColor;
  _NotifStyle({
    required this.bg,
    this.asset,
    this.isSvg = false,
    this.icon,
    this.iconColor,
  });
}
