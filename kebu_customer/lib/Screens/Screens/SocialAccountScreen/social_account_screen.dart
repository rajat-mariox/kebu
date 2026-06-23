import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Services/user_api_service.dart';

class SocialAccountScreen extends StatefulWidget {
  const SocialAccountScreen({super.key});

  @override
  State<SocialAccountScreen> createState() => _SocialAccountScreenState();
}

class _SocialAccountScreenState extends State<SocialAccountScreen> {
  bool _loading = true;
  Map<String, dynamic> _accounts = {};

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '865352387710-itkjglplh70qu5bkknspp7dli0l5pp0v.apps.googleusercontent.com',
  );

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    final response = await UserApiService.getSocialAccounts();

    if (!mounted) return;

    setState(() {
      _accounts = response.success
          ? Map<String, dynamic>.from(response.data?['socialAccounts'] ?? {})
          : {};
      _loading = false;
    });
  }

  Map<String, dynamic> _account(String provider) {
    final value = _accounts[provider];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  bool _isConnected(String provider) {
    final account = _account(provider);
    return (account['providerUserId']?.toString().trim().isNotEmpty ?? false);
  }

  // ── Google Sign-In ──
  Future<void> _connectGoogle() async {
    try {
      // Sign out first to ensure account picker shows
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User cancelled

      final response = await UserApiService.linkSocialAccount({
        'provider': 'google',
        'providerUserId': googleUser.id,
        'username': googleUser.displayName ?? '',
        'email': googleUser.email,
        'avatar': googleUser.photoUrl ?? '',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.success
                ? 'Google account linked: ${googleUser.email}'
                : (response.message ?? 'Failed to link Google account'),
          ),
        ),
      );

      if (response.success) _loadAccounts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google sign-in failed. Please try again.')),
      );
    }
  }

  // ── Facebook Sign-In ──
  Future<void> _connectFacebook() async {
    try {
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status != LoginStatus.success) return; // User cancelled or error

      final userData = await FacebookAuth.instance.getUserData(
        fields: "id,name,email,picture.width(200)",
      );

      final avatar = userData['picture']?['data']?['url'] ?? '';

      final response = await UserApiService.linkSocialAccount({
        'provider': 'facebook',
        'providerUserId': userData['id'] ?? '',
        'username': userData['name'] ?? '',
        'email': userData['email'] ?? '',
        'avatar': avatar,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.success
                ? 'Facebook account linked: ${userData['name'] ?? ''}'
                : (response.message ?? 'Failed to link Facebook account'),
          ),
        ),
      );

      if (response.success) _loadAccounts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facebook sign-in failed. Please try again.')),
      );
    }
  }

  // ── X (Twitter) – manual entry since no free OAuth SDK ──
  Future<void> _connectX() async {
    final usernameCtrl = TextEditingController();
    final existing = _account('x');
    usernameCtrl.text = existing['username']?.toString() ?? '';

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 18,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
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
                  'Link your X account',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your X (Twitter) username to link your account.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: usernameCtrl,
                  decoration: InputDecoration(
                    labelText: 'X Username (e.g. @username)',
                    labelStyle: GoogleFonts.poppins(),
                    prefixText: '@ ',
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
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final username = usernameCtrl.text.trim().replaceAll('@', '');
                      if (username.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your X username')),
                        );
                        return;
                      }

                      final response = await UserApiService.linkSocialAccount({
                        'provider': 'x',
                        'providerUserId': username,
                        'username': username,
                        'email': '',
                        'avatar': '',
                      });

                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            response.success
                                ? 'X account linked: @$username'
                                : (response.message ?? 'Failed to link X account'),
                          ),
                        ),
                      );

                      if (response.success) {
                        Navigator.pop(sheetContext, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HexColor("#FF3B59"),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Link X Account',
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
        );
      },
    );

    usernameCtrl.dispose();

    if (result == true) {
      _loadAccounts();
    }
  }

  Future<void> _connectAccount(String provider) async {
    switch (provider) {
      case 'google':
        await _connectGoogle();
        break;
      case 'facebook':
        await _connectFacebook();
        break;
      case 'x':
        await _connectX();
        break;
    }
  }

  Future<void> _disconnectAccount({
    required String provider,
    required String title,
  }) async {
    // Sign out from provider SDK as well
    if (provider == 'google') {
      await _googleSignIn.signOut();
    } else if (provider == 'facebook') {
      await FacebookAuth.instance.logOut();
    }

    final response = await UserApiService.unlinkSocialAccount(provider);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.success
              ? '$title account disconnected'
              : (response.message ?? 'Failed to disconnect account'),
        ),
      ),
    );

    if (response.success) {
      _loadAccounts();
    }
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
                      "Add Social Accounts",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const NotificationIconButton(height: 33),
                  const SizedBox(width: 4),
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
            padding: const EdgeInsets.fromLTRB(30, 40, 30, 30),
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(60),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    children: [
                      // People icon in tinted circle
                      Container(
                        width: 77,
                        height: 77,
                        decoration: BoxDecoration(
                          color: HexColor("#1877F2").withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.groups_rounded,
                            color: HexColor("#1877F2"), size: 38),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Add Social Accounts',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connecting with your friends and family has never been easier. Simply add your social accounts to stay connected',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          height: 1.6,
                          letterSpacing: -0.35,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _socialTile(
                        label: "Google",
                        provider: "google",
                        iconPath: "assets/google_icon.png",
                        background: HexColor("#8F92A1").withOpacity(0.05),
                      ),
                      const SizedBox(height: 15),
                      _socialTile(
                        label: "Facebook",
                        provider: "facebook",
                        iconPath: "assets/facebook_icon.png",
                        background: HexColor("#1877F2").withOpacity(0.05),
                      ),
                      const SizedBox(height: 15),
                      _socialTile(
                        label: "Twitter",
                        provider: "x",
                        iconPath: "assets/twitter_icon.png",
                        background: HexColor("#03A9F4").withOpacity(0.1),
                      ),
                      const SizedBox(height: 40),
                      GestureDetector(
                        onTap: () => Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border.all(color: HexColor("#D9D9D9")),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Go to Homepage',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  color: HexColor("#1B1D21"),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(Icons.arrow_forward,
                                  color: HexColor("#1B1D21"), size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _socialTile({
    required String label,
    required String provider,
    required String iconPath,
    required Color background,
  }) {
    final isConnected = _isConnected(provider);
    final account = _account(provider);
    final linked = account['email']?.toString().trim().isNotEmpty == true
        ? account['email'].toString()
        : (account['username']?.toString().trim().isNotEmpty == true
            ? '@${account['username']}'
            : '');

    return GestureDetector(
      onTap: () => isConnected
          ? _disconnectAccount(provider: provider, title: label)
          : _connectAccount(provider),
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: isConnected
              ? Border.all(color: HexColor("#FFD546"), width: 1.2)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(child: Image.asset(iconPath, height: 16, width: 16)),
            ),
            Text(
              isConnected
                  ? (linked.isNotEmpty ? '$label · $linked' : '$label connected')
                  : 'Connect with $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: HexColor("#1B1D21"),
              ),
            ),
            if (isConnected)
              Positioned(
                right: 14,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Icon(Icons.check_circle,
                      size: 18, color: HexColor("#4FBF67")),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
