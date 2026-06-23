import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

/// Figma "Fare Calculations" bottom sheet (node 131:10651).
///
/// Shown when the driver taps the info icon next to the amount on the
/// CollectCashScreen. Breaks the grand-total fare down into its component
/// parts: driver fee, convenience fee, GoChauffeurs Secure fee, GST,
/// rounding, and the final grand total.
///
/// The backend currently only stores a single `fare` value per booking, so
/// the breakdown is derived on the client using the same ratios visible in
/// the Figma example (Driver ≈ 74.2%, Convenience ≈ 19.3%, Secure flat ₹15,
/// GST 5% on the running subtotal). When the backend gains real
/// per-component fare fields, swap the math here for the populated values.
class FareBreakdownSheet extends StatelessWidget {
  final double total;
  const FareBreakdownSheet({super.key, required this.total});

  static Future<void> show(BuildContext context, double total) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (_) => FareBreakdownSheet(total: total),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = HexColor('#132235');
    final dark2 = HexColor('#132234');
    final divider = HexColor('#E1E6EF');

    final breakdown = _computeBreakdown(total);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Floating close button above the sheet.
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Material(
              color: dark,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.close, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
          // Sheet body
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Fare Calculations',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 25 / 20,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 36),
                _row('Driver Fee:', '+ ₹${_fmt(breakdown.driverFee)}', dark),
                const SizedBox(height: 20),
                _row('Convenience Fee:',
                    '+ ₹${_fmt(breakdown.convenienceFee)}', dark),
                const SizedBox(height: 20),
                _row('GoChauffeurs Secure Fee:',
                    '+ ₹${_fmt(breakdown.secureFee)}', dark),
                const SizedBox(height: 20),
                _row('GST:', '+ ₹${_fmt(breakdown.gst)}', dark),
                const SizedBox(height: 20),
                Container(height: 1, color: divider),
                const SizedBox(height: 20),
                _totalRow('Sub Total:', '₹${_fmt(breakdown.subTotal)}',
                    valueSize: 17, color: dark2),
                const SizedBox(height: 20),
                _row('Rounding Up:',
                    '+ ₹${_fmt(breakdown.roundingUp)}', dark),
                const SizedBox(height: 20),
                Container(height: 1, color: divider),
                const SizedBox(height: 20),
                _totalRow('Grand Total:',
                    '₹${breakdown.grandTotal.toStringAsFixed(0)}',
                    valueSize: 22, color: dark2),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 20 / 15,
              color: color,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 20 / 15,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _totalRow(String label, String value,
      {required double valueSize, required Color color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 20 / 15,
              color: color,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: valueSize,
            fontWeight: FontWeight.w700,
            height: (valueSize == 22 ? 28 : 22) / valueSize,
            color: color,
          ),
        ),
      ],
    );
  }

  static String _fmt(double v) => v.toStringAsFixed(2);

  /// Reverse-engineer a plausible breakdown from the grand total. The
  /// proportions match the Figma exemplar (₹581 → 430.8/111.94/15/22.85).
  static _Breakdown _computeBreakdown(double grandTotal) {
    if (grandTotal <= 0) {
      return _Breakdown(
        driverFee: 0,
        convenienceFee: 0,
        secureFee: 0,
        gst: 0,
        subTotal: 0,
        roundingUp: 0,
        grandTotal: 0,
      );
    }
    // Solve so that driver*1.05 + conv*1.05 + 15*1.05 ≈ subTotal where
    // driver ≈ 0.742 of (driver + conv) and conv ≈ 0.258 — derived from
    // 430.8 / (430.8 + 111.94) in the Figma example.
    final preTax = grandTotal / 1.05; // strip GST
    const secureFee = 15.0;
    final feeBase = preTax - secureFee;
    final driverFee = feeBase * 0.7937; // 430.8 / (430.8 + 111.94)
    final convenienceFee = feeBase - driverFee;
    final gst = (driverFee + convenienceFee + secureFee) * 0.05;
    final subTotal = driverFee + convenienceFee + secureFee + gst;
    final rounded = subTotal.ceilToDouble();
    final roundingUp = rounded - subTotal;
    return _Breakdown(
      driverFee: driverFee,
      convenienceFee: convenienceFee,
      secureFee: secureFee,
      gst: gst,
      subTotal: subTotal,
      roundingUp: roundingUp,
      grandTotal: rounded,
    );
  }
}

class _Breakdown {
  final double driverFee;
  final double convenienceFee;
  final double secureFee;
  final double gst;
  final double subTotal;
  final double roundingUp;
  final double grandTotal;
  _Breakdown({
    required this.driverFee,
    required this.convenienceFee,
    required this.secureFee,
    required this.gst,
    required this.subTotal,
    required this.roundingUp,
    required this.grandTotal,
  });
}
