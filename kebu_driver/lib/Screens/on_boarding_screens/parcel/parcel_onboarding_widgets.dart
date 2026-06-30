import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

/// Shared visual language for the Parcel Delivery onboarding flow.
///
/// These widgets implement the pink Figma redesign
/// (Figma "Personal Info" / node 159:16541) and are reused across every
/// parcel onboarding step so the screens stay consistent and DRY.
class ParcelColors {
  static final Color primary = HexColor("#F32054");
  static final Color background = HexColor("#F8FAFC");
  static final Color border = HexColor("#E1E6EF");
  static final Color labelDark = HexColor("#132235");
  static final Color hint = HexColor("#607080");
  static final Color asterisk = HexColor("#E02D3C");
  static final Color stepLabel = HexColor("#848484");
}

/// The five steps shown in the Figma stepper, in order.
const List<String> kParcelSteps = [
  'Basic Details',
  'DL Details',
  'Documents',
  'Address',
  'Bank',
];

/// Pink header bar matching the Figma "Profile" app bar.
/// [title] is the header text, [onSave] (optional) wires the right-aligned
/// "Save" action — hidden when null.
PreferredSizeWidget parcelHeader({
  required BuildContext context,
  required String title,
  VoidCallback? onSave,
}) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(64),
    child: Container(
      color: ParcelColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 25 / 20,
                    color: Colors.white,
                  ),
                ),
              ),
              if (onSave != null)
                InkWell(
                  onTap: onSave,
                  child: Text(
                    'Save',
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Horizontal 5-step progress indicator (Basic Details … Bank).
/// [currentStep] is the zero-based index of the active step.
class ParcelStepper extends StatelessWidget {
  final int currentStep;
  const ParcelStepper({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ParcelColors.background,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      // Each step is an equal-width column so the dot and its label share the
      // same horizontal centre. The connector lines fill the space between
      // adjacent dots (right half of one cell + left half of the next).
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(kParcelSteps.length, (i) {
          final isActive = i == currentStep;
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: i == 0
                          ? const SizedBox.shrink()
                          : Container(height: 1, color: ParcelColors.border),
                    ),
                    _dot(i),
                    Expanded(
                      child: i == kParcelSteps.length - 1
                          ? const SizedBox.shrink()
                          : Container(height: 1, color: ParcelColors.border),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  kParcelSteps[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    height: 1.4,
                    color: isActive
                        ? ParcelColors.primary
                        : ParcelColors.stepLabel,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _dot(int stepIndex) {
    final bool isDone = stepIndex < currentStep;
    final bool isActive = stepIndex == currentStep;
    final Color ring = (isDone || isActive)
        ? ParcelColors.primary
        : ParcelColors.border;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: ring, width: 1.5),
      ),
      child: Center(
        child: isDone
            ? Icon(Icons.check, size: 12, color: ParcelColors.primary)
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? ParcelColors.primary
                      : ParcelColors.stepLabel,
                ),
              ),
      ),
    );
  }
}

/// Centered section divider e.g. "BASIC DETAILS".
Widget parcelSectionDivider(String title) {
  return Row(
    children: [
      Expanded(child: Container(height: 1, color: ParcelColors.border)),
      const SizedBox(width: 16),
      Text(
        title.toUpperCase(),
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: ParcelColors.hint,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(child: Container(height: 1, color: ParcelColors.border)),
    ],
  );
}

/// Bold field label with optional red asterisk, matching Figma input labels.
Widget parcelFieldLabel(String label, {bool required = true}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      text: TextSpan(
        text: label,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 16 / 12,
          color: ParcelColors.labelDark,
        ),
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: ParcelColors.asterisk),
            ),
        ],
      ),
    ),
  );
}

/// Rounded text input matching the Figma "Material Inputs" component.
Widget parcelInput({
  required TextEditingController controller,
  required String label,
  required String hint,
  bool required = true,
  Widget? suffixIcon,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  bool readOnly = false,
  VoidCallback? onTap,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      parcelFieldLabel(label, required: required),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ParcelColors.border),
        ),
        child: TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: GoogleFonts.nunito(
            fontSize: 15,
            color: ParcelColors.labelDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(
              fontSize: 15,
              color: ParcelColors.hint,
            ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            suffixIcon: suffixIcon,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 44, minHeight: 24),
          ),
        ),
      ),
    ],
  );
}

/// Read-only "selector" box (dropdown-style) used for state/city/bank pickers.
Widget parcelSelector({
  required String label,
  required String value,
  required String placeholder,
  required VoidCallback onTap,
  bool required = true,
}) {
  final bool hasValue = value.isNotEmpty;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      parcelFieldLabel(label, required: required),
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ParcelColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue ? value : placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color:
                        hasValue ? ParcelColors.labelDark : ParcelColors.hint,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down, color: ParcelColors.hint),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Labeled image-upload box. Shows the picked [file] preview when present,
/// otherwise a dashed "Tap to upload" placeholder. Wrap in an Obx in the
/// caller so it rebuilds when the file changes.
Widget parcelUploadBox({
  required String label,
  required File? file,
  required VoidCallback onTap,
  bool required = true,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      parcelFieldLabel(label, required: required),
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: file != null ? ParcelColors.primary : ParcelColors.border,
              width: file != null ? 1.5 : 1,
            ),
          ),
          child: file != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(file, fit: BoxFit.cover),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_circle,
                              size: 20, color: ParcelColors.primary),
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          size: 30, color: ParcelColors.hint),
                      const SizedBox(height: 6),
                      Text("Tap to upload",
                          style: GoogleFonts.nunito(
                              fontSize: 12, color: ParcelColors.hint)),
                    ],
                  ),
                ),
        ),
      ),
    ],
  );
}

/// Bottom Back / Next button bar matching the Figma footer.
/// [nextLabel] defaults to "Next"; [onNext] is disabled when null (loading).
class ParcelBottomBar extends StatelessWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final String nextLabel;
  const ParcelBottomBar({
    super.key,
    required this.onNext,
    this.onBack,
    this.nextLabel = 'Next',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ParcelColors.background,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: _button(
              label: 'Back',
              filled: false,
              onTap: onBack ?? () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _button(
              label: nextLabel,
              filled: true,
              onTap: onNext,
            ),
          ),
        ],
      ),
    );
  }

  Widget _button({
    required String label,
    required bool filled,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? ParcelColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: ParcelColors.primary),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 2),
              blurRadius: 3,
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : ParcelColors.primary,
          ),
        ),
      ),
    );
  }
}
