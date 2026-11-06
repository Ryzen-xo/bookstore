import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import 'folio_widgets.dart';

export 'package:flutter/services.dart' show TextInputFormatter, FilteringTextInputFormatter, LengthLimitingTextInputFormatter;

/// Push a page with a gentle Cupertino-style slide.
Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
}

void lightHaptic() => HapticFeedback.lightImpact();

/// Constrains content to a readable measure on tablets.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.max = FolioSpace.maxContentWidth});
  final Widget child;
  final double max;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: max), child: child),
      );
}

/// The standard page scaffold: paper background + optional Folio app bar.
class FolioPage extends StatelessWidget {
  const FolioPage({
    super.key,
    required this.body,
    this.title,
    this.kicker,
    this.actions,
    this.bottom,
    this.floating,
    this.showBack = true,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
    this.scrollable = true,
  });

  final Widget body;
  final String? title;
  final String? kicker;
  final List<Widget>? actions;
  final Widget? bottom;
  final Widget? floating;
  final bool showBack;
  final EdgeInsets padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    final canPop = Navigator.of(context).canPop();
    final content = Padding(padding: padding, child: body);
    return Scaffold(
      backgroundColor: f.paper,
      floatingActionButton: floating,
      bottomNavigationBar: bottom,
      appBar: (title == null && kicker == null && actions == null && !(showBack && canPop))
          ? null
          : AppBar(
              backgroundColor: f.paper,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: showBack && canPop
                  ? IconButton(icon: Icon(Icons.arrow_back, color: f.ink), onPressed: () => Navigator.of(context).maybePop())
                  : null,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (kicker != null) Text(kicker!.toUpperCase(), style: FolioText.label(context)),
                  if (title != null) Text(title!, style: FolioText.h3(context)),
                ],
              ),
              actions: actions,
            ),
      body: PaperBackground(
        child: SafeArea(
          child: ContentWidth(child: scrollable ? SingleChildScrollView(child: content) : content),
        ),
      ),
    );
  }
}

/// A square hairline icon button.
class FolioIconButton extends StatelessWidget {
  const FolioIconButton({super.key, required this.icon, this.onTap, this.label, this.badge});
  final IconData icon;
  final VoidCallback? onTap;
  final String? label;
  final int? badge;
  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return Tappable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: f.rule), borderRadius: BorderRadius.circular(12)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: f.ink, size: 21),
            if (badge != null && badge! > 0)
              Positioned(
                right: -10,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: f.accent, borderRadius: BorderRadius.circular(8)),
                  constraints: const BoxConstraints(minWidth: 15),
                  child: Text('$badge', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Display + input star rating.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.size = 16, this.onChanged, this.color});
  final double value;
  final double size;
  final ValueChanged<int>? onChanged;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    final c = color ?? f.gold;
    final input = onChanged != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (input) {
          icon = i < value ? Icons.star_rounded : Icons.star_outline_rounded;
        } else {
          if (value >= i + 1) {
            icon = Icons.star_rounded;
          } else if (value > i) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_outline_rounded;
          }
        }
        final star = Icon(icon, size: size, color: c);
        if (!input) return star;
        return GestureDetector(
          onTap: () => onChanged!(i + 1),
          behavior: HitTestBehavior.opaque,
          child: Padding(padding: EdgeInsets.symmetric(horizontal: size * 0.06), child: star),
        );
      }),
    );
  }
}

/// A 5-bucket rating histogram.
class RatingBars extends StatelessWidget {
  const RatingBars({super.key, required this.histogram});
  final List<int> histogram;
  @override
  Widget build(BuildContext context) {
    final f = context.f;
    final maxCount = histogram.fold<int>(1, (m, v) => v > m ? v : m);
    return Column(
      children: List.generate(5, (i) {
        final star = 5 - i;
        final count = histogram[star - 1];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(width: 14, child: Text('$star', style: FolioText.caption(context))),
              Icon(Icons.star_rounded, size: 12, color: f.gold),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: count / maxCount, minHeight: 6, backgroundColor: f.rule, valueColor: AlwaysStoppedAnimation(f.gold)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 24, child: Text('$count', textAlign: TextAlign.right, style: FolioText.caption(context))),
            ],
          ),
        );
      }),
    );
  }
}

/// A calm empty state.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: f.faint),
            const SizedBox(height: 16),
            Text(title, style: FolioText.h3(context), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: FolioText.bodySmall(context).copyWith(color: f.muted), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// A labelled Folio text field backed by a [TextFormField].
class FolioField extends StatelessWidget {
  const FolioField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: FolioText.label(context)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          inputFormatters: inputFormatters,
          maxLines: obscure ? 1 : maxLines,
          maxLength: maxLength,
          autofillHints: autofillHints,
          onFieldSubmitted: onSubmitted,
          style: FolioText.body(context),
          cursorColor: f.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: FolioText.italic(context).copyWith(color: f.faint),
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, color: f.muted, size: 20),
            suffixIcon: suffix,
            counterText: '',
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: f.rule)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: f.accent, width: 1.4)),
            errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: f.danger)),
            focusedErrorBorder: UnderlineInputBorder(borderSide: BorderSide(color: f.danger, width: 1.4)),
          ),
        ),
      ],
    );
  }
}

