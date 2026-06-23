import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/Utils/ApiClient/api_client.dart';

class WishToWorkDialog extends StatefulWidget {
  const WishToWorkDialog({super.key});

  @override
  State<WishToWorkDialog> createState() => _WishToWorkDialogState();
}

class _WishToWorkDialogState extends State<WishToWorkDialog> {
  int selectedIndex = -1;
  bool _saving = false;

  static final _gray1 = HexColor('#132235');
  static final _border = HexColor('#E9F0F7');
  static final _yellow = HexColor('#FFD546');
  static final _radioBorder = HexColor('#D3DDE7');

  final List<String> options = [
    '3-4 Hours',
    '4-5 Hours',
    '5-6 Hours',
    '6-7 Hours',
    '7-8 Hours',
    'More than 8 hours',
  ];

  Future<void> _saveWorkHours() async {
    if (selectedIndex < 0) return;
    setState(() => _saving = true);

    await ApiClient.put('/driver/app/work-hours', body: {
      'preferredWorkHours': options[selectedIndex],
    });

    if (!mounted) return;
    Navigator.pop(context, options[selectedIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ─────────── Card ───────────
            Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Text(
                      '“ How many hours do you wish to work? ”',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 25 / 20,
                        color: _gray1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please select hours',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 20 / 15,
                        color: _gray1,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Hour options
                    ...List.generate(options.length, (index) {
                      final selected = selectedIndex == index;
                      final isLast = index == options.length - 1;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => selectedIndex = index),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.only(
                            top: index == 0 ? 4 : 16,
                            bottom: 16,
                          ),
                          decoration: BoxDecoration(
                            border: isLast
                                ? null
                                : Border(bottom: BorderSide(color: _border)),
                          ),
                          child: Row(
                            children: [
                              _radio(selected),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  options[index],
                                  style: GoogleFonts.nunito(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 20 / 15,
                                    color: _gray1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    // Proceed button
                    GestureDetector(
                      onTap: _saving ? null : _saveWorkHours,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 13, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _yellow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: _saving
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(_gray1),
                                  ),
                                )
                              : Text(
                                  'Proceed',
                                  style: GoogleFonts.nunito(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    height: 22 / 17,
                                    color: _gray1,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // ─────────── Close button ───────────
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gray1,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 26),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _radio(bool selected) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _yellow : Colors.white,
        border: Border.all(
          color: selected ? _yellow : _radioBorder,
          width: selected ? 0 : 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}
