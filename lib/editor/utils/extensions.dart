import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// Utility class for TextSpan widget helper methods
class Extensions {
  
  static bool isEmpty(TextSpan textSpan) {
    assert(textSpan.debugAssertIsValid());
    bool isEmpty = true;
    textSpan.visitChildren((InlineSpan span) {
      if (span.toPlainText().isNotEmpty) {
        isEmpty = false;
        return false;
      } else
        return true;
    });
    return isEmpty;
  }

  static bool isNotEmpty(TextSpan textSpan) => !isEmpty(textSpan);

  /// Return the length of the text contained in this [TextSpan] tree.
  static int length(TextSpan textSpan) {
    assert(textSpan.debugAssertIsValid());
    int length = 0;
    textSpan.visitChildren((InlineSpan span) {
      length += span.toPlainText().length;
      return true;
    });
    return length;
  }

  /// Returns the text span that contains the given position in the text.
  static TextSpan getSpanForPosition(TextSpan parent, int targetOffset) {
    assert(parent.debugAssertIsValid());
    int offset = 0;
    TextSpan result;
    parent.visitChildren((InlineSpan span) {
      assert(result == null);
      final int endOffset = offset + span.toPlainText().length;
      if (targetOffset >= offset && targetOffset <= endOffset) {
        result = span;
        return false;
      }
      offset = endOffset;
      return true;
    });
    return result;
  }

  /// Return the max fontSize from a given [TextSpan] tree.
  static double maxFontSize(TextSpan textSpan) {
    textSpan.debugAssertIsValid();
    double size = 0.0;
    textSpan.visitChildren((InlineSpan span) {
      var currentSize = span.style?.fontSize ?? -1.0;
      if (currentSize > size) size = currentSize;
      return true;
    });
    return size;
  }

  /// Creates a copy of this [TextSpan] but with the given fields replaced with the new values.
  static TextSpan copySpanWith(
      {@required TextSpan base,
      TextStyle style,
      String text,
      List<TextSpan> children,
      GestureRecognizer recognizer}) {
    return new TextSpan(
        style: style ?? base.style,
        text: text ?? base.text,
        children: children ?? base.children,
        recognizer: recognizer ?? base.recognizer);
  }

  static TextStyle emptyStyle = const TextStyle();
}
