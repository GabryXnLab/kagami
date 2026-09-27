/// I pezzi con cui sono fatti i grafici: tavolozza, riquadri, legenda e
/// calendario dell'attività.
///
/// La tavolozza è scelta, non inventata: sei tinte che restano distinguibili
/// anche a chi non distingue i colori come la maggioranza, verificate sulle
/// due superfici dell'app. L'ordine è fisso — una fetta non cambia colore
/// perché ne è sparita un'altra — e nessun grafico affida l'identità al solo
/// colore: accanto ci sono sempre legenda ed etichette.
library;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Tinte per i dati divisi in categorie, nell'ordine in cui si usano.
const List<Color> _categoricalDark = [
  Color(0xFF3987E5),
  Color(0xFFD95926),
  Color(0xFF199E70),
  Color(0xFFC98500),
  Color(0xFFD55181),
  Color(0xFF008300),
];

const List<Color> _categoricalLight = [
  Color(0xFF2A78D6),
  Color(0xFFEB6834),
  Color(0xFF1BAF7A),
  Color(0xFFEDA100),
  Color(0xFFE87BA4),
  Color(0xFF008300),
];

List<Color> chartPalette(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? _categoricalDark
        : _categoricalLight;

/// Un numero solo, quando il numero è già la risposta e un grafico sarebbe
/// una decorazione.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.value,
    required this.label,
    this.hint,
    super.key,
  });

  final String value;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: KagamiType.figure(25)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KagamiType.label(size: 12, color: muted),
          ),
          if (hint != null)
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KagamiType.label(size: 11, color: muted),
            ),
        ],
      ),
    );
  }
}

/// La cornice di un grafico: titolo, una riga che dice cosa si sta guardando
/// e lo spazio in cui disegnarlo.
class ChartCard extends StatelessWidget {
  const ChartCard({
    required this.title,
    required this.height,
    required this.child,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final double height;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainer,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: KagamiType.title(15, weight: 700)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: KagamiType.body(
                              12,
                              color: context.tokens.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(height: height, child: child),
            ],
          ),
        ),
      );
}

/// La legenda. C'è sempre quando le serie sono più di una: il colore da solo
/// non deve mai essere l'unico modo di sapere cosa si sta guardando.
class ChartLegend extends StatelessWidget {
  const ChartLegend({required this.entries, super.key});

  final List<(String, Color, String)> entries;

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (label, color, value) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: KagamiType.label(size: 12)),
              const SizedBox(width: 4),
              Text(value, style: KagamiType.figure(12, color: muted)),
            ],
          ),
      ],
    );
  }
}

/// Il calendario dell'attività: una casella per giorno, tanto più accesa
/// quanto più si è letto.
///
/// È una scala di intensità e non di tinte: la quantità si legge dal chiaro
/// allo scuro, e usare colori diversi per quantità diverse vorrebbe dire
/// chiedere a chi guarda di ricordare una legenda che non esiste.
class ActivityCalendar extends StatelessWidget {
  const ActivityCalendar({
    required this.perDay,
    required this.days,
    super.key,
  });

  final Map<DateTime, int> perDay;
  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Si parte dal lunedì, così ogni colonna è una settimana intera.
    final first = today
        .subtract(Duration(days: days - 1))
        .subtract(Duration(days: (today.weekday - 1) % 7));
    final weeks = (today.difference(first).inDays / 7).ceil() + 1;
    final highest = perDay.values.fold<int>(1, (top, v) => v > top ? v : top);

    return LayoutBuilder(
      builder: (context, box) {
        final cell = ((box.maxHeight - 6 * 3) / 7).clamp(6.0, 16.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var week = 0; week < weeks; week++)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Column(
                    children: [
                      for (var day = 0; day < 7; day++)
                        Builder(
                          builder: (context) {
                            final date =
                                first.add(Duration(days: week * 7 + day));
                            if (date.isAfter(today)) {
                              return SizedBox(height: cell + 3, width: cell);
                            }
                            final count = perDay[date] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Tooltip(
                                message: count == 0
                                    ? '${date.day}/${date.month}: niente'
                                    : '${date.day}/${date.month}: $count capitoli',
                                child: Container(
                                  width: cell,
                                  height: cell,
                                  decoration: BoxDecoration(
                                    color: count == 0
                                        ? scheme.surfaceContainerHighest
                                        : scheme.primary.withValues(
                                            alpha: 0.25 +
                                                0.75 * (count / highest),
                                          ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
