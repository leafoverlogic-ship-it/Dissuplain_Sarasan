String resolveClientDetailValue(
  Map<String, dynamic> map,
  List<String> candidates,
) {
  for (final key in candidates) {
    final raw = map[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

String normalizeVisitFrequencyValue(String? value) {
  final text = (value ?? '').toString().trim();
  if (text.isEmpty) return '';

  final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) return '';

  final number = int.tryParse(digitsOnly);
  if (number == null) return '';

  if (number <= 0) return '0';

  final nearest = ((number / 7).round()) * 7;
  return nearest.toString();
}
