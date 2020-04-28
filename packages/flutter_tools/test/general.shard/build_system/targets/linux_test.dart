// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/targets/dart.dart';
import 'package:flutter_tools/src/build_system/targets/linux.dart';
import 'package:mockito/mockito.dart';

import '../../../src/common.dart';
import '../../../src/context.dart';

void main() {
  testWithoutContext('Copies files to correct cache directory, excluding unrelated code', () async {
    final FileSystem fileSystem = MemoryFileSystem.test();
    setUpCacheDirectory(fileSystem);
    final MockArtifacts mockArtifacts = MockArtifacts();
    when(mockArtifacts.getArtifactPath(
      Artifact.linuxDesktopPath,
      mode: anyNamed('mode'),
      platform: anyNamed('platform'),
    )).thenReturn('linux-x64');
    when(mockArtifacts.getArtifactPath(
      Artifact.linuxCppClientWrapper,
      mode: anyNamed('mode'),
      platform: anyNamed('platform'),
    )).thenReturn('linux-x64/cpp_client_wrapper_glfw');

    final Environment testEnvironment = Environment.test(
      fileSystem.currentDirectory,
      defines: <String, String>{
        kBuildMode: 'debug',
      },
      artifacts: mockArtifacts,
      processManager: FakeProcessManager.any(),
      fileSystem: fileSystem,
      logger: BufferLogger.test(),
    );
    testEnvironment.buildDir.createSync(recursive: true);

    await const UnpackLinux().build(testEnvironment);

    expect(fileSystem.file('linux/flutter/ephemeral/libflutter_linux_glfw.so'), exists);
    expect(fileSystem.file('linux/flutter/ephemeral/flutter_export.h'), exists);
    expect(fileSystem.file('linux/flutter/ephemeral/flutter_messenger.h'), exists);
    expect(fileSystem.file('linux/flutter/ephemeral/flutter_plugin_registrar.h'), exists);
    expect(fileSystem.file('linux/flutter/ephemeral/flutter_glfw.h'), exists);
    expect(fileSystem.file('linux/flutter/ephemeral/icudtl.dat'), exists);
    expect(fileSystem.file('linux/flutter/ephemeral/cpp_client_wrapper_glfw/foo'), exists);
    expect(fileSystem.file('linux/flutter/ephemeral/unrelated-stuff'), isNot(exists));
  });

  // Only required for the test below that still depends on the context.
  FileSystem fileSystem;
  setUp(() {
    fileSystem = MemoryFileSystem.test();
  });

  testUsingContext('DebugBundleLinuxAssets copies artifacts to out directory', () async {
    final Environment testEnvironment = Environment.test(
      fileSystem.currentDirectory,
      defines: <String, String>{
        kBuildMode: 'debug',
      },
      artifacts: MockArtifacts(),
      processManager: FakeProcessManager.any(),
      fileSystem: fileSystem,
      logger: BufferLogger.test(),
    );

    testEnvironment.buildDir.createSync(recursive: true);

    // Create input files.
    testEnvironment.buildDir.childFile('app.dill').createSync();

    await const DebugBundleLinuxAssets().build(testEnvironment);
    final Directory output = testEnvironment.outputDir
      .childDirectory('flutter_assets');

    expect(output.childFile('kernel_blob.bin'), exists);
    expect(output.childFile('AssetManifest.json'), exists);
    // No bundled fonts
    expect(output.childFile('FontManifest.json'), isNot(exists));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => FakeProcessManager.any(),
  });
}

void setUpCacheDirectory(FileSystem fileSystem) {
  fileSystem.file('linux-x64/unrelated-stuff').createSync(recursive: true);
  fileSystem.file('linux-x64/libflutter_linux_glfw.so').createSync(recursive: true);
  fileSystem.file('linux-x64/flutter_export.h').createSync();
  fileSystem.file('linux-x64/flutter_messenger.h').createSync();
  fileSystem.file('linux-x64/flutter_plugin_registrar.h').createSync();
  fileSystem.file('linux-x64/flutter_glfw.h').createSync();
  fileSystem.file('linux-x64/icudtl.dat').createSync();
  fileSystem.file('linux-x64/cpp_client_wrapper_glfw/foo').createSync(recursive: true);
  fileSystem.file('packages/flutter_tools/lib/src/build_system/targets/linux.dart').createSync(recursive: true);
}

class MockArtifacts extends Mock implements Artifacts {}
