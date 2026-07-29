import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dart io async exists', () async {
    final dir = Directory.systemTemp;

    final exists = await dir.exists();

    expect(exists, isTrue);
  });
}
