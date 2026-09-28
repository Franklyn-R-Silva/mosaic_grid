import 'package:flutter/material.dart';
import 'package:mosaic_grid/mosaic_grid.dart';

import 'sample_data.dart';

/// A masonry board of notes: every note keeps its own height and drops into
/// the column that ends first; the pinned note spans the whole width.
class BoardPage extends StatelessWidget {
  /// Creates the board demo.
  const BoardPage({super.key, this.scrollController});

  /// Optional scroll controller, used by the screenshot script.
  final ScrollController? scrollController;

  static final List<Note> _notes = List.generate(300, Note.sample);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Board'),
            Text(
              'Masonry · the pinned note spans every column',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: MosaicGrid.builder(
        scrollController: scrollController,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        layout: const MosaicLayout.masonry(),
        columns: const MosaicColumns.minExtent(160, maxCount: 5),
        columnGap: 10,
        rowGap: 10,
        itemCount: _notes.length,
        columnSpan: (i) => _notes[i].pinned ? 99 : 1,
        itemBuilder: (context, i) => NoteCard(note: _notes[i]),
      ),
    );
  }
}

/// A note card whose height follows its cover and text.
class NoteCard extends StatelessWidget {
  /// Creates a card for [note].
  const NoteCard({super.key, required this.note});

  /// The note shown.
  final Note note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final tint = HSLColor.fromAHSL(
      1,
      note.hue,
      dark ? 0.25 : 0.55,
      dark ? 0.18 : 0.95,
    ).toColor();
    final ratio = note.imageAspectRatio;
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ratio != null)
            AspectRatio(
              aspectRatio: note.pinned ? ratio * 1.6 : ratio,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: illustrationGradient(note.hue),
                ),
                child: Icon(
                  note.icon,
                  size: 40,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (note.pinned) ...[
                      Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        note.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  note.body,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: HSLColor.fromAHSL(
                        1,
                        note.hue,
                        0.55,
                        0.45,
                      ).toColor(),
                      child: Text(
                        note.author[0],
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(note.author, style: theme.textTheme.labelMedium),
                    const Spacer(),
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
