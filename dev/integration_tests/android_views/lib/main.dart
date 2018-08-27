// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:path_provider/path_provider.dart';

import 'motion_event_diff.dart';

MethodChannel channel = const MethodChannel('android_views_integration');

const String kEventsFileName = 'touchEvents';

/// Wraps a flutter driver [DataHandler] with one that waits until a delegate is set.
///
/// This allows the driver test to call [FlutterDriver.requestData] before the handler was
/// set by the app in which case the requestData call will only complete once the app is ready
/// for it.
class FutureDataHandler {
  final Completer<DataHandler> handlerCompleter = new Completer<DataHandler>();

  Future<String> handleMessage(String message) async {
    final DataHandler handler = await handlerCompleter.future;
    return handler(message);
  }
}

FutureDataHandler driverDataHandler = new FutureDataHandler();

void main() {
  enableFlutterDriverExtension(handler: driverDataHandler.handleMessage);
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Android Views Integration Test',
      home: new Scaffold(
        body: new PlatformViewPage(),
      ),
    );
  }
}

class PlatformViewPage extends StatefulWidget {
  @override
  State createState() => new PlatformViewState();
}

class PlatformViewState extends State<PlatformViewPage> {
  static const int kEventsBufferSize = 1000;

  MethodChannel viewChannel;

  /// The list of motion events that were passed to the FlutterView.
  List<Map<String, dynamic>> flutterViewEvents = <Map<String, dynamic>>[];

  /// The list of motion events that were passed to the embedded view.
  List<Map<String, dynamic>> embeddedViewEvents = <Map<String, dynamic>>[];

  @override
  Widget build(BuildContext context) {
    return new Column(
      children: <Widget>[
        new SizedBox(
          height: 300.0,
          child: new AndroidView(
              viewType: 'simple_view',
              onPlatformViewCreated: onPlatformViewCreated),
        ),
        new Expanded(
          child: new ListView.builder(
            itemBuilder: buildEventTile,
            itemCount: flutterViewEvents.length,
          ),
        ),
        new Row(
          children: <Widget>[
            new RaisedButton(
              child: const Text('RECORD'),
              onPressed: listenToFlutterViewEvents,
            ),
            new RaisedButton(
              child: const Text('CLEAR'),
              onPressed: () {
                setState(() {
                  flutterViewEvents.clear();
                  embeddedViewEvents.clear();
                });
              },
            ),
            new RaisedButton(
              child: const Text('SAVE'),
              onPressed: () {
                const StandardMessageCodec codec = StandardMessageCodec();
                saveRecordedEvents(
                    codec.encodeMessage(flutterViewEvents), context);
              },
            ),
            new RaisedButton(
              key: const ValueKey<String>('play'),
              child: const Text('PLAY FILE'),
              onPressed: () { playEventsFile(); },
            )
          ],
        )
      ],
    );
  }

  Future<String> playEventsFile() async {
    const StandardMessageCodec codec = StandardMessageCodec();
    try {
      final ByteData data = await rootBundle.load('packages/assets_for_android_views/assets/touchEvents');
      final List<dynamic> unTypedRecordedEvents = codec.decodeMessage(data);
      final List<Map<String, dynamic>> recordedEvents = unTypedRecordedEvents
          .cast<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> e) =>e.cast<String, dynamic>())
          .toList();
      await channel.invokeMethod('pipeFlutterViewEvents');
      await viewChannel.invokeMethod('pipeTouchEvents');
      print('replaying ${recordedEvents.length} motion events');
      for (Map<String, dynamic> event in recordedEvents.reversed) {
        await channel.invokeMethod('synthesizeEvent', event);
      }

      await channel.invokeMethod('stopFlutterViewEvents');
      await viewChannel.invokeMethod('stopTouchEvents');

      if (flutterViewEvents.length != embeddedViewEvents.length)
        return 'Synthesized ${flutterViewEvents.length} events but the embedded view received ${embeddedViewEvents.length} events';

