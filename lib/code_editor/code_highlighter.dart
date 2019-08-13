import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:rich_code_editor/code_editor/widgets/code_editing_value.dart';

// This is the interface that must be implemented by Syntax highlighter's for each programming language
abstract class CodeEditingValueHighlighterBase {
  CodeEditingValue parse(
      {@required CodeEditingValue oldValue,
      @required CodeEditingValue newValue,
      @required TextStyle style});
}

// This is a dummy implementation of syntax highlighter
// Highlights a different color for every other word.
class DummyHighlighter implements CodeEditingValueHighlighterBase {
  var _totalOffset = 0;
  var kCodeStyle = TextStyle(fontSize: 16.0, color: Colors.green);
  var plainStyle = TextStyle(fontSize: 16.0, color: Colors.black);

  @override
  CodeEditingValue parse(
      {@required CodeEditingValue oldValue,
      @required CodeEditingValue newValue,
      @required TextStyle style}) {
    if (_equalTextValue(oldValue, newValue)) {
      return oldValue;
    } else if (_sameTextDiffSelection(oldValue, newValue)) {
      return newValue.copyWith(value: oldValue.value);
    }

    var plainStyle = TextStyle(fontSize: 16.0, color: Colors.black);

    final TextSelection newSelection = newValue.selection;

    if (_enterPressed(oldValue, newValue)) {
      print('enter pressed');

      return addTextRemotely(newValue, "    ");
    } 
    var ls = _getTextSpans(newValue.text);

    if (ls.length > 1) {
      newValue = newValue.copyWith(
          value: new TextSpan(text: "", style: plainStyle, children: ls),
          selection: TextSelection.fromPosition(
              TextPosition(offset: newSelection.end + _totalOffset)));
      _totalOffset = 0;
      return newValue;
    }

    return newValue;
  }

  static bool _equalTextValue(CodeEditingValue a, CodeEditingValue b) {
    return a.value.toPlainText() == b.value.toPlainText() &&
        a.selection == b.selection &&
        a.composing == b.composing;
  }

  bool _enterPressed(
      CodeEditingValue oldValue, CodeEditingValue newValue) {
    if (newValue.text.length == 1) {
      return (newValue.text == "\n");
    }
    final TextSelection newSelection = newValue.selection;
    final TextSelection currentSelection = oldValue.selection;

    if (currentSelection.baseOffset > newSelection.baseOffset) {
      //backspace was pressed
      return false;
    }

    var lastChar = newValue.text
        .substring(currentSelection.baseOffset, newSelection.baseOffset);
    return (lastChar == "\n");
  }

  bool _backSpacePressed(
      CodeEditingValue oldValue, CodeEditingValue newValue) {
    final TextSelection newSelection = newValue.selection;
    final TextSelection currentSelection = oldValue.selection;

    return currentSelection.baseOffset > newSelection.baseOffset;
  }

  bool _sameTextDiffSelection(CodeEditingValue a, CodeEditingValue b) {
    return a.value.toPlainText() == b.value.toPlainText() &&
        (a.selection != b.selection || a.composing != b.composing);
  }

  CodeEditingValue addTextRemotely(
    CodeEditingValue oldValue,
    String newText,
  ) {
    final TextSelection currentSelection = oldValue.selection;

    var completeText = oldValue.text;

    var textBefore = completeText.substring(0, currentSelection.start);
    var textAfter =
        completeText.substring(currentSelection.start, completeText.length);

    var result = "";

    if (textBefore.length > 0) {
      result = textBefore + newText;
    }

    if (textAfter.length > 0) {
      result = result + textAfter;
    }

    var ls = _getTextSpans(result);
    oldValue = oldValue.copyWith(
      remotelyEdited: true,
        value: new TextSpan(
            text: "", style: plainStyle, children: ls),
        selection: TextSelection.fromPosition(TextPosition(
            affinity: TextAffinity.downstream,
            offset: currentSelection.start + newText.length)));
    
    return oldValue;
  }

  List<TextSpan> _getTextSpans(String text) {
    List<TextSpan> ls = [];

    var lines = text.split("\n"); //splits each line
    var space = TextSpan(text: " ", style: plainStyle);
    var lineSpan = TextSpan(text: "\n", style: plainStyle);
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if(line == "    ") {
        ls.add(TextSpan(text: "    ", style: plainStyle));
        continue;
      }
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

    return ls;
  }
}
