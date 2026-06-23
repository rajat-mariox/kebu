import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Services/user_api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String fullName;
  final String email;
  final String profileImage;

  const EditProfileScreen({
    super.key,
    required this.fullName,
    required this.email,
    required this.profileImage,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipController = TextEditingController();
  final _stateController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  bool _saving = false;
  File? _selectedImage;
  late String _profileImageUrl;

  final Color _dark = HexColor("#1B1D21");

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.fullName;
    _emailController.text = widget.email;
    _profileImageUrl = widget.profileImage;
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _zipController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final res = await UserApiService.getProfile();
    if (res.success && res.data != null && mounted) {
      final d = res.data;
      setState(() {
        if (_nameController.text.isEmpty) {
          _nameController.text = (d['fullName'] ?? '').toString();
        }
        if (_emailController.text.isEmpty) {
          _emailController.text = (d['email'] ?? '').toString();
        }
        final cc = (d['countryCode'] ?? '+91').toString();
        final mobile = (d['mobileNumber'] ?? '').toString();
        _phoneController.text = mobile.isEmpty ? '' : '$cc $mobile';
        _addressController.text = (d['address'] ?? '').toString();
        _zipController.text = (d['pinCode'] ?? '').toString();
        _stateController.text = (d['state'] ?? '').toString();
        if (_profileImageUrl.trim().isEmpty) {
          _profileImageUrl = (d['profileImage'] ?? '').toString();
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() => _saving = true);

    final data = <String, String>{
      'fullName': name,
      'address': _addressController.text.trim(),
      'state': _stateController.text.trim(),
      'pinCode': _zipController.text.trim(),
    };
    if (email.isNotEmpty) data['email'] = email;

    final response = await UserApiService.updateProfileWithImage(
      data: data,
      profileImage: _selectedImage,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message ?? 'Failed to update profile')),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (!mounted) return;
      if (file == null) return;
      setState(() => _selectedImage = File(file.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open image picker: $e')),
      );
    }
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            // Gradient header
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
                      "Profile",
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

            Padding(
              padding: const EdgeInsets.only(top: 110),
              child: Container(
                width: MediaQuery.of(context).size.width,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(40, 28, 40, 40),
                child: Column(
                  children: [
                    _avatar(),
                    const SizedBox(height: 24),
                    _field("Full Name", _nameController),
                    const SizedBox(height: 22),
                    _field("Email Address", _emailController,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 22),
                    _field(
                      "Phone Number",
                      _phoneController,
                      readOnly: true,
                      prefix: const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Text("🇮🇳", style: TextStyle(fontSize: 18)),
                      ),
                      suffix: Icon(Icons.check, size: 18, color: _dark),
                    ),
                    const SizedBox(height: 22),
                    _field("Current Address", _addressController),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: _field("Zip Code", _zipController,
                              keyboardType: TextInputType.number),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _field(
                            "State",
                            _stateController,
                            suffix: Icon(Icons.keyboard_arrow_down,
                                size: 20, color: _dark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _saveButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- AVATAR ----------
  Widget _avatar() {
    Widget image;
    if (_selectedImage != null) {
      image = Image.file(_selectedImage!,
          width: 84, height: 84, fit: BoxFit.cover);
    } else if (_profileImageUrl.trim().isNotEmpty) {
      image = Image.network(
        _profileImageUrl.trim(),
        width: 84,
        height: 84,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset('assets/profile_image.png',
            width: 84, height: 84, fit: BoxFit.cover),
      );
    } else {
      image = Image.asset('assets/profile_image.png',
          width: 84, height: 84, fit: BoxFit.cover);
    }

    return GestureDetector(
      onTap: _saving ? null : _showImageSourceSheet,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          alignment: Alignment.center,
          children: [
            image,
            Container(width: 84, height: 84, color: Colors.black.withOpacity(0.45)),
            const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 26),
          ],
        ),
      ),
    );
  }

  // ---------- FLOATING-LABEL FIELD ----------
  Widget _field(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    TextInputType? keyboardType,
    Widget? prefix,
    Widget? suffix,
  }) {
    return SizedBox(
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _dark.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (prefix != null) prefix,
                  Expanded(
                    child: TextField(
                      controller: controller,
                      readOnly: readOnly,
                      keyboardType: keyboardType,
                      style: GoogleFonts.dmSans(
                        color: _dark,
                        fontSize: 14,
                        letterSpacing: -0.3,
                      ),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: '',
                      ),
                    ),
                  ),
                  if (suffix != null) suffix,
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 20,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  color: _dark.withOpacity(0.4),
                  fontSize: 12,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- SAVE BUTTON ----------
  Widget _saveButton() {
    return GestureDetector(
      onTap: _saving ? null : _saveProfile,
      child: Container(
        width: double.infinity,
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
        child: _saving
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                "Save Changes",
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
      ),
    );
  }
}