      final StringBuffer diff = new StringBuffer();
      for (int i = 0; i < flutterViewEvents.length; ++i) {
        final String currentDiff = diffMotionEvents(flutterViewEvents[i], embeddedViewEvents[i]);
        if (currentDiff.isEmpty)
          continue;
        if (diff.isNotEmpty)
          diff.write(', ');
        diff.write(currentDiff);
      }
      return diff.toString();
    } catch(e) {
      return e.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    channel.setMethodCallHandler(onMethodChannelCall);
  }

  Future<void> saveRecordedEvents(ByteData data, BuildContext context) async {
    if (!await channel.invokeMethod('getStoragePermission')) {
      showMessage(
          context, 'External storage permissions are required to save events');
      return;
    }
    try {
      final Directory outDir = await getExternalStorageDirectory();
      // This test only runs on Android so we can assume path separator is '/'.
      final File file = new File('${outDir.path}/$kEventsFileName');
      await file.writeAsBytes(data.buffer.asUint8List(0, data.lengthInBytes), flush: true);
      showMessage(context, 'Saved original events to ${file.path}');
    } catch (e) {
      showMessage(context, 'Failed saving ${e.toString()}');
    }
  }

  void showMessage(BuildContext context, String message) {
    Scaffold.of(context).showSnackBar(new SnackBar(
      content: new Text(message),
      duration: const Duration(seconds: 3),
    ));
  }

  void onPlatformViewCreated(int id) {
    viewChannel = new MethodChannel('simple_view/$id');
    viewChannel.setMethodCallHandler(onViewMethodChannelCall);
    driverDataHandler.handlerCompleter.complete(handleDriverMessage);
  }

  void listenToFlutterViewEvents() {
    channel.invokeMethod('pipeFlutterViewEvents');
    viewChannel.invokeMethod('pipeTouchEvents');
    new Timer(const Duration(seconds: 3), () {
      channel.invokeMethod('stopFlutterViewEvents');
      viewChannel.invokeMethod('stopTouchEvents');
    });
  }

  Future<String> handleDriverMessage(String message) async {
    switch (message) {
      case 'run test':
        return playEventsFile();
    }
    return 'unknown message: "$message"';
  }

  Future<dynamic> onMethodChannelCall(MethodCall call) {
    switch (call.method) {
      case 'onTouch':
        final Map<dynamic, dynamic> map = call.arguments;
        flutterViewEvents.insert(0, map.cast<String, dynamic>());
        if (flutterViewEvents.length > kEventsBufferSize)
          flutterViewEvents.removeLast();
        setState(() {});
        break;
    }
    return new Future<dynamic>.sync(null);
  }

  Future<dynamic> onViewMethodChannelCall(MethodCall call) {
    switch (call.method) {
      case 'onTouch':
        final Map<dynamic, dynamic> map = call.arguments;
        embeddedViewEvents.insert(0, map.cast<String, dynamic>());
        if (embeddedViewEvents.length > kEventsBufferSize)
          embeddedViewEvents.removeLast();
        setState(() {});
        break;
    }
    return new Future<dynamic>.sync(null);
  }

  Widget buildEventTile(BuildContext context, int index) {
    if (embeddedViewEvents.length > index)
      return new TouchEventDiff(
          flutterViewEvents[index], embeddedViewEvents[index]);
    return new Text(
        'Unmatched event, action: ${flutterViewEvents[index]['action']}');
  }
}

class TouchEventDiff extends StatelessWidget {
  const TouchEventDiff(this.originalEvent, this.synthesizedEvent);

  final Map<String, dynamic> originalEvent;
  final Map<String, dynamic> synthesizedEvent;

  @override
  Widget build(BuildContext context) {

    Color color;
    final String diff = diffMotionEvents(originalEvent, synthesizedEvent);
    String msg;
    final int action = synthesizedEvent['action'];
    final String actionName = getActionName(getActionMasked(action), action);
    if (diff.isEmpty) {
      color = Colors.green;
      msg = 'Matched event (action $actionName)';
    } else {
      color = Colors.red;
      msg = '[$actionName] $diff';
    }
    return new GestureDetector(
      onLongPress: () {
        print('expected:');
        prettyPrintEvent(originalEvent);
        print('\nactual:');
        prettyPrintEvent(synthesizedEvent);
      },
      child: new Container(
        color: color,
        margin: const EdgeInsets.only(bottom: 2.0),
        child: new Text(msg),
      ),
    );
  }

  void prettyPrintEvent(Map<String, dynamic> event) {
    final StringBuffer buffer = new StringBuffer();
    final int action = event['action'];
    final int maskedAction = getActionMasked(action);
    final String actionName = getActionName(maskedAction, action);

    buffer.write('$actionName ');
    if (maskedAction == 5 || maskedAction == 6) {
     buffer.write('pointer: ${getPointerIdx(action)} ');
    }

    final List<Map<dynamic, dynamic>> coords = event['pointerCoords'].cast<Map<dynamic, dynamic>>();
    for (int i = 0; i < coords.length; i++) {
      buffer.write('p$i x: ${coords[i]['x']} y: ${coords[i]['y']}, pressure: ${coords[i]['pressure']} ');
    }
    print(buffer.toString());
  }
}

