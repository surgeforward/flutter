// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// See //dev/devicelab/bin/tasks/flutter_gallery__memory_nav.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_gallery/gallery/app.dart' show GalleryApp;
import 'package:flutter_test/flutter_test.dart';

Future<void> endOfAnimation() async {
  do {
    await SchedulerBinding.instance.endOfFrame;
  } while (SchedulerBinding.instance.hasScheduledFrame);
}

Future<void> main() async {
  MaterialPageRoute.debugEnableFadingRoutes = true; // ignore: deprecated_member_use
  final Completer<void> ready = new Completer<void>();
  runApp(new GestureDetector(
    onTap: () {
      debugPrint('Received tap.');
      ready.complete();
    },
    behavior: HitTestBehavior.opaque,
    child: const IgnorePointer(
      ignoring: true,
      child: GalleryApp(testMode: true),
    ),
  ));
  await SchedulerBinding.instance.endOfFrame;
  await new Future<Null>.delayed(const Duration(milliseconds: 50));
  debugPrint('==== MEMORY BENCHMARK ==== READY ====');

  await ready.future;
  debugPrint('Continuing...');

  // remove onTap handler, enable pointer events for app
  runApp(new GestureDetector(
    child: const IgnorePointer(
      ignoring: false,
      child: GalleryApp(testMode: true),
    ),
  ));
  await SchedulerBinding.instance.endOfFrame;

  final WidgetController controller = new LiveWidgetController(WidgetsBinding.instance);

  debugPrint('Navigating...');
  await controller.tap(find.text('Material'));
  await new Future<Null>.delayed(const Duration(milliseconds: 150));
  final Finder demoList = find.byKey(const Key('GalleryDemoList'));
  final Finder demoItem = find.text('Text fields');
  do {
    await controller.drag(demoList, const Offset(0.0, -300.0));
    await new Future<Null>.delayed(const Duration(milliseconds: 20));
  } while (!demoItem.precache());

  for (int iteration = 0; iteration < 15; iteration += 1) {
    debugPrint('Tapping... (iteration $iteration)');
    await controller.tap(demoItem);
    await endOfAnimation();
    debugPrint('Backing out...');
    await controller.tap(find.byTooltip('Back').last);
    await endOfAnimation();
  }

  debugPrint('==== MEMORY BENCHMARK ==== DONE ====');
}
