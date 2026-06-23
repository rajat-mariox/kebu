import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/Screens/Screens/SavedAddresses/Controller/address_controller.dart';
import 'package:kebu_customer/Screens/Screens/SavedAddresses/add_address_screen.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  late final AddressController _ac;

  @override
  void initState() {
    super.initState();
    _ac = Get.put(AddressController());
  }

  Future<void> _confirmDelete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Address',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete this address?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await _ac.deleteAddress(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // App bar
          commonAppBar(
            height: 100,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 50, left: 15, right: 15),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text("My Addresses",
                      style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const Spacer(),
                ],
              ),
            ),
          ),

          // Body
          Expanded(
            child: Obx(() {
              if (_ac.isLoading.value && _ac.addresses.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_ac.addresses.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_off,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("No saved addresses",
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text("Tap + to add your first address",
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.grey.shade400)),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _ac.loadAddresses,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ac.addresses.length,
                  separatorBuilder: (_, __) => Divider(
                      color: Colors.grey.shade200, height: 1),
                  itemBuilder: (context, index) {
                    final addr = _ac.addresses[index];
                    return _addressTile(addr);
                  },
                ),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: HexColor("#FFD546"),
        onPressed: () async {
          final result =
              await pushTo(context, const AddAddressScreen());
          if (result == true) {
            _ac.loadAddresses();
          }
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _addressTile(Map<String, dynamic> addr) {
    final type = addr['addressType'] ?? 'Other';
    final id = addr['_id'] ?? '';
    final fullAddress = addr['address'] ?? '';
    final fullName = addr['fullName'] ?? '';
    final mobile = addr['mobileNumber'] ?? '';
    final isSelected = addr['isSelected'] == true;

    return InkWell(
      onTap: () async {
        final result = await pushTo(
            context, AddAddressScreen(existingAddress: addr));
        if (result == true) {
          _ac.loadAddresses();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? HexColor("#FFD546").withValues(alpha: 0.15)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _ac.getAddressTypeIcon(type),
                color: isSelected ? HexColor("#FFD546") : Colors.grey.shade600,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(type,
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: HexColor("#FFD546"),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text("Default",
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (fullName.isNotEmpty)
                    Text(fullName,
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  Text(fullAddress,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (mobile.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(mobile,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey)),
                    ),
                ],
              ),
            ),

            // Delete button
            IconButton(
              onPressed: () => _confirmDelete(id),
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade300, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
