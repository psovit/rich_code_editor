import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The current text, selection, and composing state for editing a run of text.
@immutable
class CodeEditingValue {
  /// Creates information for editing a run of text.
  ///
  /// The selection and composing range must be within the text.
  ///
  /// The [text], [selection], and [composing] arguments must not be null but
  /// each have default values.
  const CodeEditingValue({
    this.value = const TextSpan(text: '', style: TextStyle()),
    this.selection = const TextSelection.collapsed(offset: -1),
    this.composing = TextRange.empty,
    this.remotelyEdited,
  })  : assert(selection != null),
        assert(composing != null);

  /// The current text being edited.
  final TextSpan value;

  /// The range of text that is currently selected.
  final TextSelection selection;

  /// The range of text that is still being composed.
  final TextRange composing;

  /// A value that corresponds to the empty string with no selection and no composing range.
  static const CodeEditingValue empty = CodeEditingValue();

  /// Creates a copy of this value but with the given fields replaced with the new values.
  CodeEditingValue copyWith(
      {TextSpan value,
      TextSelection selection,
      TextRange composing,
      bool remotelyEdited = false}) {
    return new CodeEditingValue(
        value: value ?? this.value,
        selection: selection ?? this.selection,
        composing: composing ?? this.composing,
        remotelyEdited: remotelyEdited ?? this.remotelyEdited);
  }

  final bool
      remotelyEdited; //set to true if text was added programatically or by different method other than device keyboard

  @override
  String toString() =>
      '$runtimeType(text: \u2524$text\u251C, selection: $selection, composing: $composing)';

  String get text => value.toPlainText();

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other is! CodeEditingValue) return false;
    final CodeEditingValue typedOther = other;
    return typedOther.text == text &&
        typedOther.selection == selection &&
        typedOther.composing == composing;
  }

  @override
  int get hashCode => hashValues(
        text.hashCode,
        selection.hashCode,
        composing.hashCode,
      );
}

TextAffinity _toTextAffinity(String affinity) {
  switch (affinity) {
    case 'TextAffinity.downstream':
      return TextAffinity.downstream;
    case 'TextAffinity.upstream':
      return TextAffinity.upstream;
  }
  return null;
}
