class GradingBand {
  const GradingBand(this.letter, this.points, this.minimum);
  final String letter;
  final double points;
  final double? minimum;
}

/// Definitions are supplied by the website CMS, not mobile-only presets.
class GradingScale {
  const GradingScale({
    required this.id,
    required this.name,
    required this.maximum,
    required this.bands,
    this.institution = '',
  });
  final String id, name, institution;
  final double maximum;
  final List<GradingBand> bands;

  static List<GradingScale> parseList(dynamic payload) {
    final rows = payload is Map ? payload['gradingScales'] : null;
    if (rows is! List) return [];
    final seen = <String>{};
    final result = <GradingScale>[];
    for (final row in rows.whereType<Map>()) {
      final id = row['id']?.toString() ?? '';
      final name = row['name']?.toString() ?? '';
      final rawMaximum = row['maximumGpa'];
      final maximum = rawMaximum is num ? rawMaximum.toDouble() : null;
      if (id.isEmpty ||
          name.isEmpty ||
          maximum == null ||
          !maximum.isFinite ||
          maximum <= 0 ||
          seen.contains(id)) {
        continue;
      }
      final bands = <GradingBand>[];
      final rawBands = row['bands'];
      if (rawBands is List) {
        for (final band in rawBands.whereType<Map>()) {
          final letter = band['letterGrade']?.toString() ?? '';
          final points = band['gradePoints'];
          final minimum = band['minimumPercentage'];
          if (letter.isEmpty ||
              points is! num ||
              !points.isFinite ||
              points < 0 ||
              points > maximum ||
              (minimum != null &&
                  (minimum is! num ||
                      !minimum.isFinite ||
                      minimum < 0 ||
                      minimum > 100))) {
            continue;
          }
          bands.add(
            GradingBand(
              letter,
              points.toDouble(),
              (minimum as num?)?.toDouble(),
            ),
          );
        }
      }
      if (bands.isEmpty) continue;
      seen.add(id);
      result.add(
        GradingScale(
          id: id,
          name: name,
          maximum: maximum,
          bands: List.unmodifiable(bands),
          institution: row['institutionName']?.toString() ?? '',
        ),
      );
    }
    return result;
  }

  double? pointsFor(String input) {
    final raw = input.trim().toUpperCase().replaceAll('−', '-');
    final percent = double.tryParse(raw.replaceAll(',', '.'));
    if (percent != null) {
      if (!percent.isFinite || percent < 0 || percent > 100) return null;
      final matches =
          bands
              .where((band) => band.minimum != null && percent >= band.minimum!)
              .toList()
            ..sort((a, b) => b.minimum!.compareTo(a.minimum!));
      return matches.firstOrNull?.points;
    }
    return bands
        .where((band) => band.letter.toUpperCase() == raw)
        .firstOrNull
        ?.points;
  }
}

/// Matches the website's proportional converter; not an official equivalency.
double? convertGpa(double value, GradingScale from, GradingScale to) {
  if (!value.isFinite ||
      !from.maximum.isFinite ||
      !to.maximum.isFinite ||
      value < 0 ||
      value > from.maximum ||
      from.maximum <= 0 ||
      to.maximum <= 0) {
    return null;
  }
  return (value / from.maximum * to.maximum * 100).round() / 100;
}
