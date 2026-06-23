import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';

class ScratchCardScreen extends StatefulWidget {
  const ScratchCardScreen({super.key});

  @override
  State<ScratchCardScreen> createState() => _ScratchCardScreenState();
}

class _ScratchCardScreenState extends State<ScratchCardScreen> {
  bool _loading = true;
  List<dynamic> _cards = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await CustomerFeaturesApiService.getScratchCards();
      if (res.success) {
        _cards = (res.data?['cards'] as List?) ?? [];
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reveal(Map<String, dynamic> card) async {
    final res = await CustomerFeaturesApiService.scratchCard(card['_id']);
    if (!mounted) return;
    if (res.success) {
      final revealed = Map<String, dynamic>.from(res.data?['card'] ?? {});
      await _showRewardDialog(revealed);
      _fetch();
    } else {
      Fluttertoast.showToast(msg: res.message ?? 'Could not reveal');
    }
  }

  Future<void> _showRewardDialog(Map<String, dynamic> card) async {
    final rewardType = card['rewardType'] ?? 'BETTER_LUCK';
    final value = card['rewardValue'] ?? 0;
    String title;
    String subtitle;
    IconData icon;
    Color color;
    switch (rewardType) {
      case 'WALLET_CREDIT':
        title = '\u20B9$value credited!';
        subtitle = 'Added to your Kebu wallet';
        icon = Icons.account_balance_wallet;
        color = Colors.green;
        break;
      case 'DISCOUNT_COUPON':
        title = '$value% OFF';
        subtitle = 'Code: ${card['couponCode'] ?? ''}';
        icon = Icons.confirmation_num;
        color = Colors.orange;
        break;
      default:
        title = 'Better luck next time!';
        subtitle = 'Keep riding with Kebu — more rewards await.';
        icon = Icons.sentiment_satisfied;
        color = Colors.blueGrey;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text('Scratch Cards',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: _cards.length,
                    itemBuilder: (_, i) => _card(Map<String, dynamic>.from(_cards[i])),
                  ),
                ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_giftcard, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No scratch cards yet',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Complete rides to earn surprise rewards!',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> card) {
    final status = card['status'] ?? 'UNSCRATCHED';
    final title = card['title'] ?? 'Surprise!';
    final unscratched = status == 'UNSCRATCHED';
    final expired = status == 'EXPIRED';
    final expiresAt = DateTime.tryParse(card['expiresAt'] ?? '');

    return GestureDetector(
      onTap: unscratched ? () => _reveal(card) : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: unscratched
              ? LinearGradient(
                  colors: [HexColor('#FFB800'), HexColor('#FF7A00')],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: unscratched ? null : Colors.white,
          border: unscratched ? null : Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  unscratched ? Icons.card_giftcard : Icons.check_circle,
                  color: unscratched ? Colors.white : Colors.green,
                  size: 22,
                ),
                const Spacer(),
                if (expired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Expired',
                        style: GoogleFonts.poppins(color: Colors.red, fontSize: 9)),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              unscratched ? 'Tap to Scratch' : title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: unscratched ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              unscratched
                  ? 'A surprise reward is waiting!'
                  : _rewardText(card),
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: unscratched ? Colors.white70 : Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (expiresAt != null && unscratched) ...[
              const SizedBox(height: 8),
              Text(
                'Expires ${expiresAt.day}/${expiresAt.month}',
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _rewardText(Map<String, dynamic> card) {
    final type = card['rewardType'];
    final value = card['rewardValue'] ?? 0;
    if (type == 'WALLET_CREDIT') return '\u20B9$value added to wallet';
    if (type == 'DISCOUNT_COUPON') return '$value% off • ${card['couponCode'] ?? ''}';
    return 'Better luck next time';
  }
}
