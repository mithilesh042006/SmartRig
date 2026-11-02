const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `1234.5` as `$1,234.50`; [decimals] 0 gives `$1,235`.
String formatMoney(double amount, {int decimals = 2}) {
  final fixed = amount.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return parts.length > 1 ? '\$$grouped.${parts[1]}' : '\$$grouped';
}

/// Amazon listings can lack a price, which is stored as 0.
String formatPrice(double price) =>
    price > 0 ? formatMoney(price) : 'Price unavailable';

String formatDate(DateTime? date) {
  if (date == null) return 'Unknown';
  return '${_months[date.month - 1]} ${date.day}, ${date.year}';
}

String timeAgo(DateTime date, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(date);
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'Just now';
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

/// An error's message without Dart's "Exception:" prefix.
String friendlyError(Object error) =>
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