/// A shimmering placeholder block.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width = double.infinity, this.height = 16, this.radius = 8});
  final double width;
  final double height;
  final double radius;
  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
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
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(f.rule, f.card, _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A brief toast.
void showToast(BuildContext context, String message) {
  final f = context.f;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: TextStyle(color: f.paper, fontFamily: 'sans-serif')),
      backgroundColor: f.ink,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
}

/// A Folio-styled modal bottom sheet.
Future<T?> showFolioSheet<T>(BuildContext context, {required Widget child}) {
  final f = context.f;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: f.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: f.rule, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A confirmation dialog. Returns true only on explicit confirm.
Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String confirmLabel = 'Confirm', bool danger = false}) async {
  final f = context.f;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: f.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: f.rule)),
      title: Text(title, style: FolioText.h3(context)),
      content: Text(message, style: FolioText.bodySmall(context)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel', style: TextStyle(color: f.muted))),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(confirmLabel, style: TextStyle(color: danger ? f.danger : f.accent, fontWeight: FontWeight.w700))),
      ],
    ),
  );
  return result ?? false;
}

/// Gate an action behind login; returns true if signed in (else opens login).
bool requireLogin(BuildContext context) {
  final state = AppStateScope.read(context);
  if (state.loggedIn) return true;
  state.openLogin();
  return false;
}

enum BookCardVariant { grid, shelf, row }

/// The catalogue card. Grid/shelf are vertical; row is horizontal. The rating +
/// price line uses a [Wrap] so it never overflows at large text scales.
class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book, this.variant = BookCardVariant.grid, this.heroEnabled = true, this.onTap});
  final Book book;
  final BookCardVariant variant;
  final bool heroEnabled;
  final VoidCallback? onTap;

  void _open(BuildContext context) {
    lightHaptic();
    if (onTap != null) {
      onTap!();
    } else {
      AppStateScope.read(context).openBook(context, book);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (variant == BookCardVariant.row) return _row(context);
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 160.0;
      return Tappable(
        onTap: () => _open(context),
        semanticLabel: '${book.title} by ${book.author}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CoverArt(color: book.color(), title: book.title, author: book.author, width: w, heroTag: heroEnabled ? 'cover-${book.id}' : null),
            const SizedBox(height: 10),
            Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: FolioText.title(context)),
            const SizedBox(height: 2),
            Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: FolioText.caption(context)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StarRating(value: book.avgRating, size: 13),
                Text(money(book.price), style: FolioText.title(context).copyWith(color: context.f.accent)),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _row(BuildContext context) {
    final f = context.f;
    return Tappable(
      onTap: () => _open(context),
      semanticLabel: '${book.title} by ${book.author}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoverArt(color: book.color(), title: book.title, author: book.author, width: 56, heroTag: heroEnabled ? 'cover-${book.id}' : null),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: FolioText.title(context)),
                const SizedBox(height: 2),
                Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: FolioText.caption(context)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StarRating(value: book.avgRating, size: 13),
                    Text(money(book.price), style: FolioText.title(context).copyWith(color: f.accent)),
                    if (!book.inStock) StampBadge('Sold out', color: f.danger),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A code-drawn book spine for the shelf view.
class BookSpine extends StatelessWidget {
  const BookSpine({super.key, required this.book, this.height = 180, this.onTap});
  final Book book;
  final double height;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = book.color();
    final textColor = c.computeLuminance() > 0.5 ? const Color(0xFF1C1B19) : const Color(0xFFF6F1E7);
    return Tappable(
      onTap: onTap ?? () => AppStateScope.read(context).openBook(context, book),
      semanticLabel: book.title,
      child: Container(
        width: 42,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [HSLColor.fromColor(c).withLightness(0.3).toColor(), c], begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(3),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(2, 3))],
        ),
        child: RotatedBox(
          quarterTurns: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'serif', fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A wooden shelf row of spines.
class BookShelf extends StatelessWidget {
  const BookShelf({super.key, required this.books});
  final List<Book> books;
  @override
  Widget build(BuildContext context) {
    final f = context.f;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) => Align(alignment: Alignment.bottomCenter, child: BookSpine(book: books[i], height: 150 + (i % 3) * 14)),
          ),
        ),
        Container(height: 8, decoration: BoxDecoration(color: f.gold.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 3))])),
      ],
    );
  }
}
