import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Warms up the native Google Maps SDK once per app session.
///
/// The *first* `GoogleMap` a Flutter app shows pays a heavy one-time native
/// cost — loading the Maps SDK, classes and GL rendering pipeline — which is
/// why the very first map (e.g. the "Book a cab" screen) shows blank/gray
/// tiles for a second or two before it renders. By briefly creating a tiny,
/// off-screen, invisible map while the user is sitting on the idle home
/// screen, that init happens up front, so the real maps render immediately
/// when opened.
///
/// The SDK init is process-global and stays warm for the rest of the session,
/// so the warm-up map is torn down again after a few seconds to free its
/// memory.
class MapWarmup {
  MapWarmup._();

  static bool _done = false;

  /// Insert the off-screen warm-up map once. Safe to call repeatedly — it
  /// no-ops after the first call. Call from a screen's `initState` (after the
  /// first frame, so an [Overlay] is available).
  static void ensure(BuildContext context) {
    if (_done) return;
    _done = true;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      // No overlay yet — allow a later call to retry.
      _done = false;
      return;
    }

    final entry = OverlayEntry(
      builder: (_) => const Positioned(
        // Off the visible area and 1×1 so it never shows or intercepts touches.
        left: -100,
        top: -100,
        width: 1,
        height: 1,
        child: IgnorePointer(child: _WarmupMap()),
      ),
    );
    overlay.insert(entry);

    // The native SDK is warm within a couple of seconds; remove the throwaway
    // map afterwards. The process-level init persists for later maps.
    Future.delayed(const Duration(seconds: 8), entry.remove);
  }
}

class _WarmupMap extends StatelessWidget {
  const _WarmupMap();

  @override
  Widget build(BuildContext context) {
    return const GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(20.5937, 78.9629),
        zoom: 1,
      ),
      liteModeEnabled: false,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}
