String formatWon(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return '$buffer원';
}

String formatCaptureTime(DateTime value) {
  final now = DateTime.now();
  final sameDay =
      now.year == value.year &&
      now.month == value.month &&
      now.day == value.day;
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  if (sameDay) {
    return '오늘 $hour:$minute';
  }
  return '${value.month}월 ${value.day}일 $hour:$minute';
}
