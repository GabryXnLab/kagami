/// «Arrivato a»: cambiare il punto di lettura dalla scheda della serie.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../format/malf.dart';
import '../../format/reading.dart';
import '../../l10n.dart';
import '../../providers.dart';
import '../theme.dart';
import 'kit.dart';

/// Oltre questa lunghezza l'elenco ha la ricerca.
const int _searchAbove = 30;

/// Il capitolo che il ripiano indica come punto di lettura: l'ultimo letto
/// dell'indice, altrimenti il numero dichiarato.
ChapterEntry? lastReadChapter(
  Iterable<ChapterEntry> chapters,
  SeriesState state,
) {
  ChapterEntry? last;
  for (final chapter in chapters) {
    if (!state.readChapters.contains(chapter.id)) continue;
    if (last == null || chapter.order > last.order) last = chapter;
  }
  return last;
}

/// Il testo del punto di lettura, o `null` se non lo si sa.
String? reachedLabel(Iterable<ChapterEntry> chapters, SeriesState state) {
  final last = lastReadChapter(chapters, state);
  if (last != null) return last.label();
  final number = state.reachedChapter;
  return number == null ? null : currentL10n().seriesReachedChapter(number);
}

/// Chiede il nuovo punto e lo scrive: con l'elenco dei capitoli sceglie un
/// capitolo, senza un numero.
Future<void> editReached(
  BuildContext context,
  WidgetRef ref,
  String key,
  List<ChapterEntry> chapters,
  SeriesState state,
) async {
  final reading = ref.read(readingProvider.notifier);
  if (chapters.isEmpty) {
    final number = await showKagamiSheet<String>(
      context,
      title: context.l10n.seriesReachedTitle,
      builder: (context) => _NumberForm(initial: state.reachedChapter ?? ''),
    );
    if (number == null) return;
    await reading.setReachedChapter(key, number);
    return;
  }
  final current = lastReadChapter(chapters, state);
  final chosen = await showKagamiSheet<ChapterEntry>(
    context,
    title: context.l10n.seriesReachedTitle,
    scrollable: true,
    builder: (context) => _ChapterPicker(chapters: chapters, current: current),
  );
  if (chosen == null || chosen.id == current?.id || !context.mounted) return;
  // Segnare letti i capitoli fino a quello scelto non toglie il letto ai
  // successivi: tornare indietro li lascia come sono.
  if (current != null && chosen.order < current.order) {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.seriesReachedBackTitle),
        content: Text(l10n.seriesReachedBackMessage(chosen.label())),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.archiveCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.seriesReachedBackConfirm),
          ),
        ],
      ),
    );
    if (sure != true) return;
  }
  await reading.setReachedThrough(key, chapters, chosen.id);
}

class _NumberForm extends StatefulWidget {
  const _NumberForm({required this.initial});

  final String initial;

  @override
  State<_NumberForm> createState() => _NumberFormState();
}

class _NumberFormState extends State<_NumberForm> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: context.l10n.seriesReachedNumberHint,
                helperText: context.l10n.seriesReachedNumberHelp,
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
            const SizedBox(height: 16),
            KButton(
              label: context.l10n.seriesSave,
              expand: true,
              onPressed: () => Navigator.of(context).pop(_controller.text),
            ),
          ],
        ),
      );
}

class _ChapterPicker extends StatefulWidget {
  const _ChapterPicker({required this.chapters, required this.current});

  final List<ChapterEntry> chapters;
  final ChapterEntry? current;

  @override
  State<_ChapterPicker> createState() => _ChapterPickerState();
}

class _ChapterPickerState extends State<_ChapterPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final needle = _query.trim().toLowerCase();
    final shown = [
      for (final chapter in widget.chapters.reversed)
        if (needle.isEmpty || chapter.label().toLowerCase().contains(needle))
          chapter,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.chapters.length > _searchAbove)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                hintText: context.l10n.seriesReachedSearch,
              ),
            ),
          ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            itemCount: shown.length,
            itemBuilder: (context, position) {
              final chapter = shown[position];
              final here = chapter.id == widget.current?.id;
              return KPress(
                onTap: () => Navigator.of(context).pop(chapter),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          chapter.label(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KagamiType.title(14.5, weight: here ? 700 : 500),
                        ),
                      ),
                      if (here)
                        Icon(LucideIcons.check, size: 18, color: scheme.primary),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
