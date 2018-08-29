// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';

import 'package:flutter_tools/src/asset.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/cache.dart';

import 'src/common.dart';
import 'src/context.dart';

void main() {
  void writePubspecFile(String path, String name, {String fontsSection}) {
    if (fontsSection == null) {
      fontsSection = '';
    } else {
      fontsSection = '''
flutter:
     fonts:
$fontsSection
''';
    }

    fs.file(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('''
name: $name
dependencies:
  flutter:
    sdk: flutter
$fontsSection
''');
  }

  void establishFlutterRoot() {
    // Setting flutterRoot here so that it picks up the MemoryFileSystem's
    // path separator.
    Cache.flutterRoot = getFlutterRoot();
  }

  void writePackagesFile(String packages) {
    fs.file('.packages')
      ..createSync()
      ..writeAsStringSync(packages);
  }

  Future<Null> buildAndVerifyFonts(
    List<String> localFonts,
    List<String> packageFonts,
    List<String> packages,
    String expectedAssetManifest,
  ) async {
    final AssetBundle bundle = AssetBundleFactory.instance.createBundle();
    await bundle.build(manifestPath: 'pubspec.yaml');

    for (String packageName in packages) {
      for (String packageFont in packageFonts) {
        final String entryKey = 'packages/$packageName/$packageFont';
        expect(bundle.entries.containsKey(entryKey), true);
        expect(
          utf8.decode(await bundle.entries[entryKey].contentsAsBytes()),
          packageFont,
        );
      }

      for (String localFont in localFonts) {
        expect(bundle.entries.containsKey(localFont), true);
        expect(
          utf8.decode(await bundle.entries[localFont].contentsAsBytes()),
          localFont,
        );
      }
    }

    expect(
      utf8.decode(await bundle.entries['FontManifest.json'].contentsAsBytes()),
      expectedAssetManifest,
    );
  }

  void writeFontAsset(String path, String font) {
    fs.file('$path$font')
      ..createSync(recursive: true)
      ..writeAsStringSync(font);
  }

  // These tests do not use a memory file system because we want to ensure that
  // asset bundles work correctly on Windows and Posix systems.
  Directory tempDir;
  Directory oldCurrentDir;

  setUp(() async {
    tempDir = fs.systemTempDirectory.createTempSync('flutter_asset_bundle_test.');
    oldCurrentDir = fs.currentDirectory;
    fs.currentDirectory = tempDir;
  });

  tearDown(() {
    fs.currentDirectory = oldCurrentDir;
    tryToDelete(tempDir);
  });

  group('AssetBundle fonts from packages', () {
    testUsingContext('App includes neither font manifest nor fonts when no defines fonts', () async {
      establishFlutterRoot();

      writePubspecFile('pubspec.yaml', 'test');
      writePackagesFile('test_package:p/p/lib/');
      writePubspecFile('p/p/pubspec.yaml', 'test_package');

      final AssetBundle bundle = AssetBundleFactory.instance.createBundle();
      await bundle.build(manifestPath: 'pubspec.yaml');
      expect(bundle.entries.length, 3); // LICENSE, AssetManifest, FontManifest
      expect(bundle.entries.containsKey('FontManifest.json'), isTrue);
    });

    testUsingContext('App font uses font file from package', () async {
      establishFlutterRoot();

      const String fontsSection = '''
       - family: foo
         fonts:
           - asset: packages/test_package/bar
''';
      writePubspecFile('pubspec.yaml', 'test', fontsSection: fontsSection);
      writePackagesFile('test_package:p/p/lib/');
      writePubspecFile('p/p/pubspec.yaml', 'test_package');

      const String font = 'bar';
      writeFontAsset('p/p/lib/', font);

      const String expectedFontManifest =
          '[{"fonts":[{"asset":"packages/test_package/bar"}],"family":"foo"}]';
      await buildAndVerifyFonts(
        <String>[],
        <String>[font],
        <String>['test_package'],
        expectedFontManifest,
      );
    });

    testUsingContext('App font uses local font file and package font file', () async {
      establishFlutterRoot();

      const String fontsSection = '''
       - family: foo
         fonts:
           - asset: packages/test_package/bar
           - asset: a/bar
''';
      writePubspecFile('pubspec.yaml', 'test', fontsSection: fontsSection);
      writePackagesFile('test_package:p/p/lib/');
      writePubspecFile('p/p/pubspec.yaml', 'test_package');

      const String packageFont = 'bar';
      writeFontAsset('p/p/lib/', packageFont);
      const String localFont = 'a/bar';
      writeFontAsset('', localFont);

      const String expectedFontManifest =
          '[{"fonts":[{"asset":"packages/test_package/bar"},{"asset":"a/bar"}],'
          '"family":"foo"}]';
      await buildAndVerifyFonts(
        <String>[localFont],
        <String>[packageFont],
        <String>['test_package'],
        expectedFontManifest,
      );
    });

    testUsingContext('App uses package font with own font file', () async {
      establishFlutterRoot();

      writePubspecFile('pubspec.yaml', 'test');
      writePackagesFile('test_package:p/p/lib/');
      const String fontsSection = '''
       - family: foo
         fonts:
           - asset: a/bar
''';
      writePubspecFile(
        'p/p/pubspec.yaml',
        'test_package',
        fontsSection: fontsSection,
      );

      const String font = 'a/bar';
      writeFontAsset('p/p/', font);

      const String expectedFontManifest =
          '[{"family":"packages/test_package/foo",'
          '"fonts":[{"asset":"packages/test_package/a/bar"}]}]';
      await buildAndVerifyFonts(
        <String>[],
        <String>[font],
        <String>['test_package'],
        expectedFontManifest,
      );
    });

    testUsingContext('App uses package font with font file from another package', () async {
      establishFlutterRoot();

      writePubspecFile('pubspec.yaml', 'test');
      writePackagesFile('test_package:p/p/lib/\ntest_package2:p2/p/lib/');
      const String fontsSection = '''
       - family: foo
         fonts:
           - asset: packages/test_package2/bar
''';
      writePubspecFile(
        'p/p/pubspec.yaml',
        'test_package',
        fontsSection: fontsSection,
      );
      writePubspecFile('p2/p/pubspec.yaml', 'test_package2');

      const String font = 'bar';
      writeFontAsset('p2/p/lib/', font);

      const String expectedFontManifest =
          '[{"family":"packages/test_package/foo",'
          '"fonts":[{"asset":"packages/test_package2/bar"}]}]';
      await buildAndVerifyFonts(
        <String>[],
        <String>[font],
        <String>['test_package2'],
        expectedFontManifest,
      );
    });

    testUsingContext('App uses package font with properties and own font file', () async {
      establishFlutterRoot();

      writePubspecFile('pubspec.yaml', 'test');
      writePackagesFile('test_package:p/p/lib/');

      const String pubspec = '''
       - family: foo
         fonts:
           - style: italic
             weight: 400
             asset: a/bar
''';
      writePubspecFile(
        'p/p/pubspec.yaml',
        'test_package',
        fontsSection: pubspec,
      );
      const String font = 'a/bar';
      writeFontAsset('p/p/', font);

      const String expectedFontManifest =
          '[{"family":"packages/test_package/foo",'
          '"fonts":[{"weight":400,"style":"italic","asset":"packages/test_package/a/bar"}]}]';
      await buildAndVerifyFonts(
        <String>[],
        <String>[font],
        <String>['test_package'],
        expectedFontManifest,
      );
    });

    testUsingContext('App uses local font and package font with own font file.', () async {
      establishFlutterRoot();

      const String fontsSection = '''
       - family: foo
         fonts:
           - asset: a/bar
''';
      writePubspecFile(
        'pubspec.yaml',
        'test',
        fontsSection: fontsSection,
      );
      writePackagesFile('test_package:p/p/lib/');
      writePubspecFile(
        'p/p/pubspec.yaml',
        'test_package',
        fontsSection: fontsSection,
      );

      const String font = 'a/bar';
      writeFontAsset('', font);
      writeFontAsset('p/p/', font);

      const String expectedFontManifest =
          '[{"fonts":[{"asset":"a/bar"}],"family":"foo"},'
          '{"family":"packages/test_package/foo",'
          '"fonts":[{"asset":"packages/test_package/a/bar"}]}]';
      await buildAndVerifyFonts(
        <String>[font],
        <String>[font],
        <String>['test_package'],
        expectedFontManifest,
      );
    });
  });
}
