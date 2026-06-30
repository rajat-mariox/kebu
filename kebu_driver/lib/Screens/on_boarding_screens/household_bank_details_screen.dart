import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/DriverModule/VerificationScreen/verification_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';

/// Household partner onboarding — final screen ("Bank Details").
///
/// Fully backend-driven: the field list, labels, validation and the bank
/// dropdown options are fetched from `/onboarding/household/bank-details` and
/// rendered dynamically. Saving submits the whole application for admin review
/// (the driver moves to `under_verification`). Matches the Figma "Bank Details"
/// design (blue header + 4-step indicator, ACCOUNT DETAILS section).
class HouseholdBankDetailsScreen extends StatefulWidget {
  const HouseholdBankDetailsScreen({super.key});

  @override
  State<HouseholdBankDetailsScreen> createState() =>
      _HouseholdBankDetailsScreenState();
}

class _HouseholdBankDetailsScreenState
    extends State<HouseholdBankDetailsScreen> {
  // Theme tokens lifted straight from the Figma design.
  static final Color _primary = HexColor("#2C54C1");
  static final Color _bg = HexColor("#F8FAFC");
  static final Color _border = HexColor("#E1E6EF");
  static final Color _labelColor = HexColor("#132235");
  static final Color _hintColor = HexColor("#607080");

  bool _loading = true;
  bool _saving = false;

  String _title = "Bank Details";
  List<Map<String, dynamic>> _fields = [];
  List<Map<String, dynamic>> _steps = [];
  int _currentStep = 3;

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String?> _dropdownValues = {};

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    final res = await OnboardingApiService.getHouseholdBankDetails();
    if (!mounted) return;

    if (!res.success || res.data == null) {
      setState(() => _loading = false);
      showCustomToast(
          context, res.message ?? 'Failed to load the form. Please retry.');
      return;
    }

    final data = res.data as Map<String, dynamic>;
    final fields = (data['fields'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final steps = (data['steps'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final prefill = (data['prefill'] is Map)
        ? Map<String, dynamic>.from(data['prefill'])
        : <String, dynamic>{};

    for (final f in fields) {
      final key = (f['key'] ?? '').toString();
      final type = (f['type'] ?? 'text').toString();
      final pre = prefill[key];

      if (type == 'dropdown') {
        _dropdownValues[key] =
            (pre != null && pre.toString().isNotEmpty) ? pre.toString() : null;
      } else {
        final ctrl = TextEditingController();
        if (pre != null) ctrl.text = pre.toString();
        _textControllers[key] = ctrl;
      }
    }

    setState(() {
      _title = (data['title'] ?? 'Bank Details').toString();
      _fields = fields;
      _steps = steps;
      _currentStep = (data['currentStep'] is int) ? data['currentStep'] : 3;
      _loading = false;
    });
  }

  Map<String, dynamic> _collectBody() {
    final body = <String, dynamic>{};
    for (final f in _fields) {
      final key = (f['key'] ?? '').toString();
      final type = (f['type'] ?? 'text').toString();
      if (key.isEmpty || f['readOnly'] == true) continue;
      if (type == 'dropdown') {
        body[key] = _dropdownValues[key] ?? '';
      } else {
        body[key] = _textControllers[key]?.text.trim() ?? '';
      }
    }
    return body;
  }

  String? _validate(Map<String, dynamic> body) {
    for (final f in _fields) {
      if (f['required'] != true || f['readOnly'] == true) continue;
      final key = (f['key'] ?? '').toString();
      final label = (f['label'] ?? 'This field').toString();
      final val = body[key];
      if (val == null || val.toString().trim().isEmpty) {
        return '$label is required.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final body = _collectBody();
    final err = _validate(body);
    if (err != null) {
      showCustomToast(context, err);
      return;
    }

    setState(() => _saving = true);
    final res = await OnboardingApiService.saveHouseholdBankDetails(body: body);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!res.success) {
      showCustomToast(context, res.message ?? 'Failed to save bank details.');
      return;
    }

    // Final step submitted — onboarding complete. Send the partner to the
    // verification screen, which waits for admin approval (polls status on
    // entry / app-resume and moves them to the dashboard once approved). The
    // whole onboarding stack is cleared so they can't navigate back into it.
    showCustomToast(
        context, 'Application submitted! Your details are under review.');
    replaceRoute(context, const VerificationScreen());
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _header(),
          if (_steps.isNotEmpty) _stepper(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _form(),
          ),
        ],
      ),
    );
  }

  // ── Header (blue app bar) ──
  Widget _header() {
    return Container(
      color: _primary,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                _title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            InkWell(
              onTap: _saving ? null : _save,
              child: const Text(
                "Save",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4-step progress indicator ──
  Widget _stepper() {
    final nodes = <Widget>[];
    for (var i = 0; i < _steps.length; i++) {
      nodes.add(_stepNode(i));
      if (i != _steps.length - 1) {
        nodes.add(Expanded(child: Container(height: 1, color: _border)));
      }
    }

    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(children: nodes),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_steps.length, (i) {
              final label = (_steps[i]['label'] ?? '').toString();
              final isCurrent = i == _currentStep;
              final text = Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isCurrent ? _labelColor : HexColor("#848484"),
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                ),
              );
              if (i == 0) return text;
              if (i == _steps.length - 1) return text;
              return Expanded(child: Center(child: text));
            }),
          ),
        ],
      ),
    );
  }

  Widget _stepNode(int index) {
    // Completed steps (before the current one) show a blue check; the current
    // step (Bank Details) shows an empty circle — matches the Figma design
    // (Personal Details + Address + Work Details all checked).
    final done = index < _currentStep;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? _primary : Colors.white,
        border: Border.all(
          color: done ? _primary : HexColor("#848484"),
          width: 1.5,
        ),
      ),
      child: done
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HexColor("#848484"),
                ),
              ),
            ),
    );
  }

  // ── Form body ──
  Widget _form() {
    return SingleChildScrollView(
      child: Container(
        color: Colors.white,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("ACCOUNT DETAILS"),
            const SizedBox(height: 20),
            ..._fields.map(_buildField),
            const SizedBox(height: 8),
            _actionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _border)),
        const SizedBox(width: 16),
        Text(
          title,
          style: TextStyle(
            color: _hintColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Container(height: 1, color: _border)),
      ],
    );
  }

  Widget _buildField(Map<String, dynamic> f) {
    final type = (f['type'] ?? 'text').toString();
    final input = type == 'dropdown' ? _dropdownInput(f) : _textInput(f);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(f),
          const SizedBox(height: 4),
          input,
        ],
      ),
    );
  }

  Widget _fieldLabel(Map<String, dynamic> f) {
    final label = (f['label'] ?? '').toString();
    final required = f['required'] == true;
    return RichText(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: _labelColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFE02D3C)),
            ),
        ],
      ),
    );
  }

  BoxDecoration get _boxDecoration => BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
        // Figma: drop-shadow 0px 2px 1px rgba(0,0,0,0.03)
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            offset: Offset(0, 2),
            blurRadius: 1,
          ),
        ],
      );

  Widget _textInput(Map<String, dynamic> f) {
    final key = (f['key'] ?? '').toString();
    final readOnly = f['readOnly'] == true;
    final placeholder = (f['placeholder'] ?? '').toString();
    final keyboard = (f['keyboard'] ?? 'default').toString();
    final ctrl = _textControllers[key] ??= TextEditingController();

    return Container(
      decoration: _boxDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextFormField(
        controller: ctrl,
        readOnly: readOnly,
        keyboardType: _keyboardType(keyboard),
        style: TextStyle(
          color: readOnly ? _hintColor : _labelColor,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          hintText: placeholder,
          hintStyle: TextStyle(color: _hintColor, fontSize: 15),
          border: InputBorder.none,
        ),
      ),
    );
  }

  TextInputType _keyboardType(String keyboard) {
    switch (keyboard) {
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      case 'number':
        return TextInputType.number;
      default:
        return TextInputType.text;
    }
  }

  Widget _dropdownInput(Map<String, dynamic> f) {
    final key = (f['key'] ?? '').toString();
    final placeholder = (f['placeholder'] ?? 'Select').toString();
    final options =
        (f['options'] as List? ?? const []).map((e) => e.toString()).toList();
    final selected = _dropdownValues[key];

    return InkWell(
      onTap: () => _openDropdownSheet(key, f['label']?.toString() ?? '', options),
      child: Container(
        decoration: _boxDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected ?? placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected == null ? _hintColor : _labelColor,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: _labelColor, size: 22),
          ],
        ),
      ),
    );
  }

  void _openDropdownSheet(String key, String title, List<String> options) {
    if (options.isEmpty) {
      showCustomToast(context, 'No options available.');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(title,
                  style: TextStyle(
                      color: _labelColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: options.map((opt) {
                    final isSel = _dropdownValues[key] == opt;
                    return ListTile(
                      title: Text(opt,
                          style: TextStyle(color: _labelColor, fontSize: 15)),
                      trailing:
                          isSel ? Icon(Icons.check, color: _primary) : null,
                      onTap: () {
                        setState(() => _dropdownValues[key] = opt);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _primary),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text("Back",
                  style: TextStyle(
                      color: _primary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: _saving ? null : _save,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(_saving ? "Saving..." : "Save",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }
}
