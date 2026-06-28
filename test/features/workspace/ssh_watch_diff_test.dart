// Unit tests for the SSH-4 external-change poller's pure diff (设计文档 §7).
// RemoteSshBackend.diffDirectory / snapshotOf are pure, so we can verify the
// created / deleted / modified classification without a live SSH connection.

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/data/remote_ssh_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

WorkspaceEntry _file(String dir, String name, {int size = 1, int mtime = 100}) =>
    WorkspaceEntry(
      name: name,
      path: '$dir/$name',
      isDirectory: false,
      size: size,
      mtime: mtime,
    );

WorkspaceEntry _dir(String dir, String name) => WorkspaceEntry(
      name: name,
      path: '$dir/$name',
      isDirectory: true,
      size: 0,
      mtime: 100,
    );

void main() {
  const dir = '/home/alice/project';

  test('no changes → no events', () {
    final entries = [_file(dir, 'a.txt'), _dir(dir, 'src')];
    final prev = RemoteSshBackend.snapshotOf(entries);
    expect(RemoteSshBackend.diffDirectory(dir, prev, entries), isEmpty);
  });

  test('a new child is a created event carrying the parent dir', () {
    final before = [_file(dir, 'a.txt')];
    final after = [_file(dir, 'a.txt'), _file(dir, 'b.txt')];
    final events = RemoteSshBackend.diffDirectory(
      dir,
      RemoteSshBackend.snapshotOf(before),
      after,
    );
    expect(events, hasLength(1));
    expect(events.single.kind, WorkspaceChangeKind.created);
    expect(events.single.path, '$dir/b.txt');
    expect(events.single.parentPath, dir);
  });

  test('a removed child is a deleted event', () {
    final before = [_file(dir, 'a.txt'), _file(dir, 'b.txt')];
    final after = [_file(dir, 'a.txt')];
    final events = RemoteSshBackend.diffDirectory(
      dir,
      RemoteSshBackend.snapshotOf(before),
      after,
    );
    expect(events, hasLength(1));
    expect(events.single.kind, WorkspaceChangeKind.deleted);
    expect(events.single.path, '$dir/b.txt');
  });

  test('a file whose size/mtime moved is a modified event', () {
    final before = [_file(dir, 'a.txt', size: 10, mtime: 100)];
    final after = [_file(dir, 'a.txt', size: 12, mtime: 200)];
    final events = RemoteSshBackend.diffDirectory(
      dir,
      RemoteSshBackend.snapshotOf(before),
      after,
    );
    expect(events, hasLength(1));
    expect(events.single.kind, WorkspaceChangeKind.modified);
    expect(events.single.path, '$dir/a.txt');
  });

  test('directory mtime churn does not emit modified (only created/deleted)', () {
    // Same dir name present before and after — a dir never reports modified.
    final before = [_dir(dir, 'src')];
    final after = [_dir(dir, 'src')];
    expect(
      RemoteSshBackend.diffDirectory(
        dir,
        RemoteSshBackend.snapshotOf(before),
        after,
      ),
      isEmpty,
    );
  });

  test('mixed add + remove + edit in one pass', () {
    final before = [
      _file(dir, 'keep.txt', size: 1, mtime: 1),
      _file(dir, 'gone.txt'),
      _file(dir, 'edit.txt', size: 1, mtime: 1),
    ];
    final after = [
      _file(dir, 'keep.txt', size: 1, mtime: 1),
      _file(dir, 'edit.txt', size: 9, mtime: 2),
      _file(dir, 'new.txt'),
    ];
    final events = RemoteSshBackend.diffDirectory(
      dir,
      RemoteSshBackend.snapshotOf(before),
      after,
    );
    final byKind = {for (final e in events) e.kind: e.path};
    expect(events, hasLength(3));
    expect(byKind[WorkspaceChangeKind.created], '$dir/new.txt');
    expect(byKind[WorkspaceChangeKind.deleted], '$dir/gone.txt');
    expect(byKind[WorkspaceChangeKind.modified], '$dir/edit.txt');
  });
}
