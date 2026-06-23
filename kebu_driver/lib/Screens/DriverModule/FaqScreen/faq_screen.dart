import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

import 'package:kebu_driver/Services/support_api_service.dart';

/// Figma "Driver - Help & Support" (131:11776) — yellow header, a "Read FAQ's"
/// accordion with yellow-bordered question cards, and a "Raise Ticket" form
/// (subject dropdown + message) wired to [SupportApiService].
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  static final _yellow = HexColor('#FFD546');
  static final _gray1 = HexColor('#132235');
  static final _label = HexColor('#3F3F3F');
  static final _navy = HexColor('#000080');
  static final _fieldBorder = HexColor('#E8E8E8');
  static final _msgBg = HexColor('#F3FAFF');

  final _messageCtrl = TextEditingController();
  String? _subject;
  bool _busy = false;

  static const _subjects = <String, String>{
    'Payment issue': 'PAYMENT',
    'Ride issue': 'RIDE',
    'Account issue': 'ACCOUNT',
    'Other': 'OTHER',
  };

  static const _faqs = <List<String>>[
    [
      'How long does it take for my account to be approved?',
      'Account verification usually takes 24–48 hours after you submit all '
          'required documents. You will be notified once your account is approved.',
    ],
    [
      'Can I reject a ride request? Will it affect my rating?',
      'Yes, you can decline a ride request. Occasional rejections will not '
          'affect your rating, but frequently declining rides may reduce your '
          'visibility to riders.',
    ],
    [
      'How do I reset my password if I forget it?',
      'Kebu One uses OTP-based login, so there is no password to reset — just '
          'sign in with your registered mobile number and the OTP sent to it.',
    ],
    [
      'What should I do if the passenger doesn’t show up?',
      'Wait at the pickup point for a few minutes and try contacting the rider. '
          'If they still do not arrive, you can cancel the trip using the '
          '“No-show” option.',
    ],
  ];

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subject == null) {
      Fluttertoast.showToast(msg: 'Please select a subject');
      return;
    }
    final message = _messageCtrl.text.trim();
    if (message.isEmpty) {
      Fluttertoast.showToast(msg: 'Please describe your issue');
      return;
    }
    setState(() => _busy = true);
    final res = await SupportApiService.createSupportTicket(
      subject: _subject!,
      description: message,
      category: _subjects[_subject!] ?? 'OTHER',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.success) {
      Fluttertoast.showToast(msg: 'Ticket raised successfully');
      Navigator.pop(context);
    } else {
      final m = res.message ?? '';
      Fluttertoast.showToast(
        msg: m.isEmpty ? 'Could not raise ticket' : m,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(15, 16, 15, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel("Read FAQ’s"),
                  const SizedBox(height: 8),
                  _faqCard(),
                  const SizedBox(height: 20),
                  _sectionLabel('Raise Ticket'),
                  const SizedBox(height: 8),
                  _raiseTicketCard(),
                  const SizedBox(height: 28),
                  _submitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── header ───────────────

  Widget _header() {
    return Container(
      color: _yellow,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 42,
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_ios, size: 18, color: _gray1),
                      const SizedBox(width: 2),
                      Text(
                        'Back',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 23 / 16,
                          color: _gray1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Help & Support',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 25 / 18,
                    color: _gray1,
                  ),
                ),
              ),
              // Right spacer to keep the title centered (matches Back width).
              const SizedBox(width: 84),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 22 / 16,
        color: _label,
      ),
    );
  }

  // ─────────────── FAQ ───────────────

  Widget _faqCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: HexColor('#FDFDFD'),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
      child: Column(
        children: [
          for (var i = 0; i < _faqs.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _faqItem(_faqs[i][0], _faqs[i][1]),
          ],
        ],
      ),
    );
  }

  Widget _faqItem(String question, String answer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _yellow),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: _gray1,
          collapsedIconColor: _gray1,
          title: Text(
            question,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 20 / 14,
              color: Colors.black,
            ),
          ),
          children: [
            Text(
              answer,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 20 / 13,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── Raise Ticket ───────────────

  Widget _raiseTicketCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _yellow),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
      child: Column(
        children: [
          // Subject dropdown
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _fieldBorder),
              borderRadius: BorderRadius.circular(5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _subject,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down, color: _navy),
                hint: Text(
                  'Subject',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: _navy,
                  ),
                ),
                style: GoogleFonts.poppins(fontSize: 14, color: _navy),
                items: _subjects.keys
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s,
                              style: GoogleFonts.poppins(
                                  fontSize: 14, color: Colors.black87)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _subject = v),
              ),
            ),
          ),
          const SizedBox(height: 3),
          // Message area
          Container(
            decoration: BoxDecoration(
              color: _msgBg,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _messageCtrl,
              maxLines: 6,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Describe your issue…',
                hintStyle:
                    GoogleFonts.poppins(fontSize: 14, color: Colors.black38),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _busy ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _yellow,
          disabledBackgroundColor: _yellow.withValues(alpha: 0.6),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
            : Text(
                'Submit',
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 22 / 17,
                  color: _gray1,
                ),
              ),
      ),
    );
  }
}
