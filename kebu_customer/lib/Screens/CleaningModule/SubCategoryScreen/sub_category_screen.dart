import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/CleaningModule/AcRepairScreen/ac_repair_screen.dart';

class SubCategoryScreen extends StatelessWidget {
  final String parentName;
  final String? parentIcon;
  final String? parentImage;
  final List<Map<String, dynamic>> subCategories;

  const SubCategoryScreen({
    super.key,
    required this.parentName,
    required this.subCategories,
    this.parentIcon,
    this.parentImage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          cleaningAppBar(
            height: 160,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 60, left: 15, right: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      margin: const EdgeInsets.only(left: 5),
                      child: const Icon(Icons.arrow_back_ios,
                          size: 20, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    parentName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const NotificationIconButton(),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 120),
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _headerIcon(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        parentName,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Choose a service to continue",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                if (subCategories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        "No services available yet",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: subCategories.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemBuilder: (context, index) {
                      final sub = subCategories[index];
                      return _SubCategoryTile(
                        sub: sub,
                        onTap: () {
                          final name = (sub['name'] ?? '').toString();
                          final id = (sub['_id'] ?? '').toString();
                          pushTo(
                            context,
                            AcRepairScreen(
                              serviceName: name,
                              categoryId: id,
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIcon() {
    final image = parentImage ?? '';
    if (image.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          image,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _emojiOrFallback(),
        ),
      );
    }
    return _emojiOrFallback();
  }

  Widget _emojiOrFallback() {
    if (parentIcon != null && parentIcon!.isNotEmpty) {
      return Text(parentIcon!, style: const TextStyle(fontSize: 32));
    }
    return Icon(Icons.home_repair_service_outlined,
        size: 32, color: HexColor('#2369CF'));
  }
}

class _SubCategoryTile extends StatelessWidget {
  final Map<String, dynamic> sub;
  final VoidCallback onTap;

  const _SubCategoryTile({required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (sub['name'] ?? '').toString();
    final image = (sub['image'] ?? '').toString();
    final icon = (sub['icon'] ?? '').toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            SizedBox(
              height: 46,
              child: image.startsWith('http')
                  ? Image.network(
                      image,
                      height: 46,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _iconFallback(icon),
                    )
                  : _iconFallback(icon),
            ),
            const SizedBox(height: 8),
            const Spacer(),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _iconFallback(String icon) {
    if (icon.isNotEmpty) {
      return Center(
        child: Text(icon, style: const TextStyle(fontSize: 32)),
      );
    }
    return Icon(Icons.home_repair_service_outlined,
        size: 36, color: Colors.grey.shade400);
  }
}
