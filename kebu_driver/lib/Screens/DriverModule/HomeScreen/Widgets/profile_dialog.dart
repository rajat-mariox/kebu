import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kebu_driver/CommonWidgets/asset_icon.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Profile detail card shown when the user taps the profile row on the
/// dashboard. Mirrors the Figma "Dashboard / 131:9529" overlay: yellow header
/// with the Kebu One brand block, a circular avatar straddling the header,
/// driver name + "KebuOne Partner" + id, six detail rows, and an external
/// close button beneath the card.
class ProfileDialog extends StatefulWidget {
  const ProfileDialog({super.key});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  String _fullName = '';
  String _driverId = '';
  String _mobileNumber = '';
  String _joiningDate = '';
  String _licenceNumber = '';
  String _licenceExpiry = '';
  String _emergencyContact = '';
  String _bloodGroup = '';
  String _profileImage = '';
  bool _uploading = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final res = await DriverApiService.getDashboard();
    if (!mounted) return;
    if (res.success && res.data is Map) {
      final driver = res.data['driver'] ?? {};
      setState(() {
        _fullName = (driver['fullName'] ?? '').toString();
        _driverId = (driver['_id'] ?? '').toString();
        _mobileNumber = (driver['mobileNumber'] ?? '').toString();
        _joiningDate = _formatDate(driver['createdAt']);
        _licenceNumber = (driver['licenceNumber'] ?? '').toString();
        _licenceExpiry = _formatDate(driver['licenceExpiry']);
        _emergencyContact = (driver['emergencyContact'] ?? '').toString();
        _bloodGroup = (driver['bloodGroup'] ?? '').toString();
        _profileImage = (driver['profileImage'] ?? '').toString();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(date.toString()).toLocal();
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
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '-';
    // Strip a leading +91 or 91 if already prefixed.
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10 && digits.startsWith('91')) {
      digits = digits.substring(digits.length - 10);
    }
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return '+91 $digits';
  }

  String _shortDriverId() {
    if (_driverId.isEmpty) return '#----------';
    final tail = _driverId.length > 10
        ? _driverId.substring(_driverId.length - 10)
        : _driverId;
    return '#$tail';
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
    if (!mounted) return;
    if (res.success && res.data is Map) {
      setState(() {
        _profileImage = (res.data['profileImage'] ?? _profileImage).toString();
        _uploading = false;
      });
    } else {
      setState(() => _uploading = false);
    }
  }

  // ─────────────── build ───────────────

  @override
  Widget build(BuildContext context) {
    final rows = <_ProfileRow>[
      _ProfileRow('Mobile Number', _formatPhone(_mobileNumber)),
      _ProfileRow('Joining Date', _joiningDate.isNotEmpty ? _joiningDate : '-'),
      _ProfileRow(
          'Driving License', _licenceNumber.isNotEmpty ? _licenceNumber : '-'),
      _ProfileRow('Emergency No.', _formatPhone(_emergencyContact)),
      _ProfileRow('Blood Group', _bloodGroup.isNotEmpty ? _bloodGroup : '-'),
      _ProfileRow('License Validity',
          _licenceExpiry.isNotEmpty ? _licenceExpiry : '-'),
    ];

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _yellowHeader(),
                    // Gap large enough for the avatar (which straddles the
                    // header) so the name never overlaps the picture.
                    const SizedBox(height: 84),
                    if (_loading) const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            _fullName.isNotEmpty ? _fullName : 'Driver',
                            style: GoogleFonts.nunito(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 25 / 20,
                              color: HexColor('#132235'),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'KebuOne Partner',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 20 / 15,
                              color: HexColor('#364B63'),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _shortDriverId(),
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 20 / 15,
                              color: HexColor('#364B63'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        children: [
                          for (var i = 0; i < rows.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            _detailRow(rows[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                // Avatar straddles header/body
                Positioned(
                  top: 115,
                  left: 0,
                  right: 0,
                  child: Center(child: _avatar()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // External close button
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(99),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HexColor('#132235'),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 26),
            ),
          ),
        ],
        ),
      ),
    );
  }

  // ─────────────── pieces ───────────────

  Widget _yellowHeader() {
    return Container(
      height: 181,
      width: double.infinity,
      color: HexColor('#FFD546'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      alignment: Alignment.topLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo tile (uses the Figma asset; Kebu One brand block)
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: const AssetIcon(
              'assets/dashboard/profile_card_icon_tight.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kebu One',
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 32 / 28,
                    color: HexColor('#132235'),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All Services in One App',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 16 / 12,
                    color: HexColor('#132235'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    Widget inner;
    if (_profileImage.isNotEmpty) {
      inner = Image.network(
        _profileImage,
        width: 124,
        height: 124,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/profile_pic.png',
          width: 124,
          height: 124,
          fit: BoxFit.cover,
        ),
      );
    } else {
      inner = Image.asset(
        'assets/profile_pic.png',
        width: 124,
        height: 124,
        fit: BoxFit.cover,
      );
    }

    return GestureDetector(
      onTap: _pickAndUploadImage,
      child: Container(
        width: 132,
        height: 132,
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(child: inner),
            if (_uploading)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
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
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: HexColor('#FFD546'),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 14, color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(_ProfileRow row) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 126,
          child: Text(
            row.label,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 20 / 15,
              color: HexColor('#607080'),
            ),
          ),
        ),
        Text(
          ':',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 16 / 12,
            color: HexColor('#607080'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            row.value,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 20 / 15,
              color: HexColor('#132235'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileRow {
  final String label;
  final String value;
  const _ProfileRow(this.label, this.value);
}
