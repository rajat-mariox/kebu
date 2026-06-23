import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});
  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  List<dynamic> faqs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFaqs();
  }

  Future<void> _loadFaqs() async {
    final response = await CustomerFeaturesApiService.getFAQs();
    if (response.success && response.data != null && mounted) {
      setState(() {
        faqs = response.data['faqs'] ?? [];
        isLoading = false;
      });
    } else if (mounted) {
      setState(() => isLoading = false);
    }
  }

  /// Group FAQs by category, preserving first-seen order.
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final f in faqs) {
      if (f is! Map) continue;
      final m = Map<String, dynamic>.from(f);
      final cat = (m['category'] ?? 'General').toString().trim().isEmpty
          ? 'General'
          : (m['category']).toString();
      map.putIfAbsent(cat, () => []).add(m);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;

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
                    Expanded(
                      child: Text(
                        "FAQs",
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
              padding: const EdgeInsets.fromLTRB(30, 30, 30, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FAQ',
                    style: GoogleFonts.dmSans(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.4,
                      color: HexColor("#040415"),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Find important information and update about any recent changes and fees here.',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      height: 1.6,
                      letterSpacing: -0.35,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(height: 1, color: HexColor("#1B1D21").withOpacity(0.1)),
                  const SizedBox(height: 16),

                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (faqs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text("No FAQs available",
                            style: GoogleFonts.dmSans(color: Colors.grey)),
                      ),
                    )
                  else
                    ...grouped.entries.map((entry) => _category(entry.key, entry.value)),

                  const SizedBox(height: 20),

                  // Go to Homepage
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
                            "Go to Homepage",
                            style: GoogleFonts.dmSans(
                              color: HexColor("#1B1D21"),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.arrow_forward,
                              size: 16, color: HexColor("#1B1D21")),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _category(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.35,
              color: HexColor("#040415"),
            ),
          ),
        ),
        ...items.map((f) => FAQItem(
              question: (f['question'] ?? '').toString(),
              answer: (f['answer'] ?? '').toString(),
            )),
        const SizedBox(height: 14),
      ],
    );
  }
}

class FAQItem extends StatefulWidget {
  final String question;
  final String answer;
  final bool initiallyExpanded;

  const FAQItem({
    super.key,
    required this.question,
    required this.answer,
    this.initiallyExpanded = false,
  });

  @override
  State<FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<FAQItem> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.35,
                      color: HexColor("#1B1D21"),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down,
                      size: 24, color: HexColor("#1B1D21")),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              widget.answer,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                height: 1.85,
                letterSpacing: -0.3,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        Divider(height: 1, color: HexColor("#1B1D21").withOpacity(0.08)),
      ],
    );
  }
}
