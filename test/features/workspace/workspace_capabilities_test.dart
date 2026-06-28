// Locks the canWrite contract the SSH-2 editor / file-ops gates rely on: real
// backends (SAF / SSH) are writable; the read-only mock is not. The UI gates on
// this instead of probing the concrete backend type.

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/application/mock_workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/data/local_saf_backend.dart';
import 'package:aetherlink_flutter/features/workspace/data/remote_ssh_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';

void main() {
  test('mock backend is read-only', () {
    expect(MockWorkspaceBackend().capabilities.canWrite, isFalse);
  });

  test('SAF backend is writable', () {
    expect(LocalSafBackend().capabilities.canWrite, isTrue);
  });

  test('SSH backend is writable and remote (capabilities are connection-free)',
      () {
    final backend = RemoteSshBackend(
      'conn-1',
      resolveParams: () async => const SshConnectParams(
        host: 'h',
        port: 22,
        username: 'u',
        authType: SshAuthType.password,
      ),
    );
    final caps = backend.capabilities;
    expect(caps.canWrite, isTrue);
    expect(caps.isRemote, isTrue);
    expect(caps.canWatch, isTrue);
  });
}
