import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:rich_code_editor/exports.dart';

/// This is a dummy implementation for Syntax highlighter.
/// Ideally, you would implement the `SyntaxHighlighterBase` interface as per your need of highlighting rules.
class DummySyntaxHighlighter implements SyntaxHighlighterBase {
  @override
  TextEditingValue addTextRemotely(TextEditingValue oldValue, String newText) {
    return null;
  }

  @override
  TextEditingValue onBackSpacePress(
      TextEditingValue oldValue, TextSpan currentSpan) {
    return null;
  }

  @override
  TextEditingValue onEnterPress(TextEditingValue oldValue) {
    var padding = "    ";
    var newText = oldValue.text + padding;
    var newValue = oldValue.copyWith(
      text: newText,
      composing: TextRange(start: -1, end: -1),
      selection: TextSelection.fromPosition(TextPosition(
          affinity: TextAffinity.upstream, offset: newText.length)),
    );

    return newValue;
  }

  @override
  List<TextSpan> parseText(TextEditingValue tev) {
    var texts = tev.text.split(' ');

    var lsSpans = List<TextSpan>();
    texts.forEach((text) {
      if (text == 'class') {
        lsSpans
            .add(TextSpan(text: text, style: TextStyle(color: Colors.green)));
      } else if (text == 'if' || text == 'else') {
        lsSpans.add(TextSpan(text: text, style: TextStyle(color: Colors.blue)));
      } else if (text == 'return') {
        lsSpans.add(TextSpan(text: text, style: TextStyle(color: Colors.red)));
      } else {
        lsSpans
            .add(TextSpan(text: text, style: TextStyle(color: Colors.black)));
      }
      lsSpans.add(TextSpan(text: ' ', style: TextStyle(color: Colors.black)));
    });
    return lsSpans;
  }
}
