// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'message.dart';

/// A Flutter Driver command that enables or disables the FrameSync mechanism.
class SetFrameSync extends Command {
  /// Creates a command to toggle the FrameSync mechanism.
  SetFrameSync(this.enabled, { Duration timeout }) : super(timeout: timeout);

  /// Deserializes this command from the value generated by [serialize].
  SetFrameSync.deserialize(Map<String, String> params)
      : enabled = params['enabled'].toLowerCase() == 'true',
        super.deserialize(params);

  /// Whether frameSync should be enabled or disabled.
  final bool enabled;

  @override
  final String kind = 'set_frame_sync';

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'enabled': '$enabled',
  });
}

/// The result of a [SetFrameSync] command.
class SetFrameSyncResult extends Result {
  /// Deserializes this result from JSON.
  static SetFrameSyncResult fromJson(Map<String, dynamic> json) {
    return SetFrameSyncResult();
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{};
}
