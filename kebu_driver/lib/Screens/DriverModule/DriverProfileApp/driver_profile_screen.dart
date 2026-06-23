import 'dart:io';
import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});
  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  static const Color subtitleGray = Color(0xFF8C9098);

  String _fullName = '';
  String _mobileNumber = '';
  String _profileImage = '';
  String _joiningDate = '';
  String _licenceNumber = '';
  String _licenceExpiry = '';
  int _totalRides = 0;
  double _totalEarnings = 0;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final res = await DriverApiService.getDashboard();
    if (res.success && res.data != null && mounted) {
      final driver = res.data['driver'] ?? {};
      final weekly = res.data['weekly'] ?? {};
      setState(() {
        _fullName = driver['fullName'] ?? '';
        _mobileNumber = driver['mobileNumber'] ?? '';
        _profileImage = driver['profileImage'] ?? '';
        _joiningDate = _formatDate(driver['createdAt']);
        _licenceNumber = driver['licenceNumber'] ?? '';
        _licenceExpiry = _formatDate(driver['licenceExpiry']);
        _totalRides = driver['totalRides'] ?? 0;
        _totalEarnings = (weekly['totalEarnings'] ?? 0).toDouble();
      });
    }
  }

  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return '-';
    try {
      final dt = DateTime.parse(date.toString());
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return date.toString();
    }
  }

  String _formatPhone(String phone) {
    if (phone.isEmpty) return '-';
    if (phone.length == 10) {
      return '+91 ${phone.substring(0, 5)} ${phone.substring(5)}';
    }
    return '+91 $phone';
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploading = true);

    final res = await DriverApiService.uploadProfileImage(File(picked.path));

    if (res.success && res.data != null && mounted) {
      setState(() {
        _profileImage = res.data['profileImage'] ?? '';
        _uploading = false;
      });
    } else {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                      onTap: () {
                        Navigator.pop(context);
                      },
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
                      "Profile",
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

            const SizedBox(height: 20),

            // PROFILE AVATAR with camera icon
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: _profileImage.isNotEmpty
                        ? Image.network(
                            _profileImage,
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(
                                "assets/driver_image.png",
                                height: 100,
                                width: 100),
                          )
                        : Image.asset("assets/driver_image.png",
                            height: 100, width: 100),
                  ),
                  if (_uploading)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black38,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!_uploading)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: HexColor("#FFD546"),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 16, color: Colors.black),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // NAME
            Text(
              _fullName.isNotEmpty ? _fullName : 'Driver',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 6),

            // Driving since
            Text(
              'Driving Since $_joiningDate',
              style: const TextStyle(
                  fontSize: 12,
                  color: subtitleGray,
                  fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 4),

            // Phone number
            Text(
              _formatPhone(_mobileNumber),
              style: const TextStyle(
                  fontSize: 12,
                  color: subtitleGray,
                  fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 12),

            // Language chips
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DashedChip(label: 'Hindi'),
                SizedBox(width: 10),
                DashedChip(label: 'English'),
                SizedBox(width: 10),
                DashedChip(label: 'Telugu'),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              height: 12,
              width: MediaQuery.of(context).size.width,
              color: HexColor("#D3DDE7").withOpacity(0.40),
            ),

            const SizedBox(height: 12),

            // Earning & Rides header
            _sectionHeader('Earning & Rides', 'Last year'),

            // Earning card
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 7, horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '₹${_totalEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 25, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MiniInfo(
                          title: 'Total Trips', value: '$_totalRides'),
                      const SizedBox(width: 10),
                      const _MiniInfo(
                          title: 'Total Driving Hrs', value: '-'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 7),

            Container(
              height: 12,
              width: MediaQuery.of(context).size.width,
              color: HexColor("#D3DDE7").withOpacity(0.40),
            ),

            const SizedBox(height: 12),

            // Badges
            _sectionHeader('Badges', 'Last year'),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(width: 20),
                BadgeCard(
                    icon: "assets/lock.png",
                    text: 'Silver\nUnlocked',
                    isLock: true),
                SizedBox(width: 10),
                BadgeCard(
                    icon: "assets/Madel.png",
                    text: 'Silver\nUnlocked',
                    isLock: false),
                SizedBox(width: 20),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              margin: const EdgeInsets.only(left: 15, right: 15),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Driving License',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        LicenseRow(
                            label: 'DL Number',
                            value:
                                ':  ${_licenceNumber.isNotEmpty ? _licenceNumber : '-'}'),
                        LicenseRow(
                            label: 'DL Expiry Date',
                            value: ':  $_licenceExpiry'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(width: 25),
        Text(title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700)),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: HexColor("#E1E6EF"), width: 1)),
          child: Row(
            children: [
              Text(
                trailing,
                style: const TextStyle(
                    fontSize: 13, color: subtitleGray),
              ),
            ],
          ),
        ),
        const SizedBox(width: 25),
      ],
    );
  }
}

class DashedChip extends StatelessWidget {
  final String label;
  const DashedChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: HexColor("#F8FAFC"),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(label,
          style:
              const TextStyle(color: Color(0xFF4B5563), fontSize: 11)),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String title;
  final String value;
  const _MiniInfo({required this.title, required this.value});

  static const Color subtitleGray = Color(0xFF8C9098);
  static const Color greenText = Color(0xFF1FA862);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        decoration: BoxDecoration(
          border: Border.all(color: HexColor("#E1E6EF"), width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(
                    color: subtitleGray, fontSize: 13)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: greenText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class BadgeCard extends StatelessWidget {
  final String icon;
  final String text;
  final bool isLock;
  const BadgeCard(
      {super.key,
      required this.icon,
      required this.text,
      required this.isLock});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: HexColor("#F8FAFC"),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3EDF8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 10),
            Image.asset(icon, height: isLock ? 40 : 80),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                textAlign: TextAlign.center,
                text,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.05,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class LicenseRow extends StatelessWidget {
  final String label;
  final String value;
  const LicenseRow(
      {super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                  color: Color(0xFF636B74),
                  fontWeight: FontWeight.w400,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
