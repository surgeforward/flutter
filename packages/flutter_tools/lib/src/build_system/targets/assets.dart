// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:pool/pool.dart';

import '../../asset.dart';
import '../../base/file_system.dart';
import '../../devfs.dart';
import '../build_system.dart';

/// The copying logic for flutter assets.
// TODO(jonahwilliams): combine the asset bundle logic with this rule so that
// we can compute the key for deleted assets. This is required to remove assets
// from build directories that are no longer part of the manifest and to unify
// the update/diff logic.
class AssetBehavior extends SourceBehavior {
  const AssetBehavior();

  @override
  List<File> inputs(Environment environment) {
    final AssetBundle assetBundle = AssetBundleFactory.instance.createBundle();
    assetBundle.build(
      manifestPath: environment.projectDir.childFile('pubspec.yaml').path,
      packagesPath: environment.projectDir.childFile('.packages').path,
    );
    final List<File> results = <File>[];
    final Iterable<DevFSFileContent> files = assetBundle.entries.values.whereType<DevFSFileContent>();
    for (DevFSFileContent devFsContent in files) {
      results.add(fs.file(devFsContent.file.path));
    }
    return results;
  }

  @override
  List<File> outputs(Environment environment) {
    final AssetBundle assetBundle = AssetBundleFactory.instance.createBundle();
    assetBundle.build(
      manifestPath: environment.projectDir.childFile('pubspec.yaml').path,
      packagesPath: environment.projectDir.childFile('.packages').path,
    );
    final List<File> results = <File>[];
    for (MapEntry<String, DevFSContent> entry in assetBundle.entries.entries) {
      final File file = fs.file(fs.path.join(environment.buildDir.path, 'flutter_assets', entry.key));
      results.add(file);
    }
    return results;
  }
}

/// Copies the asset files from the [copyAssets] rule into place.
Future<void> copyAssetsInvocation(Map<String, ChangeType> updates, Environment environment) async {
  final Directory output = environment
    .buildDir
    .childDirectory('flutter_assets');
  if (output.existsSync()) {
    output.deleteSync(recursive: true);
  }
  output.createSync(recursive: true);
  final AssetBundle assetBundle = AssetBundleFactory.instance.createBundle();
  await assetBundle.build(
    manifestPath: environment.projectDir.childFile('pubspec.yaml').path,
    packagesPath: environment.projectDir.childFile('.packages').path,
  );
  // Limit number of open files to avoid running out of file descriptors.
  final Pool pool = Pool(64);
  await Future.wait<void>(
    assetBundle.entries.entries.map<Future<void>>((MapEntry<String, DevFSContent> entry) async {
      final PoolResource resource = await pool.request();
      try {
        final File file = fs.file(fs.path.join(output.path, entry.key));
        file.parent.createSync(recursive: true);
        await file.writeAsBytes(await entry.value.contentsAsBytes());
      } finally {
        resource.release();
      }
    }));
}

/// Copy the assets used in the application into a build directory.
const Target copyAssets = Target(
  name: 'copy_assets',
  inputs: <Source>[
    Source.pattern('{PROJECT_DIR}/pubspec.yaml'),
    Source.behavior(AssetBehavior()),
  ],
  outputs: <Source>[
    Source.pattern('{BUILD_DIR}/flutter_assets/AssetManifest.json'),
    Source.pattern('{BUILD_DIR}/flutter_assets/FontManifest.json'),
    Source.pattern('{BUILD_DIR}/flutter_assets/LICENSE'),
    Source.behavior(AssetBehavior()), // <- everything in this subdirectory.
  ],
  dependencies: <Target>[],
  buildAction: copyAssetsInvocation,
);
