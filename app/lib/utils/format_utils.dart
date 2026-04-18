/// Formats a number as a PKR currency string with comma separators.
/// e.g. 12500 → "PKR 12,500"  |  1500000 → "PKR 1,500,000"
String formatPKR(num amount) {
  final n = amount.round().toString();
  final buf = StringBuffer();
  final start = n.length % 3;
  if (start > 0) buf.write(n.substring(0, start));
  for (int i = start; i < n.length; i += 3) {
    if (buf.isNotEmpty) buf.write(',');
    buf.write(n.substring(i, i + 3));
  }
  return 'PKR ${buf.toString()}';
}

/// Returns only the formatted number with commas, no "PKR" prefix.
/// e.g. 12500 → "12,500"
String fmtNum(num amount) {
  final n = amount.round().toString();
  final buf = StringBuffer();
  final start = n.length % 3;
  if (start > 0) buf.write(n.substring(0, start));
  for (int i = start; i < n.length; i += 3) {
    if (buf.isNotEmpty) buf.write(',');
    buf.write(n.substring(i, i + 3));
  }
  return buf.toString();
}
