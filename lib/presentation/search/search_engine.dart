import '../../domain/note.dart';

class SearchResult {
  final Note note;
  final int score;
  final String snippet;

  const SearchResult({
    required this.note,
    required this.score,
    required this.snippet,
  });
}

class NotesSearchEngine {
  List<SearchResult> search(List<Note> notes, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      // Default: updatedAt descending, snippet = first line
      return notes
          .map((n) => SearchResult(
                note: n,
                score: 0,
                snippet: _firstLine(n.content),
              ))
          .toList();
    }

    final results = <SearchResult>[];

    for (final n in notes) {
      final title = n.title.toLowerCase();
      final content = n.content.toLowerCase();

      final titleIndex = title.indexOf(q);
      final contentIndex = content.indexOf(q);

      if (titleIndex < 0 && contentIndex < 0) continue;

      // Scoring: title match wins big, content match smaller, earlier match better
      int score = 0;
      if (titleIndex >= 0) score += 2000 - titleIndex;
      if (contentIndex >= 0) score += 1000 - contentIndex;

      // Slight boost for shorter titles and recent notes (soft)
      score += (200 - n.title.length).clamp(0, 200);
      final recencyBoost = _recencyBoost(n.updatedAt);
      score += recencyBoost;

      final snippet = _snippetAround(
        original: n.content,
        lower: content,
        q: q,
        matchIndex: contentIndex >= 0 ? contentIndex : 0,
      );

      results.add(SearchResult(note: n, score: score, snippet: snippet));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  int _recencyBoost(DateTime updatedAt) {
    final now = DateTime.now();
    final diff = now.difference(updatedAt).inHours;
    // 0..~72 hours gets some boost, older fades
    if (diff <= 0) return 120;
    if (diff <= 24) return 80;
    if (diff <= 72) return 40;
    return 0;
  }

  String _firstLine(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '—';
    final idx = trimmed.indexOf('\n');
    if (idx < 0) return trimmed;
    return trimmed.substring(0, idx);
  }

  String _snippetAround({
    required String original,
    required String lower,
    required String q,
    required int matchIndex,
  }) {
    final src = original.replaceAll('\n', ' ');
    final srcLower = lower.replaceAll('\n', ' ');

    final idx = srcLower.indexOf(q);
    final useIdx = idx >= 0 ? idx : matchIndex;

    const radius = 42;
    final start = (useIdx - radius).clamp(0, src.length);
    final end = (useIdx + q.length + radius).clamp(0, src.length);

    var snippet = src.substring(start, end).trim();

    if (start > 0) snippet = '… $snippet';
    if (end < src.length) snippet = '$snippet …';

    return snippet.isEmpty ? '—' : snippet;
  }
}
