import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A pressable wrapper with a gentle scale-down and a semantics label.
class Tappable extends StatefulWidget {
  const Tappable({super.key, required this.child, this.onTap, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
        onTapCancel: widget.onTap == null ? null : () => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down && !reduce ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Warm paper background with a faint vignette so pages feel like stock.
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: f.paper,
        gradient: RadialGradient(
          center: const Alignment(0, -0.9),
          radius: 1.4,
          colors: [f.surface, f.paper],
        ),
      ),
      child: child,
    );
  }
}

/// Text that fades + rises in on first build (respects reduce-motion).
class RevealText extends StatefulWidget {
  const RevealText(this.text, {super.key, this.style, this.delay = Duration.zero});
  final String text;
  final TextStyle? style;
  final Duration delay;
  @override
  State<RevealText> createState() => _RevealTextState();
}

class _RevealTextState extends State<RevealText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
  @override
  void initState() {
    super.initState();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _c.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = Curves.easeOut.transform(_c.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: Text(widget.text, style: widget.style)),
        );
      },
    );
  }
}

/// A section header: small uppercase kicker + serif title + hairline rule.
class FolioHeader extends StatelessWidget {
  const FolioHeader({super.key, required this.label, required this.title, this.trailing});
  final String label;
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: FolioText.label(context)),
                  const SizedBox(height: 4),
                  Text(title, style: FolioText.h2(context)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: f.rule),
      ],
    );
  }
}

/// A code-drawn 3D hardcover. No network images.
class CoverArt extends StatelessWidget {
  const CoverArt({super.key, required this.color, required this.title, required this.author, this.width = 140, this.heroTag});
  final Color color;
  final String title;
  final String author;
  final double width;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;
    final dark = _shade(color, -0.28);
    final light = _shade(color, 0.16);
    final textColor = _readable(color);
    final cover = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [dark, color, light]),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(4, 8))],
      ),
      // Cover typography is artwork: keep it fixed relative to the cover size so
      // it never overflows at large accessibility text scales.
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Stack(
        children: [
          // Spine highlight.
          Positioned(left: width * 0.07, top: 6, bottom: 6, child: Container(width: 1.5, color: light.withValues(alpha: 0.6))),
          Positioned(left: width * 0.1, top: 6, bottom: 6, child: Container(width: 1, color: dark.withValues(alpha: 0.5))),
          // Frame.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(width * 0.16, width * 0.14, width * 0.1, width * 0.12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 2, width: width * 0.3, color: textColor.withValues(alpha: 0.7)),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width * 0.78),
                      child: Text(
                        title,
                        maxLines: 4,
                        style: TextStyle(fontFamily: 'serif', fontFamilyFallback: kSerifFallback, fontSize: width * 0.13, height: 1.15, fontWeight: FontWeight.w700, color: textColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    author.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'sans-serif', fontSize: width * 0.062, letterSpacing: 0.8, height: 1.2, color: textColor.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 6),
                  Container(height: 1, width: width * 0.4, color: textColor.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
    if (heroTag != null) return Hero(tag: heroTag!, child: cover);
    return cover;
  }

  static Color _shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static Color _readable(Color c) {
    return c.computeLuminance() > 0.5 ? const Color(0xFF1C1B19) : const Color(0xFFF6F1E7);
  }
}

/// A horizontal carousel of covers with a gentle focus scale.
class CoverCarousel extends StatefulWidget {
  const CoverCarousel({super.key, required this.height, required this.itemCount, required this.itemBuilder});
  final double height;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  @override
  State<CoverCarousel> createState() => _CoverCarouselState();
}

class _CoverCarouselState extends State<CoverCarousel> {
  final _controller = PageController(viewportFraction: 0.42);
  double _page = 0;
  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.itemCount,
        padEnds: true,
        itemBuilder: (context, i) {
          final delta = (i - _page).abs();
          final scale = (1 - delta * 0.12).clamp(0.85, 1.0);
          return Center(
            child: Transform.scale(scale: scale, child: Opacity(opacity: (1 - delta * 0.25).clamp(0.5, 1.0), child: widget.itemBuilder(context, i))),
          );
        },
      ),
    );
  }
}

/// A rotated rubber-stamp badge.
class StampBadge extends StatelessWidget {
  const StampBadge(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.f.accent;
    return Transform.rotate(
      angle: -0.06,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(border: Border.all(color: c, width: 1.6), borderRadius: BorderRadius.circular(6)),
        child: Text(text.toUpperCase(), style: TextStyle(fontFamily: 'sans-serif', fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: c)),
      ),
    );
  }
}

enum FolioButtonStyle { ink, accent, outline }

