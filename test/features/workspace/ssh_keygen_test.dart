// Tests the pure-Dart Ed25519 keygen used by the Termux one-tap flow
// (设计文档 §10.5 / Termux-A). The critical property is that dartssh2 — the
// library that actually authenticates at connect time — can parse the PEM we
// generate, so we round-trip the output through SSHKeyPair.fromPem here.
//
// dartssh2 is imported in this *test* on purpose: the import-boundary guard
// (ssh_import_boundary_test.dart) only scans lib/, and the whole point is to
// prove byte-compatibility with the real consumer.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/ssh_keygen.dart';

void main() {
  group('SshKeygen.generateEd25519', () {
    test('emits an OpenSSH private key PEM and an authorized_keys line', () {
      final pair = SshKeygen.generateEd25519();

      expect(
        pair.privateKeyPem,
        startsWith('-----BEGIN OPENSSH PRIVATE KEY-----'),
      );
      expect(pair.privateKeyPem.trim(), endsWith('-----END OPENSSH PRIVATE KEY-----'));

      final parts = pair.authorizedKeyLine.split(' ');
      expect(parts, hasLength(3));
      expect(parts[0], 'ssh-ed25519');
      expect(parts[2], 'aetherlink@termux');
      // The middle field is base64 of an ssh wire blob beginning with the type.
      final blob = base64.decode(parts[1]);
      expect(
        utf8.decode(blob.sublist(4, 4 + 'ssh-ed25519'.length)),
        'ssh-ed25519',
      );
    });

    test('the PEM round-trips through dartssh2 and can sign', () {
      final pair = SshKeygen.generateEd25519();

      final keys = SSHKeyPair.fromPem(pair.privateKeyPem);
      expect(keys, hasLength(1));

      // A usable private key signs without throwing — this is what password-less
      // login relies on.
      final signature = keys.single.sign(Uint8List.fromList([1, 2, 3, 4]));
      expect(signature.encode(), isNotEmpty);
    });

    test('honours a custom comment', () {
      final pair = SshKeygen.generateEd25519(comment: 'me@phone');
      expect(pair.authorizedKeyLine, endsWith(' me@phone'));
      expect(SSHKeyPair.fromPem(pair.privateKeyPem), hasLength(1));
    });

    test('successive calls produce distinct keys', () {
      final a = SshKeygen.generateEd25519();
      final b = SshKeygen.generateEd25519();
      expect(a.privateKeyPem, isNot(b.privateKeyPem));
      expect(a.authorizedKeyLine, isNot(b.authorizedKeyLine));
    });
  });
}
