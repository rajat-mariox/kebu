import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/DriverModule/WalletModule/recharge_wallet_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/WalletModule/send_amount_action_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/WalletModule/wallet_transaction_list_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Figma "My Wallet" (131:11504) — navy balance card with a blue total-balance
/// header, four circular action shortcuts (Recharge, Statement, Send, Received)
/// and a month-grouped transaction list. All data from [DriverApiService].
class MyWalletScreen extends StatefulWidget {
  const MyWalletScreen({super.key});

  @override
  State<MyWalletScreen> createState() => _MyWalletScreenState();
}

class _MyWalletScreenState extends State<MyWalletScreen> {
  static final _yellow = HexColor('#FFD546');
  static final _gray1 = HexColor('#132235');
  static final _gray2 = HexColor('#364B63');
  static final _gray3 = HexColor('#607080');
  static final _gray5 = HexColor('#D3DDE7');
  static final _bgGray = HexColor('#F0F5FA');
  static final _green = HexColor('#08875D');
  static final _red = HexColor('#E02D3C');
  static final _border2 = HexColor('#E9F0F7');
  static final _navy = HexColor('#132235');
  static final _blue = HexColor('#2F6FED');
  static final _circle = HexColor('#364B63');

  bool _loading = true;
  double _balance = 0;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final res = await DriverApiService.getWallet();
    if (!mounted) return;
    if (res.success && res.data != null) {
      final txs = res.data['transactions'] as List<dynamic>? ?? [];
      setState(() {
        _balance = (res.data['balance'] ?? 0).toDouble();
        _transactions =
            txs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _openRecharge() async {
    final ok =
        await pushTo(context, WalletRechargeScreen(initialBalance: _balance));
    if (ok == true && mounted) _fetch();
  }

  Future<void> _openSendAction() async {
    final ok =
        await pushTo(context, SendAmountActionScreen(initialBalance: _balance));
    if (ok == true && mounted) _fetch();
  }

  void _openStatement() {
    pushTo(
        context,
        const WalletTransactionListScreen(
            title: 'Wallet Statement', type: null));
  }

  void _openReceived() {
    pushTo(
        context,
        const WalletTransactionListScreen(
            title: 'Received Amount', type: 'CREDIT'));
  }

  // ─────────────── build ───────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _bgGray,
      body: Column(
        children: [
          _appBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetch,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _balanceCard(),
                    const SizedBox(height: 16),
                    _transactionList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBar() {
    return Container(
      width: double.infinity,
      color: _yellow,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(99),
                child: Icon(Icons.arrow_back, size: 26, color: _gray1),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'My Wallet',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 25 / 20,
                    color: _gray1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── balance card ───────────────

  Widget _balanceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Blue total balance
          Container(
            width: double.infinity,
            color: _blue,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Column(
              children: [
                Text(
                  'Total balance',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                    letterSpacing: 1,
                    color: _gray5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${_formatBalance(_balance)}',
                  style: GoogleFonts.nunito(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _action(Icons.add_card_outlined, 'Recharge\nWallet',
                    _openRecharge),
                _action(Icons.sticky_note_2_outlined, 'Wallet\nStatement',
                    _openStatement),
                _action(Icons.north_east_rounded, 'Send\nAmount',
                    _openSendAction),
                _action(Icons.south_west_rounded, 'Received\nAmount',
                    _openReceived),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: _circle, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 16 / 12,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── transactions ───────────────

  Widget _transactionList() {
    if (_loading) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_transactions.isEmpty) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'No transactions yet',
            style: GoogleFonts.nunito(fontSize: 13, color: _gray2),
          ),
        ),
      );
    }

    // Group by month-year (createdAt).
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final t in _transactions) {
      grouped.putIfAbsent(_monthLabel(t['createdAt']), () => []).add(t);
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _monthSeparator(entry.key),
            ),
            const SizedBox(height: 16),
            for (final t in entry.value) _txRow(t),
          ],
        ],
      ),
    );
  }

  Widget _monthSeparator(String label) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: HexColor('#E1E6EF'))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 13 / 11,
              color: _gray3,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: HexColor('#E1E6EF'))),
      ],
    );
  }

  Widget _txRow(Map<String, dynamic> tx) {
    final isCredit = (tx['type'] ?? '').toString() == 'CREDIT';
    final amount = (tx['amount'] ?? 0).toDouble();
    final description = (tx['description'] ?? '').toString().isNotEmpty
        ? tx['description'].toString()
        : (isCredit ? 'Your Earning' : 'Send Amount');
    final ref = (tx['referenceId'] ?? tx['_id'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border2)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 20 / 15,
                    color: _gray1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reference ID: ${ref.isNotEmpty ? ref : '-'}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 16 / 12,
                    color: _gray2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${isCredit ? '+' : '-'} ₹${amount.toStringAsFixed(2)}',
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 22 / 17,
              color: isCredit ? _green : _red,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── helpers ───────────────

  String _monthLabel(dynamic date) {
    if (date == null) return 'EARLIER';
    try {
      final dt = DateTime.parse(date.toString()).toLocal();
      const months = [
        'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
        'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
      ];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return 'EARLIER';
    }
  }

  static String _formatBalance(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final whole = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
      buf.write(whole[i]);
    }
    return '$buf.${parts[1]}';
  }
}