/// The three button styles: ink fill, accent fill, hairline outline.
class FolioButton extends StatelessWidget {
  const FolioButton({super.key, required this.label, this.onPressed, this.style = FolioButtonStyle.ink, this.icon, this.expand = false});
  final String label;
  final VoidCallback? onPressed;
  final FolioButtonStyle style;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    final disabled = onPressed == null;
    Color bg;
    Color fg;
    Border? border;
    switch (style) {
      case FolioButtonStyle.accent:
        bg = f.accent;
        fg = Colors.white;
        break;
      case FolioButtonStyle.outline:
        bg = Colors.transparent;
        fg = f.ink;
        border = Border.all(color: f.ink, width: 1.2);
        break;
      case FolioButtonStyle.ink:
        bg = f.ink;
        fg = f.paper;
        break;
    }
    if (disabled) {
      bg = style == FolioButtonStyle.outline ? Colors.transparent : f.rule;
      fg = f.faint;
      border = style == FolioButtonStyle.outline ? Border.all(color: f.rule) : null;
    }
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: FolioText.button(context).copyWith(color: fg))),
      ],
    );
    return Tappable(
      onTap: onPressed,
      semanticLabel: label,
      child: Container(
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(color: bg, border: border, borderRadius: BorderRadius.circular(12)),
        child: child,
      ),
    );
  }
}

/// Three bouncing dots while the librarian thinks.
class ThinkingDots extends StatefulWidget {
  const ThinkingDots({super.key});
  @override
  State<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<ThinkingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_c.value + i * 0.2) % 1.0;
            final y = math.sin(t * math.pi) * 4;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(offset: Offset(0, -y), child: Container(width: 7, height: 7, decoration: BoxDecoration(color: f.accent, shape: BoxShape.circle))),
            );
          }),
        );
      },
    );
  }
}

/// A paper card with a hairline border and a soft shadow.
class PaperCard extends StatelessWidget {
  const PaperCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final f = context.f;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: f.card,
        borderRadius: BorderRadius.circular(FolioSpace.radius),
        border: Border.all(color: f.rule),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: f.isDark ? 0.3 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: child,
    );
    return onTap == null ? card : Tappable(onTap: onTap, child: card);
  }
}

/// Text that types itself out (respects reduce-motion).
class TypewriterText extends StatefulWidget {
  const TypewriterText(this.text, {super.key, this.style, this.speed = const Duration(milliseconds: 16)});
  final String text;
  final TextStyle? style;
  final Duration speed;
  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  int _count = 0;
  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _count = widget.text.length;
      return;
    }
    Future.doWhile(() async {
      await Future.delayed(widget.speed);
      if (!mounted) return false;
      setState(() => _count++);
      return _count < widget.text.length;
    });
  }

  @override
  void didUpdateWidget(TypewriterText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _count = 0;
      _start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.text.substring(0, _count.clamp(0, widget.text.length));
    return Text(shown, style: widget.style);
  }
}

/// One slot in the bottom navigation.
class FolioNavItem {
  const FolioNavItem(this.icon, this.label, {this.center = false, this.badge});
  final IconData icon;
  final String label;
  final bool center;
  final int? badge;
}

/// The five-slot Folio bottom bar with a raised centre AI button.
class FolioNavBar extends StatelessWidget {
  const FolioNavBar({super.key, required this.index, required this.onTap, required this.items});
  final int index;
  final ValueChanged<int> onTap;
  final List<FolioNavItem> items;

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return Container(
      decoration: BoxDecoration(color: f.card, border: Border(top: BorderSide(color: f.rule))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _slot(context, i, items[i])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(BuildContext context, int i, FolioNavItem item) {
    final f = context.f;
    final active = i == index;
    if (item.center) {
      return Tappable(
        onTap: () => onTap(i),
        semanticLabel: item.label,
        child: Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: f.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: f.accent.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]),
            child: Icon(item.icon, color: Colors.white, size: 24),
          ),
        ),
      );
    }
    return Tappable(
      onTap: () => onTap(i),
      semanticLabel: item.label,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(item.icon, size: 23, color: active ? f.accent : f.muted),
              if (item.badge != null && item.badge! > 0)
                Positioned(
                  right: -8,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: f.accent, borderRadius: BorderRadius.circular(8)),
                    constraints: const BoxConstraints(minWidth: 15),
                    child: Text('${item.badge}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(item.label, style: TextStyle(fontFamily: 'sans-serif', fontSize: 10, color: active ? f.accent : f.muted, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}

/// A selectable hairline chip.
class FolioChip extends StatelessWidget {
  const FolioChip({super.key, required this.label, this.selected = false, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return Tappable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? f.ink : Colors.transparent,
          border: Border.all(color: selected ? f.ink : f.rule),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: FolioText.caption(context).copyWith(color: selected ? f.paper : f.ink, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// A hairline divider.
class FolioDivider extends StatelessWidget {
  const FolioDivider({super.key, this.indent = 0});
  final double indent;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: indent),
        child: Container(height: 1, color: context.f.rule),
      );
}
