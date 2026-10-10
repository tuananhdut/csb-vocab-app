/// Vietnamese has two accepted tone placements on "oa", "oe" and "uy"
/// ("thủy" vs "thuỷ", "hòa" vs "hoà"). Keyboards and the textbook DB mix
/// both, and they are different code points even when both are NFC, so a
/// plain `LIKE` misses the other spelling.
const _newStyleToOld = {
  'òa': 'oà', 'óa': 'oá', 'ỏa': 'oả', 'õa': 'oã', 'ọa': 'oạ',
  'òe': 'oè', 'óe': 'oé', 'ỏe': 'oẻ', 'õe': 'oẽ', 'ọe': 'oẹ',
  'ùy': 'uỳ', 'úy': 'uý', 'ủy': 'uỷ', 'ũy': 'uỹ', 'ụy': 'uỵ',
};

String _replaceAll(String text, Map<String, String> table) {
  var out = text;
  table.forEach((from, to) => out = out.replaceAll(from, to));
  return out;
}

/// [text] plus its spelling with the tone on the first vowel and with the
/// tone on the second vowel, without duplicates. Always starts with
/// [text] itself.
List<String> toneStyleVariants(String text) {
  final oldToNew = {for (final e in _newStyleToOld.entries) e.value: e.key};
  return {text, _replaceAll(text, _newStyleToOld), _replaceAll(text, oldToNew)}.toList();
}
