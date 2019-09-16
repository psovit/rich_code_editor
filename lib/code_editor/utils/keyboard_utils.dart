import 'package:flutter/widgets.dart';
import 'package:rich_code_editor/code_editor/widgets/code_editing_value.dart';

class KeyboardUtils {
  /// Check and see if last pressed key was enter key.
  /// This is checked by looking if the last character text == "\n".
  static PressedKey enterPressed(CodeEditingValue oldValue, CodeEditingValue newValue) {
    if (newValue.text.length == 1 && newValue.text == "\n") {
      return PressedKey.enter;
    }

    final TextSelection newSelection = newValue.selection;
    final TextSelection currentSelection = oldValue.selection;

    if (currentSelection.baseOffset > newSelection.baseOffset) {
      //backspace was pressed
      return PressedKey.backSpace;
    }

    var lastChar = newValue.text.substring(currentSelection.baseOffset, newSelection.baseOffset);
    return lastChar == "\n" ? PressedKey.enter : PressedKey.regular;
  }
}

enum PressedKey {
  enter,
  backSpace,
  regular
}
