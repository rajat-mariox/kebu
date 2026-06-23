import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/asset_icon.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Triggers a debit from the driver wallet (Send Amount action). Reuses
/// the same in-screen keypad layout as Recharge for consistency.
class SendAmountActionScreen extends StatefulWidget {
  final double initialBalance;
  const SendAmountActionScreen({super.key, this.initialBalance = 0});

  @override
  State<SendAmountActionScreen> createState() =>
      _SendAmountActionScreenState();
}

class _SendAmountActionScreenState extends State<SendAmountActionScreen> {
  static final _yellow = HexColor('#FFD546');
  static final _gray1 = HexColor('#132235');
  static final _gray2 = HexColor('#364B63');
  static final _bgGray = HexColor('#F0F5FA');
  static final _blue = HexColor('#2F6FED');
  static final _red = HexColor('#E02D3C');

  String _amount = '500';
  double _balance = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _balance = widget.initialBalance;
    _refreshBalance();
  }

  Future<void> _refreshBalance() async {
    final res = await DriverApiService.getWallet();
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() => _balance = (res.data['balance'] ?? 0).toDouble());
    }
  }

  void _onKey(String k) {
    setState(() {
      if (_amount == '0') {
        _amount = k;
      } else {
        if ((_amount + k).length > 7) return;
        _amount = _amount + k;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amount.length <= 1) {
        _amount = '0';
      } else {
        _amount = _amount.substring(0, _amount.length - 1);
      }
    });
  }

  Future<void> _onSend() async {
    final value = double.tryParse(_amount) ?? 0;
    if (value <= 0) {
      Fluttertoast.showToast(msg: 'Enter an amount');
      return;
    }
    if (value > _balance) {
      Fluttertoast.showToast(
        msg: 'Insufficient balance',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }
    setState(() => _busy = true);
    final res =
        await DriverApiService.sendFromWallet(amount: value);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      Fluttertoast.showToast(msg: 'Sent ₹${value.toStringAsFixed(0)}');
      Navigator.pop(context, true);
    } else {
      Fluttertoast.showToast(
        msg: res.message.isEmpty ? 'Send failed' : res.message,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _appBar(context),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                children: [
                  Text(
                    'Available Balance',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 16 / 12,
                      color: _gray2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${_formatBalance(_balance)}',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 25 / 20,
                      color: _gray1,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '₹',
                        style: GoogleFonts.nunito(
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          height: 32 / 22,
                          color: _gray1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _amount,
                        style: GoogleFonts.nunito(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          height: 41 / 34,
                          letterSpacing: -0.4,
                          color: _gray1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _BlinkingCursor(color: _blue),
                    ],
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _onSend,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          disabledBackgroundColor:
                              _red.withValues(alpha: 0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Send Now',
                                style: GoogleFonts.nunito(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  height: 22 / 17,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Keypad(onKey: _onKey, onBackspace: _onBackspace),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              'Send Amount',
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

  static String _formatBalance(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final whole = parts[0];
    final buf = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
      buf.write(whole[i]);
    }
    return '${buf.toString()}.${parts[1]}';
  }
}

class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(width: 1, height: 32, color: widget.color),
    );
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  const _Keypad({required this.onKey, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    final bg = HexColor('#E3E5E5');

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  for (final k in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _Key(
                          label: k,
                          onTap: k.isEmpty
                              ? null
                              : k == '⌫'
                                  ? onBackspace
                                  : () => onKey(k),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _Key({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox(height: 47);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 47,
        decoration: BoxDecoration(
          color: label == '⌫' ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: label == '⌫'
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    offset: const Offset(0, 1),
                    blurRadius: 0.5,
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: label == '⌫'
            ? const Icon(Icons.backspace_outlined,
                color: Colors.black, size: 22)
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF0E0F0F),
                ),
              ),
      ),
    );
  }
}
