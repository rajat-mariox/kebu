import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/direction_details.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// "Update Booking" — lets the provider add an extra charge to an in-progress
/// booking. Persists the amount to the backend (so the customer's bill updates)
/// and returns the entered amount to the caller. Matches the Figma design.
class UpdateBookingScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  /// The extra charge currently applied (pre-fills the field).
  final double currentExtra;

  const UpdateBookingScreen({
    super.key,
    this.data = const {},
    this.currentExtra = 0,
  });

  @override
  State<UpdateBookingScreen> createState() => _UpdateBookingScreenState();
}

class _UpdateBookingScreenState extends State<UpdateBookingScreen> {
  late final DirectionData _d = DirectionData(widget.data);
  late final TextEditingController _extraCtrl =
      TextEditingController(text: widget.currentExtra > 0 ? "${widget.currentExtra}" : "");
  bool _submitting = false;

  static final Color _primary = HexColor("#2C54C1");

  @override
  void dispose() {
    _extraCtrl.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    final extra = double.tryParse(_extraCtrl.text.trim()) ?? 0;
    final id = _d.bookingId;
    if (id.isEmpty) {
      Fluttertoast.showToast(msg: "Booking not found");
      return;
    }

    setState(() => _submitting = true);
    final res = await DriverApiService.updateBookingExtraAmount(
        bookingId: id, extraAmount: extra);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (res.success) {
      Fluttertoast.showToast(msg: "Booking updated");
      Navigator.pop(context, extra); // return the applied extra to the caller
    } else {
      Fluttertoast.showToast(
          msg: res.message.isNotEmpty ? res.message : "Could not update booking");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          cleaningAppBar(
            height: 160,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 60, left: 15, right: 15),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text("Update Booking",
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 120),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 7),
                          _serviceNumberCard(),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Text("Total Amount",
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF1C1F34),
                                      fontWeight: FontWeight.w500)),
                              const Spacer(),
                              Text(_d.subtotalLabel,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF1C1F34),
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text("Extra Charges",
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF1C1F34),
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          _extraField(),
                        ],
                      ),
                    ),
                  ),
                  _bottomBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceNumberCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_d.startTimeLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.black)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: HexColor("#EBFFF5"),
                  border: Border.all(color: HexColor("#06A14E")),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text("Started",
                    style: TextStyle(
                        fontSize: 10,
                        color: HexColor("#06A14E"),
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Your service number is ${_d.bookingNumber}",
              style: const TextStyle(
                  fontSize: 13, color: Colors.black, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _extraField() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HexColor("#B1B1B1")),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      child: TextField(
        controller: _extraCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        style: const TextStyle(fontSize: 15, color: Color(0xFF1C1F34)),
        decoration: const InputDecoration(
          isDense: true,
          prefixText: "₹ ",
          hintText: "Enter extra charges",
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text("Cancel",
                      style: TextStyle(
                          color: _primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _submitting ? null : _update,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HexColor("#2F4DBC"),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Update",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
