import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/household_work_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';

/// Household partner onboarding — second screen ("Address").
///
/// Fully backend-driven: the section list (current + permanent address), field
/// labels, validation and dropdown options (e.g. the state list) are fetched
/// from `/onboarding/household/address` and rendered dynamically, so the form
/// can change without an app release. Matches the Figma "Address" design (blue
/// header + 4-step indicator, ADDRESS + PERMANENT ADDRESS sections with a
/// "Same as Current Address" toggle).
class HouseholdAddressScreen extends StatefulWidget {
  const HouseholdAddressScreen({super.key});

  @override
  State<HouseholdAddressScreen> createState() => _HouseholdAddressScreenState();
}

class _HouseholdAddressScreenState extends State<HouseholdAddressScreen> {
  final OnboardingController _controller = Get.find<OnboardingController>();

  // Theme tokens lifted straight from the Figma design.
  static final Color _primary = HexColor("#2C54C1");
  static final Color _bg = HexColor("#F8FAFC");
  static final Color _border = HexColor("#E1E6EF");
  static final Color _labelColor = HexColor("#132235");
  static final Color _hintColor = HexColor("#607080");
  static final Color _mutedColor = HexColor("#94A3B3");

  bool _loading = true;
  bool _saving = false;

  String _title = "Address";
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _steps = [];
  int _currentStep = 1;

  bool _sameAsCurrent = false;

  // Per-field controllers / dropdown values keyed by "<sectionKey>.<fieldKey>".
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

  String _fieldId(String sectionKey, String fieldKey) => '$sectionKey.$fieldKey';

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    final res = await OnboardingApiService.getHouseholdAddress();
    if (!mounted) return;

    if (!res.success || res.data == null) {
      setState(() => _loading = false);
      showCustomToast(
          context, res.message ?? 'Failed to load the form. Please retry.');
      return;
    }

    final data = res.data as Map<String, dynamic>;
    final sections = (data['sections'] as List? ?? const [])
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

