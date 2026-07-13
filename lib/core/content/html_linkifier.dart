String linkifyPlainUrls(String html) {
  if (html.isEmpty || !html.contains(RegExp(r'https?://'))) return html;

  final output = StringBuffer();
  final blockedTags = <String>[];
  final tagPattern = RegExp(r'<[^>]*>');
  var cursor = 0;

  for (final match in tagPattern.allMatches(html)) {
    final text = html.substring(cursor, match.start);
    output.write(blockedTags.isEmpty ? _linkifyText(text) : text);

    final tag = match.group(0)!;
    output.write(tag);
    _updateBlockedTags(tag, blockedTags);
    cursor = match.end;
  }

  final remainder = html.substring(cursor);
  output.write(blockedTags.isEmpty ? _linkifyText(remainder) : remainder);
  return output.toString();
}

String resolveHtmlLinkTarget({
  String? callbackUrl,
  Map<String, String>? attributes,
  String? visibleText,
}) {
  final candidates = [attributes?['href'], callbackUrl, visibleText]
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty);

  for (final candidate in candidates) {
    final uri = Uri.tryParse(candidate);
    if (uri != null && uri.scheme.isNotEmpty) return candidate;
  }

  return candidates.isEmpty ? '' : candidates.first;
}

String _linkifyText(String text) {
  final urlPattern = RegExp(r'''https?://[^\s<>"']+''', caseSensitive: false);
  final output = StringBuffer();
  var cursor = 0;

  for (final match in urlPattern.allMatches(text)) {
    output.write(text.substring(cursor, match.start));

    final captured = match.group(0)!;
    final split = _splitTrailingPunctuation(captured);
    output.write('<a href="${split.url}">${split.url}</a>${split.trailing}');
    cursor = match.end;
  }

  output.write(text.substring(cursor));
  return output.toString();
}

({String url, String trailing}) _splitTrailingPunctuation(String value) {
  const punctuation = '.,;:!?)]}';
  var end = value.length;

  while (end > 0 && punctuation.contains(value[end - 1])) {
    end--;
  }

  return (url: value.substring(0, end), trailing: value.substring(end));
}

void _updateBlockedTags(String tag, List<String> blockedTags) {
  final match = RegExp(
    r'^<\s*(/)?\s*([a-z0-9]+)',
    caseSensitive: false,
  ).firstMatch(tag);
  if (match == null) return;

  final name = match.group(2)!.toLowerCase();
  const blocked = {'a', 'script', 'style', 'code', 'pre'};
  if (!blocked.contains(name)) return;

  final closing = match.group(1) != null;
  if (closing) {
    final index = blockedTags.lastIndexOf(name);
    if (index >= 0) blockedTags.removeAt(index);
    return;
  }

  if (!tag.trimRight().endsWith('/>')) blockedTags.add(name);
}
