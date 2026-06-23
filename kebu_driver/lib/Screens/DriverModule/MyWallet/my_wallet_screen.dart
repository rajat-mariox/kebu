import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:kebu_driver/Screens/DriverModule/ReceivedAmount/received_amount.dart';
import 'package:kebu_driver/Screens/DriverModule/RechargeWalletScreen/recharge_wallet_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/SendMoney/send_money.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:flutter/material.dart';

class MyWalletScreen extends StatefulWidget {
  const MyWalletScreen({super.key});

  @override
  State<MyWalletScreen> createState() => _MyWalletScreenState();
}

class _MyWalletScreenState extends State<MyWalletScreen> {
  double _totalEarnings = 0;
  int _totalRides = 0;
  List<Map<String, dynamic>> _recentBookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  Future<void> _fetchEarnings() async {
    final res = await DriverApiService.getEarnings();
    if (res.success && res.data != null && mounted) {
      setState(() {
        _totalEarnings = (res.data['totalEarnings'] ?? 0).toDouble();
        _totalRides = res.data['totalRides'] ?? 0;
        final list = res.data['recentBookings'] as List<dynamic>? ?? [];
        _recentBookings =
            list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            commonAppBar(
              height: 100,
              context: context,
              child: Container(
                padding: const EdgeInsets.only(top: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.only(left: 16),
                        width: 40,
                        height: 35,
                        alignment: Alignment.center,
                        child: Image.asset("assets/back_arrow.png",
                            color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "My Wallet",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            _buildBalanceCard(),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )
            else if (_recentBookings.isEmpty)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(40),
                width: double.infinity,
                child: const Center(
                  child: Text("No transactions yet",
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                ),
              )
            else ...[
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(children: <Widget>[
                  const Expanded(child: Divider(thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      "RECENT EARNINGS",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey[700]),
                    ),
                  ),
                  const Expanded(child: Divider(thickness: 1)),
                ]),
              ),
              Container(height: 8, color: Colors.white),
              Container(
                color: Colors.white,
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 0),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentBookings.length,
                  itemBuilder: (context, index) {
                    return _buildTransactionTile(_recentBookings[index]);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2575FC), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              children: [
                const Text("Total Earnings",
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text(
                  "₹${_totalEarnings.toStringAsFixed(2)}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "$_totalRides rides completed",
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2A),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionItem(
                    'assets/rechage_amount.png', "Recharge\nWallet", () {
                  pushTo(context, const RechargeScreen());
                }),
                _buildActionItem(
                    'assets/statement.png', "Wallet\nStatement", () {}),
                _buildActionItem(
                    'assets/send_amount.png', "Send\nAmount", () {
                  pushTo(context, const SendMoney());
                }),
                _buildActionItem(
                    'assets/recieve_amount.png', "Received\nAmount", () {
                  pushTo(context, const ReceivedAmount());
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(String icon, String label, Function onTap) {
    return InkWell(
      onTap: () => onTap(),
      child: Column(
        children: [
          Image.asset(icon, height: 40),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> booking) {
    final fare = (booking['finalFare'] ?? booking['fare'] ?? 0).toDouble();
    final bookingId = booking['_id']?.toString() ?? '';
    final shortId = bookingId.length > 8
        ? bookingId.substring(bookingId.length - 8).toUpperCase()
        : bookingId.toUpperCase();
    final status = booking['status']?.toString() ?? '';

    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status == 'COMPLETED' ? "Your Earning" : status,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text("Reference ID: $shortId",
                      style:
                          TextStyle(color: Colors.grey[700], fontSize: 10)),
                  const SizedBox(height: 6),
                ],
              ),
              const Spacer(),
              Text(
                "+ ₹${fare.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 0.5,
          width: MediaQuery.of(context).size.width,
          color: Colors.grey[400],
        ),
      ],
    );
  }
}
