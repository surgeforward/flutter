// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/web/chrome.dart';
import 'package:flutter_tools/src/web/web_device.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/testbed.dart';

void main() {
  testWithoutContext('No web devices listed if feature is disabled', () async {
    final WebDevices webDevices = WebDevices(
      featureFlags: TestFeatureFlags(isWebEnabled: false),
      fileSystem: MemoryFileSystem.test(),
      logger: BufferLogger.test(),
      platform: FakePlatform(
        operatingSystem: 'linux',
        environment: <String, String>{}
      ),
      processManager:  FakeProcessManager.any(),
    );

    expect(await webDevices.pollingGetDevices(), isEmpty);
  });

  testWithoutContext('GoogleChromeDevice defaults', () async {
    final GoogleChromeDevice chromeDevice = GoogleChromeDevice(
      chromiumLauncher: null,
      fileSystem: MemoryFileSystem.test(),
      logger: BufferLogger.test(),
      platform: FakePlatform(operatingSystem: 'linux'),
      processManager: FakeProcessManager.any(),
    );

    expect(chromeDevice.name, 'Chrome');
    expect(chromeDevice.id, 'chrome');
    expect(chromeDevice.supportsHotReload, true);
    expect(chromeDevice.supportsHotRestart, true);
    expect(chromeDevice.supportsStartPaused, true);
    expect(chromeDevice.supportsFlutterExit, true);
    expect(chromeDevice.supportsScreenshot, false);
    expect(await chromeDevice.isLocalEmulator, false);
    expect(chromeDevice.getLogReader(), isA<NoOpDeviceLogReader>());
    expect(chromeDevice.getLogReader(), isA<NoOpDeviceLogReader>());
    expect(await chromeDevice.portForwarder.forward(1), 1);
  });

  testWithoutContext('MicrosoftEdge defaults', () async {
    final MicrosoftEdgeDevice chromeDevice = MicrosoftEdgeDevice(
      chromiumLauncher: null,
      fileSystem: MemoryFileSystem.test(),
      logger: BufferLogger.test(),
    );

    expect(chromeDevice.name, 'Edge');
    expect(chromeDevice.id, 'edge');
    expect(chromeDevice.supportsHotReload, true);
    expect(chromeDevice.supportsHotRestart, true);
    expect(chromeDevice.supportsStartPaused, true);
    expect(chromeDevice.supportsFlutterExit, true);
    expect(chromeDevice.supportsScreenshot, false);
    expect(await chromeDevice.isLocalEmulator, false);
    expect(chromeDevice.getLogReader(), isA<NoOpDeviceLogReader>());
    expect(chromeDevice.getLogReader(), isA<NoOpDeviceLogReader>());
    expect(await chromeDevice.portForwarder.forward(1), 1);
  });

  testWithoutContext('Server defaults', () async {
    final WebServerDevice device = WebServerDevice(
      logger: BufferLogger.test(),
    );

    expect(device.name, 'Web Server');
    expect(device.id, 'web-server');
    expect(device.supportsHotReload, true);
    expect(device.supportsHotRestart, true);
    expect(device.supportsStartPaused, true);
    expect(device.supportsFlutterExit, true);
    expect(device.supportsScreenshot, false);
    expect(await device.isLocalEmulator, false);
    expect(device.getLogReader(), isA<NoOpDeviceLogReader>());
    expect(device.getLogReader(), isA<NoOpDeviceLogReader>());
    expect(await device.portForwarder.forward(1), 1);
  });

  testWithoutContext('Chrome device is listed when Chrome can be run', () async {
    final WebDevices webDevices = WebDevices(
      featureFlags: TestFeatureFlags(isWebEnabled: true),
      fileSystem: MemoryFileSystem.test(),
      logger: BufferLogger.test(),
      platform: FakePlatform(
        operatingSystem: 'linux',
        environment: <String, String>{}
      ),
      processManager:  FakeProcessManager.any(),
    );

    expect(await webDevices.pollingGetDevices(),
      contains(isA<GoogleChromeDevice>()));
  });

  testWithoutContext('Chrome device is not listed when Chrome cannot be run', () async {
    final MockProcessManager processManager = MockProcessManager();
    when(processManager.canRun(any)).thenReturn(false);
    final WebDevices webDevices = WebDevices(
      featureFlags: TestFeatureFlags(isWebEnabled: true),
      fileSystem: MemoryFileSystem.test(),
      logger: BufferLogger.test(),
      platform: FakePlatform(
        operatingSystem: 'linux',
        environment: <String, String>{}
      ),
      processManager: processManager,
    );

    expect(await webDevices.pollingGetDevices(),
      isNot(contains(isA<GoogleChromeDevice>())));
  });

  testWithoutContext('Web Server device is listed by default', () async {
    final WebDevices webDevices = WebDevices(
      featureFlags: TestFeatureFlags(isWebEnabled: true),
      fileSystem: MemoryFileSystem.test(),
      logger: BufferLogger.test(),
      platform: FakePlatform(
        operatingSystem: 'linux',
        environment: <String, String>{}
      ),
      processManager: FakeProcessManager.any(),
    );

    expect(await webDevices.pollingGetDevices(),
      contains(isA<WebServerDevice>()));
  });

  testWithoutContext('Chrome invokes version command on non-Windows platforms', () async {
    final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
      const FakeCommand(
        command: <String>[
          kLinuxExecutable,
          '--version',
        ],
        stdout: 'ABC'
      )
    ]);
    final WebDevices webDevices = WebDevices(
      featureFlags: TestFeatureFlags(isWebEnabled: true),
      fileSystem: MemoryFileSystem.test(),
      logger: BufferLogger.test(),
      platform: FakePlatform(
        operatingSystem: 'linux',
        environment: <String, String>{}
      ),
      processManager: processManager,
    );


    final GoogleChromeDevice chromeDevice = (await webDevices.pollingGetDevices())
      .whereType<GoogleChromeDevice>().first;

    expect(chromeDevice.isSupported(), true);
    expect(await chromeDevice.sdkNameAndVersion, 'ABC');

    // Verify caching works correctly.
    expect(await chromeDevice.sdkNameAndVersion, 'ABC');
    expect(processManager.hasRemainingExpectations, false);
  });

  testWithoutContext('Chrome version check invokes registry query on windows.', () async {
    final FakeProcessManager processManager = FakeProcessManager.list(<FakeCommand>[
      const FakeCommand(
        command: <String>[
          'reg',
          'query',
          r'HKEY_CURRENT_USER\Software\Google\Chrome\BLBeacon',
          '/v',
          'version',
        ],
        stdout: r'HKEY_CURRENT_USER\Software\Google\Chrome\BLBeacon\ version REG_SZ 74.0.0 A',
      )
    ]);
    final WebDevices webDevices = WebDevices(
      featureFlags: TestFeatureFlags(isWebEnabled: true),
      fileSystem: MemoryFileSystem.test(),
      logger: BufferLogger.test(),
      platform: FakePlatform(
        operatingSystem: 'windows',
        environment: <String, String>{}
      ),
      processManager: processManager,
    );


    final GoogleChromeDevice chromeDevice = (await webDevices.pollingGetDevices())
      .whereType<GoogleChromeDevice>().first;

    expect(chromeDevice.isSupported(), true);
    expect(await chromeDevice.sdkNameAndVersion, 'Google Chrome 74.0.0');

    // Verify caching works correctly.
    expect(await chromeDevice.sdkNameAndVersion, 'Google Chrome 74.0.0');
    expect(processManager.hasRemainingExpectations, false);
  });
}

// This is used to set `canRun` to false in a test.
class MockProcessManager extends Mock implements ProcessManager {}
