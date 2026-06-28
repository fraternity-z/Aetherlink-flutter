// Tests the shared SSH persist helper (ssh_workspace_setup.dart) that both the
// SSH connection form and the Termux one-tap flow use to create a connection +
// store its secret. Runs against the in-memory Drift harness (设计文档 §5.2: the
// secret lands under the separate credential KV).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_credential_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_workspace_setup.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';

void main() {
  ProviderContainer makeContainer() {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(ChatRepositoryImpl(db)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('persistSshConnection creates a profile and stores its private key',
      () async {
    final c = makeContainer();
    await c.read(sshConnectionStoreProvider.future);
    final connections = c.read(sshConnectionStoreProvider.notifier);
    final credentials = c.read(sshCredentialStoreProvider.notifier);

    const params = SshConnectParams(
      host: '127.0.0.1',
      port: 8022,
      username: 'termux',
      authType: SshAuthType.privateKey,
      privateKeyPem: '-----BEGIN OPENSSH PRIVATE KEY-----\nXX\n-----END OPENSSH PRIVATE KEY-----\n',
    );

    final conn = await persistSshConnection(
      connections: connections,
      credentials: credentials,
      label: 'Termux',
      params: params,
      fingerprint: 'SHA256:abc',
    );

    // Profile stored (non-secret) with the typed-in host/port/auth.
    final stored = connections.byId(conn.id);
    expect(stored, isNotNull);
    expect(stored!.host, '127.0.0.1');
    expect(stored.port, 8022);
    expect(stored.authType, SshAuthType.privateKey);
    expect(stored.hostKeyFingerprint, 'SHA256:abc');
    expect(stored.credentialKeyId, isNotEmpty);

    // Secret stored separately, keyed by the minted credentialKeyId.
    final secret = await credentials.read(conn.credentialKeyId);
    expect(secret?.privateKeyPem, params.privateKeyPem);
    expect(secret?.password, isNull);
  });
}
