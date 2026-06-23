import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:kebu_driver/CommonWidgets/button_widget.dart';
import 'package:kebu_driver/Screens/DriverModule/VerificationScreen/verification_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';

class ServiceCategoriesScreen extends StatefulWidget {
  const ServiceCategoriesScreen({super.key});

  @override
  State<ServiceCategoriesScreen> createState() =>
      _ServiceCategoriesScreenState();
}

class _ServiceCategoriesScreenState extends State<ServiceCategoriesScreen> {
  final OnboardingController _controller = Get.find<OnboardingController>();
  final Set<String> _expandedParents = <String>{};

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    _controller.loadingCategories.value = true;
    final res = await OnboardingApiService.getOnboardingServiceCategories();
    _controller.loadingCategories.value = false;

    if (!res.success || res.data == null) {
      if (mounted) {
        showCustomToast(
            context, res.message ?? 'Failed to load services. Please retry.');
      }
      return;
    }

    final list = (res.data['categories'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _controller.householdCategoryTree.assignAll(list);
  }

  void _toggleSelection(String id) {
    final selected = _controller.householdCategoryIds;
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
  }

  Future<void> _saveAndContinue() async {
    final selected = _controller.householdCategoryIds.toList();
    if (selected.isEmpty) {
      showCustomToast(
          context, 'Please select at least one service to continue.');
      return;
    }

    _controller.isLoading.value = true;
    final res = await OnboardingApiService.saveOnboardingServiceCategories(
      categoryIds: selected,
    );
    _controller.isLoading.value = false;

    if (!mounted) return;

    if (res.success) {
      replaceRoute(context, const VerificationScreen());
    } else {
      showCustomToast(context, res.message ?? 'Failed to save services.');
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: Container(
        height: 82,
        decoration: BoxDecoration(color: Colors.grey[100]),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Obx(() => ButtonWidget(
                    onTap: _controller.isLoading.value
                        ? null
                        : _saveAndContinue,
                    borderRadius: BorderRadius.circular(8),
                    text: _controller.isLoading.value
                        ? "Saving..."
                        : "Save & Continue",
                    textColor: HexColor("#000000"),
                    backgroundColor: HexColor("#A2BF49"),
                  )),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            commonAppBar(
              height: 110,
              context: context,
              child: Container(
                padding: const EdgeInsets.only(top: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.only(left: 16),
                        width: 40,
                        height: 35,
                        alignment: Alignment.center,
                        child: Image.asset("assets/back_arrow.png",
                            color: HexColor("#000000")),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text("Choose Services",
                        style: TextStyle(
                            color: HexColor("#000000"),
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const SizedBox(width: 15),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Select the services you can provide. Tap a category to view its sub-services.",
                style: TextStyle(
                    color: HexColor("#6E6E6E"),
                    fontSize: 13,
                    height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              if (_controller.loadingCategories.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_controller.householdCategoryTree.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.cleaning_services_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text(
                          "No services available right now",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _loadCategories,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: _controller.householdCategoryTree
                      .map((parent) => _buildParentTile(parent))
                      .toList(),
                ),
              );
            }),
            const SizedBox(height: 16),
            Obx(() {
              final count = _controller.householdCategoryIds.length;
              if (count == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: HexColor("#A2BF49").withAlpha(28),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "$count service${count == 1 ? '' : 's'} selected",
                    style: TextStyle(
                      color: HexColor("#5A7C25"),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildParentTile(Map<String, dynamic> parent) {
    final id = (parent['_id'] ?? '').toString();
    final name = (parent['name'] ?? '').toString();
    final icon = (parent['icon'] ?? '').toString();
    final image = (parent['image'] ?? '').toString();
    final description = (parent['description'] ?? '').toString();
    final subRaw = parent['subCategories'];
    final subs = (subRaw is List)
        ? subRaw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList()
        : <Map<String, dynamic>>[];

    final isExpanded = _expandedParents.contains(id);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HexColor("#E1E6EF")),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Obx(() {
            final isSelected =
                _controller.householdCategoryIds.contains(id);
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (subs.isEmpty) {
                  _toggleSelection(id);
                } else {
                  setState(() {
                    if (isExpanded) {
                      _expandedParents.remove(id);
                    } else {
                      _expandedParents.add(id);
                    }
                  });
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _avatar(image, icon, 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (subs.isEmpty)
                      _selectionDot(isSelected)
                    else
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey.shade600,
                      ),
                  ],
                ),
              ),
            );
          }),
          if (subs.isNotEmpty && isExpanded) ...[
            Container(height: 1, color: HexColor("#F0F2F5")),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: subs.map(_buildSubTile).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubTile(Map<String, dynamic> sub) {
    final id = (sub['_id'] ?? '').toString();
    final name = (sub['name'] ?? '').toString();
    final icon = (sub['icon'] ?? '').toString();
    final image = (sub['image'] ?? '').toString();
    final description = (sub['description'] ?? '').toString();

    return Obx(() {
      final isSelected = _controller.householdCategoryIds.contains(id);
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _toggleSelection(id),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? HexColor("#A2BF49").withAlpha(22)
                : HexColor("#F7F8FA"),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? HexColor("#A2BF49")
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              _avatar(image, icon, 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _selectionDot(isSelected),
            ],
          ),
        ),
      );
    });
  }

  Widget _avatar(String image, String icon, double size) {
    if (image.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          image,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _emoji(icon, size),
        ),
      );
    }
    return _emoji(icon, size);
  }

  Widget _emoji(String icon, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HexColor("#F4F6F2"),
        borderRadius: BorderRadius.circular(8),
      ),
      child: icon.isNotEmpty
          ? Text(icon, style: TextStyle(fontSize: size * 0.55))
          : Icon(Icons.cleaning_services_outlined,
              size: size * 0.55, color: Colors.grey.shade500),
    );
  }

  Widget _selectionDot(bool isSelected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isSelected ? HexColor("#A2BF49") : Colors.transparent,
        border: Border.all(
          color: isSelected ? HexColor("#A2BF49") : Colors.grey.shade400,
          width: 1.5,
        ),
        shape: BoxShape.circle,
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : null,
    );
  }
}
