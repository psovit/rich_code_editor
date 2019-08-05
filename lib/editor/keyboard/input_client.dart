// /// The current text, selection, and composing state for editing a run of text.
// @immutable
import 'package:flutter/widgets.dart';

class RichTextEditingValue { //extends AbstractTextEditingValue<TextSpan> {
  /// Creates information for editing a run of text.
  ///
  /// The selection and composing range must be within the text.
  ///
  /// The [value], [selection], and [composing] arguments must not be null but
  /// each have default values.
  const RichTextEditingValue(
      {this.value: const TextSpan(text: "", style: TextStyle()),
      this.selection: const TextSelection.collapsed(offset: -1),
      this.composing: TextRange.empty, 
      this.remotelyEdited = false})
      : assert(value != null),
        assert(selection != null),
        assert(composing != null);

  /// The current text being edited.
  final TextSpan value;

  /// The range of text that is currently selected.
  final TextSelection selection;

  /// The range of text that is still being composed.
  final TextRange composing;

  /// A value that corresponds to the empty string with no selection and no composing range.
  static const RichTextEditingValue empty = const RichTextEditingValue();

  /// Creates a copy of this value but with the given fields replaced with the new values.
  RichTextEditingValue copyWith(
      {TextSpan value, TextSelection selection, TextRange composing, bool remotelyEdited = false}) {
    return new RichTextEditingValue(
        value: value ?? this.value,
        selection: selection ?? this.selection,
        composing: composing ?? this.composing,
        remotelyEdited : remotelyEdited ?? this.remotelyEdited);
  }

  final bool remotelyEdited;//set to true if text was added programatically or by different method other than device keyboard

  String get text => value.toPlainText();
}