import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_credential_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

/// Shared "create an SSH connection + its workspace" helpers, factored out of
/// the SSH connection form so the Termux one-tap flow (设计文档 §10.5 / Termux-A)
/// reuses the exact same persist path instead of copy-pasting it.

/// Persists a new [SshConnection] profile and its secret. The profile (non-
/// secret) lands in the connections list; the secret goes to the separate
/// credential KV that is excluded from backup export (设计文档 §5.2). Returns the
/// stored profile (with its minted id + credentialKeyId).
///
/// Takes the two notifiers directly (rather than a `WidgetRef`) so it is plain
/// to unit-test with a `ProviderContainer`.
Future<SshConnection> persistSshConnection({
  required SshConnectionStore connections,
  required SshCredentialStore credentials,
  required String label,
  required SshConnectParams params,
  String? fingerprint,
}) async {
  final connection = await connections.add(
    label: label,
    host: params.host,
    port: params.port,
    username: params.username,
    authType: params.authType,
    hostKeyFingerprint: fingerprint,
  );
  await credentials.save(
    connection.credentialKeyId,
    SshCredential(
      password: params.password,
      privateKeyPem: params.privateKeyPem,
      passphrase: params.passphrase,
    ),
  );
  return connection;
}

/// Opens (or refreshes) a workspace pointing at [connection] rooted at [root]
/// and switches into it (clearing open tabs so the shell lands on the tree).
/// Shared by the SSH form (create / reuse) and the Termux flow; [backendType]
/// distinguishes a Termux workspace from a plain SSH one for display.
Future<Workspace> openAndSwitchSshWorkspace(
  WidgetRef ref,
  SshConnection connection, {
  required String root,
  WorkspaceBackendType backendType = WorkspaceBackendType.ssh,
}) async {
  final workspace = await ref.read(workspaceStoreProvider.notifier).open(
        name: connection.label,
        backendType: backendType,
        root: root,
        displayPath: '${connection.username}@${connection.host}:$root',
        connectionId: connection.id,
      );
  ref.read(currentWorkspaceProvider.notifier).open(workspace);
  ref.read(openWorkspaceFilesProvider.notifier).reset();
  return workspace;
}
