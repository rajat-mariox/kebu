import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';
import 'package:share_plus/share_plus.dart';

class ReferAFriendScreen extends StatefulWidget {
  const ReferAFriendScreen({super.key});
  @override
  State<ReferAFriendScreen> createState() => _ReferAFriendScreenState();
}

class _ReferAFriendScreenState extends State<ReferAFriendScreen> {
  String referralCode = '';
  int totalReferrals = 0;
  double totalEarnings = 0;
  int completedReferrals = 0;
  int pendingReferrals = 0;
  double referrerReward = 400;
  double referredReward = 50;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReferralInfo();
  }

  Future<void> _loadReferralInfo() async {
    final response = await CustomerFeaturesApiService.getReferralInfo();
    if (response.success && response.data != null && mounted) {
      setState(() {
        referralCode = response.data['referralCode'] ?? '';
        totalReferrals = response.data['totalReferrals'] ?? 0;
        totalEarnings = (response.data['totalEarnings'] ?? 0).toDouble();
        completedReferrals = response.data['completedReferrals'] ?? 0;
        pendingReferrals = response.data['pendingReferrals'] ?? 0;
        referrerReward = (response.data['referrerReward'] ?? 400).toDouble();
        referredReward = (response.data['referredReward'] ?? 50).toDouble();
        isLoading = false;
      });
    } else if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void _shareViaWhatsApp() {
    final text = "Join Kebu and get ₹${referredReward.toStringAsFixed(0)} in your wallet! "
        "Use my referral code: $referralCode\n"
        "Download now: https://kebu.app/refer/$referralCode";
    Share.share(text);
  }

  void _showApplyCodeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Have A Referral Code?", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: "Enter Code",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Enter the referral code received and instantly get ₹${referredReward.toStringAsFixed(0)} in your Kebu Wallet.",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HexColor("#FF6B35"),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final res = await CustomerFeaturesApiService.applyReferralCode(controller.text.trim());
                if (mounted) {
                  if (res.success) {
                    _showAppliedDialog();
                    _loadReferralInfo();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res.message ?? 'Invalid referral code')),
                    );
                  }
                }
              },
              child: const Text("Submit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAppliedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 60),
            const SizedBox(height: 16),
            const Text("Referral Code Applied", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              "We will bet your Referral snow you created an account",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HexColor("#FF6B35"),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          commonAppBar(
            height: 160,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 60, left: 15, right: 15),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
                  ),
                  const Spacer(),
                  const Text("Refer & Earn", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                ],
              ),
            ),
          ),

          Container(
            margin: const EdgeInsets.only(top: 115),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: Column(
                      children: [
                        // Header banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [HexColor("#FFE0B2"), HexColor("#FFCC80")]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Invite your Friend and Earn ₹${referrerReward.toStringAsFixed(0)}",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                              const Text(
                                "For every new user refer",
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                              const SizedBox(height: 16),

                              // 3-step illustration
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: HexColor("#FF6B35"), width: 2),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _stepIcon(Icons.person_add, "Invite your\nFriend"),
                                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                    _stepIcon(Icons.phone_android, "Friend does\nRecharge"),
                                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                    _stepIcon(Icons.wallet, "You get up to\n₹${referrerReward.toStringAsFixed(0)}"),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Referral code
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    const Text("Your Referral Code : ", style: TextStyle(fontSize: 12, color: Colors.black54)),
                                    Text(
                                      referralCode.isNotEmpty ? referralCode : '...',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1),
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () {
                                        if (referralCode.isNotEmpty) {
                                          Clipboard.setData(ClipboardData(text: referralCode));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Referral code copied!")),
                                          );
                                        }
                                      },
                                      child: const Icon(Icons.copy, size: 18, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              Text(
                                "Share your referral code and get a bonus up to ₹${referrerReward.toStringAsFixed(0)}",
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 12),

                              // Social share icons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _socialIcon(Icons.facebook, const Color(0xFF1877F2), () => _shareViaWhatsApp()),
                                  const SizedBox(width: 12),
                                  _socialIcon(Icons.send, const Color(0xFF0088CC), () => _shareViaWhatsApp()),
                                  const SizedBox(width: 12),
                                  _socialIcon(Icons.share, const Color(0xFFE91E63), () => _shareViaWhatsApp()),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Refer via WhatsApp button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: _shareViaWhatsApp,
                                  icon: const Icon(Icons.message, color: Colors.white, size: 20),
                                  label: const Text("Refer Via Whatsapp", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Apply referral code link
                        InkWell(
                          onTap: _showApplyCodeDialog,
                          child: Text(
                            "Have a referral code?",
                            style: TextStyle(color: HexColor("#2196F3"), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Stats row
                        Row(
                          children: [
                            _statCard("Total Referrals", "$totalReferrals", HexColor("#E3F2FD")),
                            const SizedBox(width: 10),
                            _statCard("Total Earned", "₹${totalEarnings.toStringAsFixed(0)}", HexColor("#E8F5E9")),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            _statCard("Completed", "$completedReferrals", HexColor("#FFF3E0")),
                            const SizedBox(width: 10),
                            _statCard("Pending", "$pendingReferrals", HexColor("#FCE4EC")),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // How it works
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("How it works", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 12),
                        _howItWorksStep("1", "Share your referral code with friends"),
                        _howItWorksStep("2", "Your friend signs up and enters your code"),
                        _howItWorksStep("3", "They get ₹${referredReward.toStringAsFixed(0)} instantly in their wallet"),
                        _howItWorksStep("4", "You earn ₹${referrerReward.toStringAsFixed(0)} when they complete their first ride"),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stepIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: HexColor("#FFF3E0"),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: HexColor("#FF6B35")),
        ),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _socialIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _statCard(String label, String value, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _howItWorksStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: HexColor("#FFD546"),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(num, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