    for (final section in sections) {
      final sectionKey = (section['key'] ?? '').toString();
      final fields = (section['fields'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final sectionPrefill = (prefill[sectionKey] is Map)
          ? Map<String, dynamic>.from(prefill[sectionKey])
          : <String, dynamic>{};

      for (final f in fields) {
        final fieldKey = (f['key'] ?? '').toString();
        final type = (f['type'] ?? 'text').toString();
        final id = _fieldId(sectionKey, fieldKey);
        final pre = sectionPrefill[fieldKey];

        if (type == 'dropdown') {
          _dropdownValues[id] =
              (pre != null && pre.toString().isNotEmpty) ? pre.toString() : null;
        } else {
          final ctrl = TextEditingController();
          if (pre != null) ctrl.text = pre.toString();
          _textControllers[id] = ctrl;
        }
      }
    }

    setState(() {
      _title = (data['title'] ?? 'Address').toString();
      _sections = sections;
      _steps = steps;
      _currentStep = (data['currentStep'] is int) ? data['currentStep'] : 1;
      _sameAsCurrent = prefill['sameAsCurrentAddress'] == true;
      _loading = false;
    });
  }

  Map<String, dynamic> _collectSection(Map<String, dynamic> section) {
    final sectionKey = (section['key'] ?? '').toString();
    final fields = (section['fields'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final values = <String, dynamic>{};
    for (final f in fields) {
      final fieldKey = (f['key'] ?? '').toString();
      final type = (f['type'] ?? 'text').toString();
      final id = _fieldId(sectionKey, fieldKey);
      if (type == 'dropdown') {
        values[fieldKey] = _dropdownValues[id] ?? '';
      } else {
        values[fieldKey] = _textControllers[id]?.text.trim() ?? '';
      }
    }
    return values;
  }

  /// Validates a section against its `required` field config. Returns the first
  /// error message, or null when valid.
  String? _validateSection(Map<String, dynamic> section, String sectionLabel) {
    final fields = (section['fields'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final values = _collectSection(section);

    for (final f in fields) {
      if (f['required'] != true || f['readOnly'] == true) continue;
      final fieldKey = (f['key'] ?? '').toString();
      final label = (f['label'] ?? 'This field').toString();
      final val = values[fieldKey];
      if (val == null || val.toString().trim().isEmpty) {
        return '$sectionLabel: $label is required.';
      }
    }
    return null;
  }

  Map<String, dynamic>? _sectionByKey(String key) {
    for (final s in _sections) {
      if ((s['key'] ?? '').toString() == key) return s;
    }
    return null;
  }

  Future<void> _save({required bool advance}) async {
    final current = _sectionByKey('current');
    final permanent = _sectionByKey('permanent');
    if (current == null) return;

    final currentErr = _validateSection(current, 'Current Address');
    if (currentErr != null) {
      showCustomToast(context, currentErr);
      return;
    }
    if (!_sameAsCurrent && permanent != null) {
      final permanentErr = _validateSection(permanent, 'Permanent Address');
      if (permanentErr != null) {
        showCustomToast(context, permanentErr);
        return;
      }
    }

    final body = <String, dynamic>{
      'current': _collectSection(current),
      'sameAsCurrentAddress': _sameAsCurrent,
    };
    if (permanent != null && !_sameAsCurrent) {
      body['permanent'] = _collectSection(permanent);
    }

    setState(() => _saving = true);
    final res = await OnboardingApiService.saveHouseholdAddress(body: body);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!res.success) {
      showCustomToast(context, res.message ?? 'Failed to save address.');
      return;
    }

    // Keep the shared onboarding controller in sync for downstream steps.
    final cur = _collectSection(current);
    _controller.addressController.text = (cur['address'] ?? '').toString();
    _controller.apartmentController.text = (cur['apartment'] ?? '').toString();
    _controller.zipCodeController.text = (cur['zipCode'] ?? '').toString();
    _controller.selectedState.value = (cur['state'] ?? '').toString();
    _controller.selectedCity.value = (cur['city'] ?? '').toString();
    _controller.selectedCountry.value =
        (cur['country'] ?? 'India').toString();

    if (advance) {
      // Household onboarding flow: Address → Work Details → Bank Details.
      pushTo(context, const HouseholdWorkDetailsScreen());
    } else {
      showCustomToast(context, 'Address saved.');
    }
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
              onTap: _saving ? null : () => _save(advance: false),
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
    // and future steps show an empty circle — matches the Figma "Address" step.
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._sections.map(_buildSection),
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: _actionButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(Map<String, dynamic> section) {
    final sectionKey = (section['key'] ?? '').toString();
    final title = (section['title'] ?? '').toString();
    final supportsSameAsCurrent = section['supportsSameAsCurrent'] == true;
    final fields = (section['fields'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    // When "Same as Current Address" is selected the permanent fields collapse.
    final showFields = !(supportsSameAsCurrent && _sameAsCurrent);

    return Container(
      color: Colors.white,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(title),
          const SizedBox(height: 20),
          if (supportsSameAsCurrent) ...[
            _sameAsCurrentToggle(),
            const SizedBox(height: 20),
          ],
          if (showFields)
            ...fields.map((f) => _buildField(sectionKey, f)),
        ],
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

  Widget _sameAsCurrentToggle() {
    return InkWell(
      onTap: () => setState(() => _sameAsCurrent = !_sameAsCurrent),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _sameAsCurrent ? _primary : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _sameAsCurrent ? _primary : _border,
                width: 1.5,
              ),
            ),
            child: _sameAsCurrent
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            "Same as Current Address",
            style: TextStyle(color: _labelColor, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String sectionKey, Map<String, dynamic> f) {
    final type = (f['type'] ?? 'text').toString();
    final input = type == 'dropdown'
        ? _dropdownInput(sectionKey, f)
        : _textInput(sectionKey, f);

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
    final readOnly = f['readOnly'] == true;
    return RichText(
      text: TextSpan(
        text: label,
        style: TextStyle(
          // Read-only fields (e.g. Country) use the muted label like in Figma.
          color: readOnly ? _mutedColor : _labelColor,
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
      );

  Widget _textInput(String sectionKey, Map<String, dynamic> f) {
    final fieldKey = (f['key'] ?? '').toString();
    final readOnly = f['readOnly'] == true;
    final placeholder = (f['placeholder'] ?? '').toString();
    final keyboard = (f['keyboard'] ?? 'default').toString();
    final id = _fieldId(sectionKey, fieldKey);
    final ctrl = _textControllers[id] ??= TextEditingController();

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
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _dropdownInput(String sectionKey, Map<String, dynamic> f) {
    final fieldKey = (f['key'] ?? '').toString();
    final placeholder = (f['placeholder'] ?? 'Select').toString();
    final options =
        (f['options'] as List? ?? const []).map((e) => e.toString()).toList();
    final id = _fieldId(sectionKey, fieldKey);
    final selected = _dropdownValues[id];

    return InkWell(
      onTap: () =>
          _openDropdownSheet(id, f['label']?.toString() ?? '', options),
      child: Container(
        decoration: _boxDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected ?? placeholder,
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

  void _openDropdownSheet(String id, String title, List<String> options) {
    if (options.isEmpty) {
      showCustomToast(context, 'No options available.');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
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
                  final isSel = _dropdownValues[id] == opt;
                  return ListTile(
                    title: Text(opt,
                        style: TextStyle(color: _labelColor, fontSize: 15)),
                    trailing:
                        isSel ? Icon(Icons.check, color: _primary) : null,
                    onTap: () {
                      setState(() => _dropdownValues[id] = opt);
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
            onTap: _saving ? null : () => _save(advance: true),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(_saving ? "Saving..." : "Next",
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
