/// Ripetizione dilazionata (SM-2 semplificato), identica a BE/services/flashcards.py.
/// Voti: 0 per niente, 1 a fatica, 2 bene, 3 facile.
class FlashcardSchedule {
  final double ease;
  final int intervalDays;
  final Duration wait;

  const FlashcardSchedule(this.ease, this.intervalDays, this.wait);
}

class FlashcardScheduler {
  FlashcardScheduler._();

  static const double minEase = 1.3;

  static FlashcardSchedule next({required double ease, required int intervalDays, required int reviews, required int grade}) {
    final int g = grade.clamp(0, 3);
    double e = ease <= 0 ? 2.5 : ease;
    if (g < 2) {
      e = (e - (g == 1 ? 0.2 : 0.3)).clamp(minEase, 10.0);
      return FlashcardSchedule(e, 0, Duration(minutes: g == 1 ? 10 : 1));
    }
    e = (e + (g == 3 ? 0.15 : 0.0)).clamp(minEase, 10.0);
    int interval;
    if (reviews == 0 || intervalDays <= 0) {
      interval = g == 2 ? 3 : 8;
    } else {
      final int grown = (intervalDays * e * (g == 3 ? 1.3 : 1.0)).round();
      interval = grown > intervalDays + 1 ? grown : intervalDays + 1;
    }
    if (interval > 365) interval = 365;
    return FlashcardSchedule(e, interval, Duration(days: interval));
  }

  /// Etichette dei pulsanti: "1 min", "10 min", "3 gg", "8 gg".
  static Map<String, String> buttonLabels({required double ease, required int intervalDays, required int reviews}) {
    final Map<String, String> labels = <String, String>{};
    for (int grade = 0; grade < 4; grade++) {
      final Duration wait = next(ease: ease, intervalDays: intervalDays, reviews: reviews, grade: grade).wait;
      labels['$grade'] = wait.inMinutes < 60 * 24 ? '${wait.inMinutes} min' : '${wait.inDays} gg';
    }
    return labels;
  }
}
