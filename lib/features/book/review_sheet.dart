import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/folio_widgets.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';

/// Write or edit a review. Pops `true` when saved.
class ReviewSheet extends StatefulWidget {
  const ReviewSheet({super.key, required this.book, this.existing});
  final Book book;
  final Review? existing;
  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  late int _rating = widget.existing?.rating ?? 0;
  late final _body = TextEditingController(text: widget.existing?.body ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_rating == 0) {
      showToast(context, 'Please choose a star rating.');
      return;
    }
    if (_body.text.length > 600) {
      showToast(context, 'Reviews are limited to 600 characters.');
      return;
    }
    setState(() => _busy = true);
    final state = AppStateScope.read(context);
    try {
      await state.repo.saveReview(state.user!.id, widget.book.id, _rating, _body.text.trim());
      if (!mounted) return;
      showToast(context, 'Thanks for your review!');
      Navigator.of(context).pop(true);
    } on AppError catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.existing == null ? 'Write a review' : 'Edit your review', style: FolioText.h2(context)),
        const SizedBox(height: 4),
        Text(widget.book.title, style: FolioText.italic(context)),
        const SizedBox(height: 20),
        Text('YOUR RATING', style: FolioText.label(context)),
        const SizedBox(height: 8),
        StarRating(value: _rating.toDouble(), size: 36, onChanged: (v) => setState(() => _rating = v)),
        const SizedBox(height: 20),
        FolioField(
          controller: _body,
          label: 'Your review',
          hint: 'What did you think? (optional)',
          maxLines: 5,
          maxLength: 600,
          inputFormatters: [LengthLimitingTextInputFormatter(600)],
        ),
        Align(alignment: Alignment.centerRight, child: Text('${_body.text.length}/600', style: FolioText.caption(context))),
        const SizedBox(height: 16),
        FolioButton(label: _busy ? 'Saving…' : 'Submit review', style: FolioButtonStyle.accent, expand: true, onPressed: _busy ? null : _save),
      ],
    );
  }
}
