import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

class SliderButtonWidget extends StatefulWidget {
  final VoidCallback? onSlideComplete;
  final VoidCallback? onTap;
  final String text;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final TextStyle? textStyle;
  final Color? arrowColor;
  final bool reverse;
  final Color? thumbColor;
  // Size of the draggable square thumb. Defaults to 58 (legacy behaviour).
  final double? thumbSize;
  // Gap between the thumb and the track edge. Defaults to 3 (legacy).
  final double thumbMargin;
  // Corner radius of the thumb. Defaults to 17 (legacy).
  final double thumbBorderRadius;
  // Size of the built-in chevron icon inside the thumb.
  final double iconSize;
  // Optional custom widget rendered inside the thumb instead of the built-in
  // chevron icon (e.g. a Figma-exported chevron SVG).
  final Widget? thumbIcon;

  const SliderButtonWidget({
    super.key,
    this.onSlideComplete,
    this.onTap,
    required this.text,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.textColor,
    this.padding,
    this.margin,
    this.textStyle,
    this.arrowColor,
    this.reverse = false,
    this.thumbColor,
    this.thumbSize,
    this.thumbMargin = 3,
    this.thumbBorderRadius = 17,
    this.iconSize = 30,
    this.thumbIcon,
  });

  @override
  State<SliderButtonWidget> createState() => _SliderButtonWidgetState();
}

class _SliderButtonWidgetState extends State<SliderButtonWidget> {
  double _dragPosition = 0;
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    final containerHeight = widget.height ?? 64;
    final thumbSize = widget.thumbSize ?? 58;
    final thumbMargin = widget.thumbMargin;

    return Container(
      padding: widget.padding ?? EdgeInsets.zero,
      margin: widget.margin ?? EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxDrag = maxWidth - thumbSize - (thumbMargin * 2);

          return Container(
            height: containerHeight,
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? HexColor("#FFD546"),
              borderRadius: widget.borderRadius ?? BorderRadius.circular(20),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Center text
                Center(
                  child: Text(
                    widget.text,
                    style: widget.textStyle ??
                        TextStyle(
                          color: widget.textColor ?? Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),

                // Draggable thumb
                AnimatedPositioned(
                  duration: _completed
                      ? const Duration(milliseconds: 300)
                      : Duration.zero,
                  left: widget.reverse ? null : thumbMargin + _dragPosition,
                  right: widget.reverse ? thumbMargin + _dragPosition : null,
                  top: thumbMargin,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_completed) return;
                      setState(() {
                        // In reverse mode the thumb sits on the right and
                        // moves left, so dragging left (negative dx)
                        // increases the progress.
                        _dragPosition +=
                            widget.reverse ? -details.delta.dx : details.delta.dx;
                        _dragPosition = _dragPosition.clamp(0, maxDrag);
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (_completed) return;
                      if (_dragPosition >= maxDrag * 0.75) {
                        setState(() {
                          _dragPosition = maxDrag;
                          _completed = true;
                        });
                        (widget.onSlideComplete ?? widget.onTap)?.call();
                        // Reset after a short delay
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted) {
                            setState(() {
                              _dragPosition = 0;
                              _completed = false;
                            });
                          }
                        });
                      } else {
                        setState(() {
                          _dragPosition = 0;
                        });
                      }
                    },
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: widget.thumbColor ?? Colors.white,
                        borderRadius:
                            BorderRadius.circular(widget.thumbBorderRadius),
                        border: Border.all(color: const Color(0xFFE6EEF2)),
                      ),
                      child: Center(
                        child: widget.thumbIcon ??
                            Icon(
                              widget.reverse
                                  ? Icons.keyboard_double_arrow_left
                                  : Icons.keyboard_double_arrow_right,
                              color: widget.arrowColor ?? HexColor("#FFD546"),
                              size: widget.iconSize,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
