// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'common.dart';
import 'constants.dart';
import 'flutter_test_alternative.dart';

/// Matches an [AndroidSemanticsNode].
///
/// Any properties which aren't supplied are ignored during the comparison,
/// with the exception of `isHeading`. The heading property is not available
/// on all versions of Android. If it is not available on the tested version,
/// it will be match whatever it is compared against.
///
/// This matcher is intended to compare the accessibility values generated by
/// the Android accessibility bridge, and not the semantics object created by
/// the Flutter framework.
Matcher hasAndroidSemantics({
  String text,
  String contentDescription,
  String className,
  int id,
  Rect rect,
  Size size,
  List<AndroidSemanticsAction> actions,
  List<AndroidSemanticsNode> children,
  bool isChecked,
  bool isCheckable,
  bool isEditable,
  bool isEnabled,
  bool isFocusable,
  bool isFocused,
  bool isHeading,
  bool isPassword,
  bool isLongClickable,
}) {
  return _AndroidSemanticsMatcher(
    text: text,
    contentDescription: contentDescription,
    className: className,
    rect: rect,
    size: size,
    id: id,
    actions: actions,
    isChecked: isChecked,
    isCheckable: isCheckable,
    isEditable: isEditable,
    isEnabled: isEnabled,
    isFocusable: isFocusable,
    isFocused: isFocused,
    isHeading: isHeading,
    isPassword: isPassword,
    isLongClickable: isLongClickable,
  );
}

class _AndroidSemanticsMatcher extends Matcher {
  _AndroidSemanticsMatcher({
    this.text,
    this.contentDescription,
    this.className,
    this.id,
    this.actions,
    this.rect,
    this.size,
    this.isChecked,
    this.isCheckable,
    this.isEnabled,
    this.isEditable,
    this.isFocusable,
    this.isFocused,
    this.isHeading,
    this.isPassword,
    this.isLongClickable,
  });

  final String text;
  final String className;
  final String contentDescription;
  final int id;
  final List<AndroidSemanticsAction> actions;
  final Rect rect;
  final Size size;
  final bool isChecked;
  final bool isCheckable;
  final bool isEditable;
  final bool isEnabled;
  final bool isFocusable;
  final bool isFocused;
  final bool isHeading;
  final bool isPassword;
  final bool isLongClickable;

  @override
  Description describe(Description description) {
    description.add('AndroidSemanticsNode');
    if (text != null)
      description.add(' with text: $text');
    if (contentDescription != null)
      description.add( 'with contentDescription $contentDescription');
    if (className != null)
      description.add(' with className: $className');
    if (id != null)
      description.add(' with id: $id');
    if (actions != null)
      description.add(' with actions: $actions');
    if (rect != null)
      description.add(' with rect: $rect');
    if (size != null)
      description.add(' with size: $size');
    if (isChecked != null)
      description.add(' with flag isChecked: $isChecked');
    if (isEditable != null)
      description.add(' with flag isEditable: $isEditable');
    if (isEnabled != null)
      description.add(' with flag isEnabled: $isEnabled');
    if (isFocusable != null)
      description.add(' with flag isFocusable: $isFocusable');
    if (isFocused != null)
      description.add(' with flag isFocused: $isFocused');
    if (isHeading != null)
      description.add(' with flag isHeading: $isHeading');
    if (isPassword != null)
      description.add(' with flag isPassword: $isPassword');
    if (isLongClickable != null)
      description.add(' with flag isLongClickable: $isLongClickable');
    return description;
  }

  @override
  bool matches(covariant AndroidSemanticsNode item, Map<Object, Object> matchState) {
    if (text != null && text != item.text)
      return _failWithMessage('Expected text: $text', matchState);
    if (contentDescription != null && contentDescription != item.contentDescription)
      return _failWithMessage('Expected contentDescription: $contentDescription', matchState);
    if (className != null && className != item.className)
      return _failWithMessage('Expected className: $className', matchState);
    if (id != null && id != item.id)
      return _failWithMessage('Expected id: $id', matchState);
    if (rect != null && rect != item.getRect())
      return _failWithMessage('Expected rect: $rect', matchState);
    if (size != null && size != item.getSize())
      return _failWithMessage('Expected size: $size', matchState);
    if (actions != null) {
      final List<AndroidSemanticsAction> itemActions = item.getActions();
      if (!unorderedEquals(actions).matches(itemActions, matchState)) {
        final List<String> actionsString = actions.map<String>((AndroidSemanticsAction action) => action.toString()).toList()..sort();
        final List<String> itemActionsString = itemActions.map<String>((AndroidSemanticsAction action) => action.toString()).toList()..sort();
        final Set<String> unexpected = itemActionsString.toSet().difference(actionsString.toSet());
        final Set<String> missing = actionsString.toSet().difference(itemActionsString.toSet());
        return _failWithMessage('Expected actions: $actionsString\nActual actions: $itemActionsString\nUnexpected: $unexpected\nMissing: $missing', matchState);
      }
    }
    if (isChecked != null && isChecked != item.isChecked)
      return _failWithMessage('Expected isChecked: $isChecked', matchState);
    if (isCheckable != null && isCheckable != item.isCheckable)
      return _failWithMessage('Expected isCheckable: $isCheckable', matchState);
    if (isEditable != null && isEditable != item.isEditable)
      return _failWithMessage('Expected isEditable: $isEditable', matchState);
    if (isEnabled != null && isEnabled != item.isEnabled)
      return _failWithMessage('Expected isEnabled: $isEnabled', matchState);
    if (isFocusable != null && isFocusable != item.isFocusable)
      return _failWithMessage('Expected isFocusable: $isFocusable', matchState);
    if (isFocused != null && isFocused != item.isFocused)
      return _failWithMessage('Expected isFocused: $isFocused', matchState);
    // Heading is not available in all Android versions, so match anything if it is not set by the platform
    if (isHeading != null && isHeading != item.isHeading && item.isHeading != null)
      return _failWithMessage('Expected isHeading: $isHeading', matchState);
    if (isPassword != null && isPassword != item.isPassword)
      return _failWithMessage('Expected isPassword: $isPassword', matchState);
    if (isLongClickable != null && isLongClickable != item.isLongClickable)
      return _failWithMessage('Expected longClickable: $isLongClickable', matchState);
    return true;
  }

  @override
  Description describeMismatch(Object item, Description mismatchDescription,
      Map<Object, Object> matchState, bool verbose) {
    return mismatchDescription.add(matchState['failure']);
  }

  bool _failWithMessage(String value, Map<dynamic, dynamic> matchState) {
    matchState['failure'] = value;
    return false;
  }
}
