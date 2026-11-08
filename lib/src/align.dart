/// Which letter of one word becomes which letter of another.
///
/// A weighted edit distance: a letter kept as itself costs nothing, a letter
/// morphing into another costs a little less than one growing in or
/// shrinking away, and a letter never morphs into a space. So most letters
/// morph into the letter at the same place (`Amethyst` into `Citrine`), as
/// few as possible appear or vanish (only the length difference, usually),
/// and a word slides only when that keeps many letters as themselves (`Ruby`
/// into `bRuby`).
///
/// Returns one entry per pair, in order: an index into [a], into [b], or
/// both.
List<(int?, int?)> alignLetters(List<int> a, List<int> b) {
  const gap = 1.0;
  double change(int x, int y) {
    if (x == y) return 0;
    final space = _isSpace(x), otherSpace = _isSpace(y);
    if (space || otherSpace) return space && otherSpace ? 0 : 3 * gap;
    if (String.fromCharCode(x).toLowerCase() ==
        String.fromCharCode(y).toLowerCase()) {
      return .4;
    }
    return .9;
  }

  final n = a.length, m = b.length;
  // cost[i][j]: aligning a[i..] with b[j..].
  final cost = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
  for (var i = n; i >= 0; i--) {
    for (var j = m; j >= 0; j--) {
      if (i == n && j == m) continue;
      var best = double.infinity;
      if (i < n && j < m) best = change(a[i], b[j]) + cost[i + 1][j + 1];
      if (i < n) best = _min(best, gap + cost[i + 1][j]);
      if (j < m) best = _min(best, gap + cost[i][j + 1]);
      cost[i][j] = best;
    }
  }
  final pairs = <(int?, int?)>[];
  var i = 0, j = 0;
  const eps = 1e-9;
  while (i < n || j < m) {
    // Prefer pairing, then letting a's letter go, then b's growing in.
    if (i < n &&
        j < m &&
        (cost[i][j] - change(a[i], b[j]) - cost[i + 1][j + 1]).abs() < eps) {
      pairs.add((i++, j++));
    } else if (i < n && (cost[i][j] - gap - cost[i + 1][j]).abs() < eps) {
      pairs.add((i++, null));
    } else {
      pairs.add((null, j++));
    }
  }
  return pairs;
}

bool _isSpace(int rune) => String.fromCharCode(rune).trim().isEmpty;

double _min(double x, double y) => x < y ? x : y;
