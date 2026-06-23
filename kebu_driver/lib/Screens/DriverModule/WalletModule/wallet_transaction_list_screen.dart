import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/asset_icon.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Shared wallet-transactions screen used by Received Amount (CREDIT),
/// Send Amount (DEBIT), and the Wallet Statement (all). Renders the list
/// grouped by month per Figma 131:11578 / 131:11657.
class WalletTransactionListScreen extends StatefulWidget {
  /// Title shown in the yellow app bar.
  final String title;

  /// `'CREDIT'` for received, `'DEBIT'` for sent, null for the full
  /// statement (mixed +/- amounts).
  final String? type;

  const WalletTransactionListScreen({
    super.key,
    required this.title,
    this.type,
  });

  @override
  State<WalletTransactionListScreen> createState() =>
      _WalletTransactionListScreenState();
}

class _WalletTransactionListScreenState
    extends State<WalletTransactionListScreen> {
  static final _yellow = HexColor('#FFD546');
  static final _gray1 = HexColor('#132235');
  static final _gray2 = HexColor('#364B63');
  static final _gray3 = HexColor('#607080');
  static final _gray6 = HexColor('#E9F0F7');
  static final _border = HexColor('#E1E6EF');
  static final _bgGray = HexColor('#F0F5FA');
  static final _green = HexColor('#08875D');
  static final _red = HexColor('#E02D3C');

  bool _loading = true;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final res = await DriverApiService.getWalletTransactions(
      type: widget.type,
      page: 0,
      limit: 100,
    );
    if (!mounted) return;
    final list = (res.success && res.data != null)
        ? (res.data['transactions'] as List<dynamic>? ?? [])
        : [];
    setState(() {
      _transactions = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByMonth(_transactions);

    return Scaffold(
      backgroundColor: _bgGray,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _appBar(context),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: groups.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    'No transactions yet',
                                    style: GoogleFonts.nunito(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: _gray2,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              color: Colors.white,
                              child: ListView.builder(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.only(top: 16, bottom: 16),
                                itemCount: groups.length,
                                itemBuilder: (_, i) {
                                  final g = groups[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _monthHeader(g.label),
                                        const SizedBox(height: 16),
                                        for (int j = 0;
                                            j < g.items.length;
                                            j++)
                                          _row(
                                            g.items[j],
                                            isLast: j == g.items.length - 1,
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── app bar ───────────────

  Widget _appBar(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _yellow,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 18),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: AssetIcon(
                'assets/history/arrow_left.svg',
                width: 28,
                height: 28,
                color: _gray1,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              widget.title,
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
    );
  }

  // ─────────────── month header ───────────────

  Widget _monthHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: _border)),
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
          Expanded(child: Container(height: 1, color: _border)),
        ],
      ),
    );
  }

  // ─────────────── row ───────────────

  Widget _row(Map<String, dynamic> tx, {required bool isLast}) {
    final isCredit = (tx['type'] ?? '').toString() == 'CREDIT';
    final amount = (tx['amount'] ?? 0).toDouble();
    final description =
        (tx['description'] ?? '').toString().isNotEmpty
            ? tx['description'].toString()
            : (isCredit ? 'Your Earning' : 'Send Amount');
    final ref = (tx['referenceId'] ?? tx['_id'] ?? '').toString();
    final shortRef = _shortRef(ref);

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: _gray6)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
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
                  'Reference ID: $shortRef',
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

  String _shortRef(String ref) {
    if (ref.isEmpty) return '—';
    if (ref.length <= 16) return ref.toUpperCase();
    return ref.substring(ref.length - 16).toUpperCase();
  }

  List<_MonthGroup> _groupByMonth(List<Map<String, dynamic>> txs) {
    const months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];

    final map = <String, List<Map<String, dynamic>>>{};
    final order = <String>[];

    for (final t in txs) {
      final raw = t['createdAt'];
      if (raw == null) continue;
      DateTime dt;
      try {
        dt = DateTime.parse(raw.toString()).toLocal();
      } catch (_) {
        continue;
      }
      final label = '${months[dt.month - 1]} ${dt.year}';
      if (!map.containsKey(label)) {
        map[label] = [];
        order.add(label);
      }
      map[label]!.add(t);
    }

    return order.map((l) => _MonthGroup(label: l, items: map[l]!)).toList();
  }
}

class _MonthGroup {
  final String label;
  final List<Map<String, dynamic>> items;
  _MonthGroup({required this.label, required this.items});
}
