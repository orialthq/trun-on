import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ori_beauty/domain/models.dart';

void main() {
  test('verbatim live analyze reply survives the app parser', () {
    final raw = File('/tmp/analyze_res.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    try {
      final parsed = StructuredContentAnalysis.fromJson(decoded);
      // ignore: avoid_print
      print('PARSE OK: ${parsed.primaryCategory}');
    } catch (error) {
      fail('PARSE FAILED: $error');
    }
  });
}
