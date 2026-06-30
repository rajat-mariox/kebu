import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

/// Drives a [SlideToConfirm] programmatically — call [slide] to animate the
/// handle to the end and run its `onConfirmed` (e.g. auto-confirm once an OTP
/// is fully entered). Manual dragging keeps working alongside this.
class SlideToConfirmController extends ChangeNotifier {
  VoidCallback? _onSlide;

  void _attach(VoidCallback cb) => _onSlide = cb;
  void _detach(VoidCallback cb) {
    if (_onSlide == cb) _onSlide = null;
  }

  /// Auto-slide the handle to the end and trigger confirmation.
  void slide() => _onSlide?.call();
}

/// A slide-to-confirm button matching the Figma slider control used across the
/// cleaning flow ("Verify and mark arrived", "Start the service", …): a track
/// with a white chevron handle the user drags to the right edge to confirm.
///
/// While `onConfirmed` runs the handle shows a spinner; if it resolves false
/// (e.g. wrong OTP, missing photos) the handle springs back to the start. On
/// true the parent is expected to navigate away, so the handle stays at the end.
///
/// Pass a [controller] and call `controller.slide()` to confirm automatically
/// (without a drag) — used to auto-verify the moment the OTP is complete.
class SlideToConfirm extends StatefulWidget {
  /// Centre label, shown until the handle slides over it.
  final String label;

  /// Fired when the handle reaches the end. Return true to keep it there
  /// (success), false to spring it back.
  final Future<bool> Function() onConfirmed;

  /// Optional controller to trigger the slide programmatically.
  final SlideToConfirmController? controller;

  /// Track (background) colour. Defaults to the brand blue.
  final Color? trackColor;

  /// Label colour. Defaults to white.
  final Color? textColor;

  /// Colour of the chevron inside the white handle. Defaults to [trackColor].
  final Color? handleIconColor;

  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.controller,
    this.trackColor,
    this.textColor,
    this.handleIconColor,
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  static const double _trackHeight = 48;
  static const double _handleWidth = 56;
  static const double _inset = 2;

  double _dragX = 0;
  bool _busy = false;
  double _maxX = 0; // latest laid-out travel distance (set during build)

  // Single controller animating [_dragX] between [_animFrom] and [_animTo],
  // used both for the spring-back and the programmatic auto-slide.
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(() {
      setState(() => _dragX = _animFrom + (_animTo - _animFrom) * _anim.value);
    });
  double _animFrom = 0;
  double _animTo = 0;

  Color get _track => widget.trackColor ?? HexColor("#2C54C1");
  Color get _handleIcon => widget.handleIconColor ?? _track;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(_autoSlide);
  }

  @override
  void didUpdateWidget(SlideToConfirm old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._detach(_autoSlide);
      widget.controller?._attach(_autoSlide);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(_autoSlide);
    _anim.dispose();
    super.dispose();
  }

  void _animateTo(double target, Duration duration) {
    _animFrom = _dragX;
    _animTo = target;
    _anim.duration = duration;
    _anim.forward(from: 0);
  }

  void _springBack() => _animateTo(0, const Duration(milliseconds: 220));

  /// Animate the handle all the way across, then confirm. Triggered by the
  /// controller (e.g. OTP completed) — a no-op while busy/animating.
  Future<void> _autoSlide() async {
    if (_busy || _anim.isAnimating || _maxX <= 0) return;
    _animateTo(_maxX, const Duration(milliseconds: 350));
    await _anim.forward();
    if (!mounted) return;
    await _complete();
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    final ok = await widget.onConfirmed();
    if (!mounted) return;
    setState(() => _busy = false);
    // On success the parent navigates away; on failure, return to start.
    if (!ok) _springBack();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _maxX = constraints.maxWidth - _handleWidth - _inset * 2;
        final maxX = _maxX;
        final progress = maxX <= 0 ? 0.0 : (_dragX / maxX).clamp(0.0, 1.0);
        final locked = _busy || _anim.isAnimating;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: locked
              ? null
              : (d) => setState(
                  () => _dragX = (_dragX + d.delta.dx).clamp(0.0, maxX)),
          onHorizontalDragEnd: locked
              ? null
              : (_) {
                  // Forgiving threshold — past ~80% counts as a confirm.
                  if (_dragX >= maxX * 0.8) {
                    setState(() => _dragX = maxX);
                    _complete();
                  } else {
                    _springBack();
                  }
                },
          child: Container(
            height: _trackHeight,
            decoration: BoxDecoration(
              color: _track,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Centred label (nudged ~12px right of the handle, per Figma).
                // Kept to a single line so it never wraps inside the 48px track.
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Align(
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: 1 - progress,
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            color: widget.textColor ?? Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Faint trailing chevron hint (Figma).
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Opacity(
                      opacity: (1 - progress) * 0.5,
                      child: Icon(Icons.chevron_right,
                          color: widget.textColor ?? Colors.white, size: 22),
                    ),
                  ),
                ),
                // The draggable handle — white, raised, with the double chevron.
                Positioned(
                  left: _inset + _dragX,
                  top: _inset,
                  bottom: _inset,
                  child: Container(
                    width: _handleWidth,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _busy
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation(_handleIcon),
                            ),
                          )
                        : Icon(Icons.keyboard_double_arrow_right,
                            color: _handleIcon, size: 26),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
