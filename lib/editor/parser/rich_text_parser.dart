import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:rich_code_editor/editor/keyboard/text_input_client.dart';

// This is the interface that must be implemented by Syntax highlighter's for each programming language
abstract class RichTextEditingValueParserBase {
  RichTextEditingValue parse(
      {@required RichTextEditingValue oldValue,
      @required RichTextEditingValue newValue,
      @required TextStyle style});
}


// This is a dummy implementation of syntax highlighter
// Highlights a different color for every other word.
class DummyParser implements RichTextEditingValueParserBase {
  @override
  RichTextEditingValue parse(
      {@required RichTextEditingValue oldValue,
      @required RichTextEditingValue newValue,
      @required TextStyle style}) {
    if (_equalTextValue(oldValue, newValue)) {
      return oldValue;
    }

    var kCodeStyle = TextStyle(fontSize: 16.0, color: Colors.green);
    var plainStyle = TextStyle(fontSize: 16.0, color: Colors.black);

    List<TextSpan> ls = [];
    var lines = newValue.text.split("\n"); //splits each line
    var space = TextSpan(text: " ", style: plainStyle);
    var lineSpan = TextSpan(text: "\n", style: plainStyle);

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var words = line.split(" "); //add other delimeters here..
      var isCode = true;

      for (var j = 0; j < words.length; j++) {
        var word = words[j];
        var ts = TextSpan(text: word, style: isCode ? kCodeStyle : plainStyle);

        isCode = !isCode;

        if (word != "") {
          ls.add(ts);
        }

        if (words.length - (j + 1) > 0) {
          ls.add(space);
        }
      }
      if (lines.length - (i + 1) > 0) {
        ls.add(lineSpan);
      }
    }

    if (ls.length > 1) {
      return newValue = newValue.copyWith(
          value: new TextSpan(text: "", style: plainStyle, children: ls));
    }

    return newValue;
  }

  static bool _equalTextValue(RichTextEditingValue a, RichTextEditingValue b) {
    return a.value.toPlainText() == b.value.toPlainText() &&
        a.selection == b.selection &&
        a.composing == b.composing;
  }
}
