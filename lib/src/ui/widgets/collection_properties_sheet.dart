/// Le proprietà di una raccolta: le regole con cui si riempie da sola e le
/// caratteristiche che valgono per tutte le sue serie.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/library_view.dart';
import '../../format/reading.dart';
import '../../l10n.dart';
import '../../providers.dart';
import '../series_screen.dart' show releaseLabels, shelfIcons, shelfLabels;
import '../theme.dart';
import 'kit.dart';

typedef CollectionProperties = (CollectionRules, CollectionTraits);

/// Apre il foglio sui valori di partenza; `null` se l'utente chiude senza
/// applicare.
Future<CollectionProperties?> showCollectionProperties(
  BuildContext context,
  WidgetRef ref, {
  CollectionRules rules = const CollectionRules(),
  CollectionTraits traits = const CollectionTraits(),
}) {
  final facets = ref.read(libraryFacetsProvider);
  return showKagamiSheet<CollectionProperties>(
    context,
    title: context.l10n.collectionPropsTitle,
    scrollable: true,
    builder: (context) => CollectionPropertiesForm(
      facets: facets,
      rules: rules,
      traits: traits,
    ),
  );
}

class CollectionPropertiesForm extends StatefulWidget {
  const CollectionPropertiesForm({
    required this.facets,
    required this.rules,
    required this.traits,
    super.key,
  });

  final LibraryFacets facets;
  final CollectionRules rules;
  final CollectionTraits traits;

  @override
  State<CollectionPropertiesForm> createState() => _FormState();
}

/// Oltre questa soglia i tag si cercano scrivendo invece di scorrerli.
const int _searchAbove = 12;
const int _shownMax = 40;

class _FormState extends State<CollectionPropertiesForm> {
  late CollectionRules _rules = widget.rules;
  late CollectionTraits _traits = widget.traits;
  String _query = '';

  late final List<String> _allTags = {
    ...widget.facets.genres,
    ...widget.facets.tags,
    ..._rules.tags,
  }.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  Set<T> _toggle<T>(Set<T> set, T value) =>
      set.contains(value) ? ({...set}..remove(value)) : {...set, value};

  void _setTraits({bool? muted, bool? keep, bool? pause, bool? rating}) =>
      setState(() => _traits = CollectionTraits(
            muted: muted ?? _traits.muted,
            keepChapters: keep ?? _traits.keepChapters,
            noAutoPause: pause ?? _traits.noAutoPause,
            noRatingInvite: rating ?? _traits.noRatingInvite,
          ));

  Widget _group(String title, List<Widget> chips) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KSection(title),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ),
      );

  Widget _switch(IconData icon, String title, bool value, ValueChanged<bool> onChanged) =>
      KTile(
        icon: icon,
        title: title,
        onTap: () => onChanged(!value),
        trailing: Switch(value: value, onChanged: onChanged),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final facets = widget.facets;
    final query = _query.trim().toLowerCase();
    final tags = [
      ..._allTags.where(_rules.tags.contains),
      ..._allTags
          .where((tag) => !_rules.tags.contains(tag))
          .where((tag) => query.isEmpty || tag.toLowerCase().contains(query)),
    ].take(_shownMax).toList();
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          l10n.collectionPropsAutoTitle,
          style: KagamiType.display(16),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.collectionPropsAutoNote,
          style: KagamiType.label(size: 13, color: context.tokens.muted),
        ),
        const SizedBox(height: 16),
        if (facets.types.isNotEmpty)
          _group(l10n.collectionPropsTypes, [
            for (final type in facets.types)
              KChip(
                label: type,
                active: _rules.types.contains(type),
                onTap: () => setState(
                  () => _rules = _rules.copyWith(types: _toggle(_rules.types, type)),
                ),
              ),
          ]),
        if (_allTags.isNotEmpty) ...[
          _group(l10n.collectionPropsTags, [
            for (final tag in tags)
              KChip(
                label: tag,
                active: _rules.tags.contains(tag),
                onTap: () => setState(
                  () => _rules = _rules.copyWith(tags: _toggle(_rules.tags, tag)),
                ),
              ),
          ]),
          if (_allTags.length > _searchAbove)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: l10n.collectionPropsTagSearch,
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                ),
              ),
            ),
        ],
        _group(l10n.collectionPropsShelf, [
          for (final status in ShelfStatus.values)
            KChip(
              label: shelfLabels[status]!,
              icon: shelfIcons[status],
              active: _rules.shelf.contains(status),
              onTap: () => setState(
                () => _rules = _rules.copyWith(shelf: _toggle(_rules.shelf, status)),
              ),
            ),
        ]),
        _group(l10n.collectionPropsRelease, [
          for (final entry in releaseLabels.entries)
            KChip(
              label: entry.value,
              active: _rules.release.contains(entry.key),
              onTap: () => setState(
                () => _rules = _rules.copyWith(release: _toggle(_rules.release, entry.key)),
              ),
            ),
        ]),
        if (facets.providers.isNotEmpty)
          _group(l10n.collectionPropsProviders, [
            for (final provider in facets.providers)
              KChip(
                label: provider,
                active: _rules.providers.contains(provider),
                onTap: () => setState(
                  () => _rules = _rules.copyWith(providers: _toggle(_rules.providers, provider)),
                ),
              ),
          ]),
        _group(l10n.collectionPropsMinRating, [
          for (final value in const [6, 7, 8, 9, 10])
            KChip(
              label: '$value',
              active: _rules.minRating == value,
              onTap: () => setState(
                () => _rules = _rules.minRating == value
                    ? _rules.copyWith(clearMinRating: true)
                    : _rules.copyWith(minRating: value),
              ),
            ),
        ]),
        _switch(
          LucideIcons.heart,
          l10n.collectionPropsFavorite,
          _rules.favorite,
          (value) => setState(() => _rules = _rules.copyWith(favorite: value)),
        ),
        const SizedBox(height: 22),
        Text(
          l10n.collectionPropsTraitsTitle,
          style: KagamiType.display(16),
        ),
        const SizedBox(height: 8),
        _switch(LucideIcons.bellOff, l10n.collectionPropsMuted, _traits.muted,
            (value) => _setTraits(muted: value)),
        _switch(LucideIcons.eraser, l10n.collectionPropsKeepChapters,
            _traits.keepChapters, (value) => _setTraits(keep: value)),
        _switch(LucideIcons.pause, l10n.collectionPropsNoAutoPause,
            _traits.noAutoPause, (value) => _setTraits(pause: value)),
        _switch(LucideIcons.star, l10n.collectionPropsNoRatingInvite,
            _traits.noRatingInvite, (value) => _setTraits(rating: value)),
        const SizedBox(height: 22),
        KButton(
          label: l10n.collectionPropsApply,
          expand: true,
          onPressed: () => Navigator.of(context).pop((_rules, _traits)),
        ),
      ],
    );
  }
}
