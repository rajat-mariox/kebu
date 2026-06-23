import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/asset_icon.dart';

/// Slide-to-confirm button matching the Figma "Arrow / Chevron_Right_Duo"
/// design — a yellow track with a white chevron pill that the user drags
/// from left edge to right edge to fire `onConfirmed`.
///
/// Used in driver flows where a destructive or terminal action (At Pickup,
/// Verify Ride, Complete Ride, Accept Booking) should require deliberate
/// intent, not an accidental tap.
class SwipeButton extends StatefulWidget {
  final String label;
  final VoidCallback onConfirmed;

  /// When true, the button shows a spinner and ignores drags. The slider
  /// also snaps back to the left edge so the next tap starts fresh.
  final bool loading;

  /// Track color (default: brand yellow #FFD546).
  final Color? trackColor;

  /// Color of the draggable thumb (default: white).
  final Color? thumbColor;

  /// Color of the chevron icon inside the thumb (default: brand yellow so
  /// it reads against the white pill).
  final Color? chevronColor;

  /// Color of the label text (default: dark gray #132234).
  final Color? labelColor;

  const SwipeButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.loading = false,
    this.trackColor,
    this.thumbColor,
    this.chevronColor,
    this.labelColor,
  });

  @override
  State<SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<SwipeButton>
    with SingleTickerProviderStateMixin {
  /// Drag offset in pixels from the left edge.
  double _dragOffset = 0.0;

  /// Whether the user has fully swiped past the threshold and we've fired
  /// the callback. Prevents double-fire mid-drag.
  bool _confirmed = false;

  static const double _trackHeight = 48;
  static const double _thumbWidth = 56;
  static const double _innerInset = 2; // matches Figma's 2px inset

  @override
  void didUpdateWidget(covariant SwipeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When loading flips off (action either completed or failed), reset the
    // slider so the user can swipe again if needed.
    if (oldWidget.loading && !widget.loading) {
      setState(() {
        _dragOffset = 0;
        _confirmed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.trackColor ?? HexColor('#FFD546');
    final thumb = widget.thumbColor ?? Colors.white;
    final chevron = widget.chevronColor ?? HexColor('#FFD546');
    final labelColor = widget.labelColor ?? HexColor('#132234');

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        // The thumb can travel from left-inset to (trackWidth - thumbWidth - inset).
        final maxDrag = trackWidth - _thumbWidth - _innerInset * 2;
        final progress = maxDrag <= 0 ? 0.0 : (_dragOffset / maxDrag).clamp(0.0, 1.0);

        return SizedBox(
          height: _trackHeight,
          child: Stack(
            children: [
              // Track
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: track,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    // Fade the label as the thumb covers it.
                    opacity: (1 - progress * 1.4).clamp(0.0, 1.0),
                    child: widget.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Text(
                              widget.label,
                              style: GoogleFonts.nunito(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                height: 22 / 17,
                                color: labelColor,
                              ),
                            ),
                          ),
                  ),
                ),
              ),

              // Draggable thumb — animates back when released early.
              AnimatedPositioned(
                duration: _confirmed
                    ? const Duration(milliseconds: 120)
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                left: _innerInset + _dragOffset,
                top: _innerInset,
                bottom: _innerInset,
                width: _thumbWidth,
                child: GestureDetector(
                  onHorizontalDragUpdate: widget.loading
                      ? null
                      : (details) {
                          setState(() {
                            _dragOffset = (_dragOffset + details.delta.dx)
                                .clamp(0.0, maxDrag);
                          });
                        },
                  onHorizontalDragEnd: widget.loading
                      ? null
                      : (_) {
                          if (_dragOffset >= maxDrag * 0.9) {
                            // Snap to end and fire the callback once.
                            if (!_confirmed) {
                              _confirmed = true;
                              setState(() => _dragOffset = maxDrag);
                              widget.onConfirmed();
                            }
                          } else {
                            setState(() => _dragOffset = 0);
                          }
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      color: thumb,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    // Figma calls for inset 0 -3px 3px rgba(8,135,93,0.3),
                    // which Flutter's BoxDecoration can't render. A bottom-up
                    // gradient overlay produces the same green-glow effect.
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          HexColor('#08875D').withValues(alpha: 0.3),
                          HexColor('#08875D').withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.18],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: AssetIcon(
                      'assets/active_ride/chevron_right.svg',
                      width: 28,
                      height: 22,
                      color: chevron,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
