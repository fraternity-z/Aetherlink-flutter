import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/memory/domain/memory_vector.dart';

void main() {
  group('float32Blob', () {
    test('encodes n floats as a 4n-byte little-endian blob', () {
      final blob = float32Blob(const [1.0, 2.0, 3.5]);
      expect(blob, isA<Uint8List>());
      expect(blob.length, 12);
      // Round-trips back to the same float32 values.
      final view = Float32List.view(blob.buffer);
      expect(view, [1.0, 2.0, 3.5]);
    });

    test('empty vector yields an empty blob', () {
      expect(float32Blob(const []).length, 0);
    });
  });
}
