import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  // Figma method lists
  static const List<Map<String, String>> _preferredMethods = [
    {'name': 'Google Pay', 'asset': 'assets/payments/google_pay_icon.png'},
    {'name': 'Paytm', 'asset': 'assets/payments/paytm_icon.png'},
    {'name': 'Credit / Debit Card', 'asset': 'assets/payments/mastercard_icon.png'},
  ];
  static const List<Map<String, String>> _upiMethods = [
    {'name': 'PhonePe UPI', 'asset': 'assets/payments/phone_pay.png'},
    {'name': 'Mobikwik', 'asset': 'assets/payments/mobikwik_icon.png'},
    {'name': 'CRED pay', 'asset': 'assets/payments/cred_pay.png'},
  ];

  Future<void> _showAddMethodSheet() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddPaymentMethodSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: GestureDetector(
            onTap: _showAddMethodSheet,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [HexColor("#FFD546"), HexColor("#FF155E")],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text("Add Payment Method",
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          letterSpacing: -0.4)),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Stack(
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
                    const SizedBox(width: 4),
                    Text(
                      "Payment Methods",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const NotificationIconButton(height: 33),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.only(top: 120),
              padding: const EdgeInsets.fromLTRB(19, 26, 19, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Preferred Mode"),
                  const SizedBox(height: 12),
                  _buildCard(
                    children: _withDividers(
                      _preferredMethods.map(_methodTile).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle("UPI"),
                  const SizedBox(height: 12),
                  _buildCard(
                    children: _withDividers(
                      _upiMethods.map(_methodTile).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- helpers ----------

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.25,
          color: Colors.black,
        ),
      );

  List<Widget> _withDividers(List<Widget> tiles) {
    final out = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      out.add(tiles[i]);
      if (i != tiles.length - 1) {
        out.add(Divider(height: 1, thickness: 1, color: HexColor("#ECECEC")));
      }
    }
    return out;
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _iconBox(Widget child) => Container(
        width: 42,
        height: 42,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(color: HexColor("#CAC7C7"), width: 0.6),
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: child,
      );

  Widget _methodTile(Map<String, String> m) {
    return InkWell(
      onTap: _showAddMethodSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _iconBox(Image.asset(m['asset']!,
                width: 28, height: 28, fit: BoxFit.contain)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(m['name']!,
                  style: GoogleFonts.montserrat(
                      fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.add_circle_outline,
                color: HexColor("#FD6B22"), size: 22),
          ],
        ),
      ),
    );
  }
}

class _AddPaymentMethodSheet extends StatefulWidget {
  const _AddPaymentMethodSheet();

  @override
  State<_AddPaymentMethodSheet> createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends State<_AddPaymentMethodSheet> {
  final _formKey = GlobalKey<FormState>();
  final _upiIdCtrl = TextEditingController();
  final _cardHolderCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();

  String _type = 'UPI';
  String _upiApp = 'Google Pay';
  bool _isDefault = true;
  bool _saving = false;

  @override
  void dispose() {
    _upiIdCtrl.dispose();
    _cardHolderCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'type': _type,
      'isDefault': _isDefault,
    };

    if (_type == 'UPI') {
      data['upiId'] = _upiIdCtrl.text.trim();
      data['upiApp'] = _upiApp;
    } else if (_type == 'CARD') {
      final cardNumber = _cardNumberCtrl.text.replaceAll(RegExp(r'\s+'), '');
      data['cardHolderName'] = _cardHolderCtrl.text.trim();
      data['cardLast4'] =
          cardNumber.length >= 4 ? cardNumber.substring(cardNumber.length - 4) : cardNumber;
      data['cardBrand'] = _detectCardBrand(cardNumber);
      data['cardExpiry'] = _cardExpiryCtrl.text.trim();
    } else {
      final accountNumber =
          _accountNumberCtrl.text.replaceAll(RegExp(r'\s+'), '');
      data['bankName'] = _bankNameCtrl.text.trim();
      data['accountLast4'] = accountNumber.length >= 4
          ? accountNumber.substring(accountNumber.length - 4)
          : accountNumber;
    }

    setState(() => _saving = true);
    final response =
        await CustomerFeaturesApiService.addPaymentMethod(data);

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.success
              ? 'Payment method added'
              : (response.message ?? 'Failed to add payment method'),
        ),
      ),
    );

    if (response.success) {
      Navigator.pop(context, true);
    }
  }

  String _detectCardBrand(String number) {
    if (number.startsWith('4')) return 'Visa';
    if (number.startsWith('5')) return 'Mastercard';
    if (number.startsWith('3')) return 'Amex';
    if (number.startsWith('6')) return 'RuPay';
    return 'Card';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Payment Method',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: _inputDecoration('Method Type'),
                items: const [
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'CARD', child: Text('Credit / Debit Card')),
                  DropdownMenuItem(value: 'NETBANKING', child: Text('Netbanking')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
              ),
              const SizedBox(height: 14),
              if (_type == 'UPI') ...[
                TextFormField(
                  controller: _upiIdCtrl,
                  decoration: _inputDecoration('UPI ID'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'UPI ID is required';
                    }
                    if (!value.contains('@')) {
                      return 'Enter a valid UPI ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _upiApp,
                  decoration: _inputDecoration('UPI App'),
                  items: const [
                    DropdownMenuItem(value: 'Google Pay', child: Text('Google Pay')),
                    DropdownMenuItem(value: 'PhonePe', child: Text('PhonePe')),
                    DropdownMenuItem(value: 'Paytm', child: Text('Paytm')),
                    DropdownMenuItem(value: 'BHIM', child: Text('BHIM')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _upiApp = value);
                    }
                  },
                ),
              ],
              if (_type == 'CARD') ...[
                TextFormField(
                  controller: _cardHolderCtrl,
                  decoration: _inputDecoration('Card Holder Name'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Card holder name is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cardNumberCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Card Number'),
                  validator: (value) {
                    final digits =
                        (value ?? '').replaceAll(RegExp(r'\s+'), '');
                    if (digits.length < 12) {
                      return 'Enter a valid card number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cardExpiryCtrl,
                  decoration: _inputDecoration('Expiry (MM/YY)'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Expiry is required' : null,
                ),
              ],
              if (_type == 'NETBANKING') ...[
                TextFormField(
                  controller: _bankNameCtrl,
                  decoration: _inputDecoration('Bank Name'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Bank name is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _accountNumberCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Account Number'),
                  validator: (value) {
                    final digits =
                        (value ?? '').replaceAll(RegExp(r'\s+'), '');
                    if (digits.length < 6) {
                      return 'Enter a valid account number';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                activeThumbColor: HexColor("#FF3B59"),
                title: Text(
                  'Set as default method',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                onChanged: (value) => setState(() => _isDefault = value),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HexColor("#FF3B59"),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save Method',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: HexColor("#FF3B59")),
      ),
    );
  }
}
