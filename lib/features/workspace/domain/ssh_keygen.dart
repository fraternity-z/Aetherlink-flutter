import 'dart:convert';

import 'package:pinenacl/ed25519.dart';

/// A freshly generated SSH key pair, rendered as the two text artifacts the
/// Termux one-tap flow needs (设计文档 §10.5 / Termux-A):
///
/// - [privateKeyPem]        : OpenSSH-format private key (`-----BEGIN OPENSSH
///   PRIVATE KEY-----`). Stored in the credential KV (excluded from backup,
///   §5.2) and handed to dartssh2's `SSHKeyPair.fromPem` at connect time.
/// - [authorizedKeyLine]    : the single-line public key (`ssh-ed25519 AAAA…
///   comment`) baked into the setup script and appended to Termux's
///   `~/.ssh/authorized_keys` for password-less login.
///
/// **Only the public half ever leaves the device.** The private key never goes
/// into the script.
class SshGeneratedKeyPair {
  const SshGeneratedKeyPair({
    required this.privateKeyPem,
    required this.authorizedKeyLine,
  });

  final String privateKeyPem;
  final String authorizedKeyLine;
}

/// Generates SSH key pairs for the Termux one-tap setup.
///
/// dartssh2 has no key-generation API, so this builds the artifacts by hand:
/// the raw Ed25519 pair comes from `pinenacl` (the very library dartssh2 uses
/// for `ssh-ed25519`, guaranteeing byte-compatibility with
/// `SSHKeyPair.fromPem`), and the OpenSSH wire/PEM encoding is assembled here.
///
/// Kept **pure and dartssh2-free** (so it stays out of the dartssh2 import
/// boundary, 设计文档 §11) and fully unit-testable — a test round-trips the
/// output through dartssh2 to prove the PEM actually authenticates.
abstract final class SshKeygen {
  static const String _keyType = 'ssh-ed25519';

  /// Generates a new Ed25519 key pair tagged with [comment] (shown after the
  /// public key, e.g. `aetherlink@termux`).
  static SshGeneratedKeyPair generateEd25519({
    String comment = 'aetherlink@termux',
  }) {
    final signing = SigningKey.generate();
    // pinenacl lays the signing key out as seed(32) || publicKey(32) — exactly
    // the OpenSSH ed25519 private blob — and exposes the bare 32-byte public key
    // via verifyKey.
    final publicKey = Uint8List.fromList(signing.verifyKey);
    final privateKey = Uint8List.fromList(signing); // 64 bytes (seed || pub)

    final publicBlob = _encodeEd25519PublicBlob(publicKey);
    return SshGeneratedKeyPair(
      privateKeyPem: _encodeOpenSshPrivateKey(
        publicBlob: publicBlob,
        publicKey: publicKey,
        privateKey: privateKey,
        comment: comment,
      ),
      authorizedKeyLine:
          '$_keyType ${base64.encode(publicBlob)} $comment',
    );
  }

  // The SSH public key blob: string("ssh-ed25519") + string(pubkey). This is
  // what gets base64'd into both the authorized_keys line and the embedded
  // public key inside the private PEM.
  static Uint8List _encodeEd25519PublicBlob(Uint8List publicKey) {
    final w = _SshWireWriter()
      ..writeString(utf8.encode(_keyType))
      ..writeString(publicKey);
    return w.toBytes();
  }

  // Builds the `openssh-key-v1` private key container and PEM-wraps it. Mirrors
  // the format dartssh2 itself emits in OpenSSHKeyPairs.toPem (unencrypted,
  // cipher/kdf = "none"), so the result parses straight back via
  // SSHKeyPair.fromPem.
  static String _encodeOpenSshPrivateKey({
    required Uint8List publicBlob,
    required Uint8List publicKey,
    required Uint8List privateKey,
    required String comment,
  }) {
    // The unencrypted private section, identical check ints front the block so
    // openssh can sanity-check a successful decrypt.
    const checkInt = 0x12345678;
    final priv = _SshWireWriter()
      ..writeUint32(checkInt)
      ..writeUint32(checkInt)
      ..writeString(utf8.encode(_keyType))
      ..writeString(publicKey)
      ..writeString(privateKey)
      ..writeString(utf8.encode(comment));
    // Pad with 1,2,3,… up to the "none" cipher block size (8).
    var pad = 1;
    while (priv.length % 8 != 0) {
      priv.writeByte(pad++);
    }

    final container = _SshWireWriter()
      ..writeRaw(utf8.encode('openssh-key-v1'))
      ..writeByte(0) // null terminator of the magic
      ..writeString(utf8.encode('none')) // cipher
      ..writeString(utf8.encode('none')) // kdf
      ..writeString(const []) // kdf options (empty)
      ..writeUint32(1) // number of keys
      ..writeString(publicBlob)
      ..writeString(priv.toBytes());

    return _pemWrap('OPENSSH PRIVATE KEY', container.toBytes());
  }

  // 64-char-per-line base64, BEGIN/END framed (the canonical OpenSSH layout).
  static String _pemWrap(String type, Uint8List content) {
    final encoded = base64.encode(content);
    final buffer = StringBuffer()..writeln('-----BEGIN $type-----');
    for (var i = 0; i < encoded.length; i += 70) {
      buffer.writeln(
        encoded.substring(i, i + 70 > encoded.length ? encoded.length : i + 70),
      );
    }
    buffer.writeln('-----END $type-----');
    return buffer.toString();
  }
}

/// Minimal big-endian SSH wire writer (uint32-length-prefixed strings), enough
/// to assemble the OpenSSH key blobs above without pulling in dartssh2.
class _SshWireWriter {
  final BytesBuilder _b = BytesBuilder(copy: false);

  int get length => _b.length;

  void writeByte(int value) => _b.addByte(value & 0xff);

  void writeRaw(List<int> bytes) => _b.add(bytes);

  void writeUint32(int value) {
    _b.add([
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ]);
  }

  void writeString(List<int> bytes) {
    writeUint32(bytes.length);
    _b.add(bytes);
  }

  Uint8List toBytes() => _b.toBytes();
}
