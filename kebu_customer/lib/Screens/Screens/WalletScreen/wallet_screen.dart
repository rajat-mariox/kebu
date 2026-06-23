import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/Screens/BookARideModule/UpiCheckoutScreen/payment_checkout_screen.dart';
import 'package:kebu_customer/Services/payment_api_service.dart';
import 'package:kebu_customer/Services/wallet_api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double balance = 0;
  List<dynamic> transactions = [];
  bool isLoading = true;
  double? selectedAmount;
  bool isRecharging = false;

  final List<Map<String, dynamic>> rechargeOptions = [
    {'amount': 20.0, 'bonus': 10},
    {'amount': 50.0, 'bonus': 25},
    {'amount': 100.0, 'bonus': 50},
    {'amount': 200.0, 'bonus': 100},
    {'amount': 500.0, 'bonus': 250},
    {'amount': 1000.0, 'bonus': 150},
    {'amount': 2000.0, 'bonus': 300},
    {'amount': 4000.0, 'bonus': 600},
    {'amount': 8000.0, 'bonus': 1200},
    {'amount': 15000.0, 'bonus': 2000},
  ];

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final response = await WalletApiService.getWallet();
    if (response.success && response.data != null && mounted) {
      setState(() {
        balance = (response.data['balance'] ?? 0).toDouble();
        transactions = response.data['transactions'] ?? [];
        isLoading = false;
      });
    } else if (mounted) {
      setState(() => isLoading = false);
    }
  }

  double get gstAmount => (selectedAmount ?? 0) * 0.18;
  double get totalAmount => (selectedAmount ?? 0) + gstAmount;
  int get bonusAmount {
    final opt = rechargeOptions.where((e) => e['amount'] == selectedAmount).toList();
    return opt.isNotEmpty ? opt.first['bonus'] : 0;
  }

  Future<void> _initiateRecharge() async {
    if (selectedAmount == null || selectedAmount! <= 0) return;
    setState(() => isRecharging = true);

    final response = await PaymentApiService.createPaymentOrder(
      amount: totalAmount,
      type: 'WALLET_RECHARGE',
      referenceId: 'wallet_recharge_${DateTime.now().millisecondsSinceEpoch}',
    );

    if (!mounted) return;
    setState(() => isRecharging = false);

    if (response.success && response.data != null) {
      final orderId = response.data['orderId'] ?? response.data['order']?['id'];
      final keyId = response.data['keyId'] ?? response.data['key'];

      if (orderId != null && keyId != null) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentCheckoutScreen(
              keyId: keyId,
              orderId: orderId,
              amount: totalAmount,
              paymentType: 'WALLET_RECHARGE',
              referenceId: 'wallet_recharge',
            ),
          ),
        );
        // Reload wallet after payment
        _loadWallet();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message ?? 'Failed to create payment order')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          commonAppBar(
            height: 180,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 55, left: 15, right: 15),
              child: Column(
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
                      ),
                      const Spacer(),
                      const Text("Recharge Wallet", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text("Available Balance", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    "₹ ${balance.toStringAsFixed(0)}",
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          Container(
            margin: const EdgeInsets.only(top: 165),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Recharge Amount", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),

                        // Recharge grid
                        Wrap(
                          spacing: 10,
                          runSpacing: 12,
                          children: rechargeOptions.map((opt) {
                            final amount = opt['amount'] as double;
                            final bonus = opt['bonus'] as int;
                            final isSelected = selectedAmount == amount;
                            return GestureDetector(
                              onTap: () => setState(() => selectedAmount = amount),
                              child: Container(
                                width: (MediaQuery.of(context).size.width - 52) / 3,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? HexColor("#FFD546") : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? HexColor("#FFD546") : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      "₹ ${amount.toStringAsFixed(0)}",
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white.withAlpha(180) : HexColor("#FFF8E1"),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "Get ₹$bonus Extra",
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: HexColor("#E65100")),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // Payment details
                        if (selectedAmount != null) ...[
                          const Text("Payment Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _detailRow("Recharge Amount", "₹ ${selectedAmount!.toStringAsFixed(0)}"),
                                const SizedBox(height: 8),
                                _detailRow("GST (18%)", "₹ ${gstAmount.toStringAsFixed(0)}"),
                                const Divider(height: 20),
                                _detailRow("Total Amount", "₹ ${totalAmount.toStringAsFixed(0)}", bold: true),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Bonus banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: HexColor("#FFF8E1"),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: HexColor("#FFD546")),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: HexColor("#4CAF50"),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text("45%\nEXTRA", textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Rs ${(selectedAmount! + bonusAmount).toStringAsFixed(0)} will be credited to your wallet after the recharge",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Pay Now button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: HexColor("#FFD546"),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: isRecharging ? null : _initiateRecharge,
                              child: Text(
                                isRecharging ? "Processing..." : "Pay Now",
                                style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Transaction history
                        if (transactions.isNotEmpty) ...[
                          const Text("Recent Transactions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          ...transactions.take(10).map((t) => _transactionTile(t)),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      ],
    );
  }

  Widget _transactionTile(Map<String, dynamic> t) {
    final type = t['type'] ?? '';
    final isCredit = type == 'CREDIT';
    final desc = t['description'] ?? (isCredit ? 'Wallet Recharge' : 'Payment');
    final amount = (t['amount'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isCredit ? const Color(0xFFE8F5E9) : const Color(0xFFFCE4EC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(t['status'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            "${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(0)}",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isCredit ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
