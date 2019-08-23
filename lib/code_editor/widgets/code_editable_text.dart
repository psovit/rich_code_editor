// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show ViewportOffset, RenderEditable;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/widgets.dart' hide TextSelectionOverlay;
import 'package:rich_code_editor/code_editor/code_highlighter.dart';
import 'package:rich_code_editor/code_editor/widgets/code_editable.dart' as ce;
import 'package:rich_code_editor/code_editor/widgets/code_editing_value.dart';
import 'package:rich_code_editor/code_editor/widgets/code_selection.dart' as cs;

export 'package:flutter/services.dart' show TextSelection, TextInputType;

/// Signature for the callback that reports when the user changes the selection
/// (including the cursor location).
typedef SelectionChangedCallback = void Function(
    TextSelection selection, ce.SelectionChangedCause cause);

// The time it takes for the cursor to fade from fully opaque to fully
// transparent and vice versa. A full cursor blink, from transparent to opaque
// to transparent, is twice this duration.
const Duration _kCursorBlinkHalfPeriod = Duration(milliseconds: 500);

// The time the cursor is static in opacity before animating to become
// transparent.
const Duration _kCursorBlinkWaitForStart = Duration(milliseconds: 150);

// Number of cursor ticks during which the most recently entered character
// is shown in an obscured text field.
const int _kObscureShowLatestCharCursorTicks = 3;

/// A controller for an editable text field.
///
/// Whenever the user modifies a text field with an associated
/// [CodeEditingController], the text field updates [value] and the controller
/// notifies its listeners. Listeners can then read the [text] and [selection]
/// properties to learn what the user has typed or how the selection has been
/// updated.
///
/// Similarly, if you modify the [text] or [selection] properties, the text
/// field will be notified and will update itself appropriately.
///
/// A [CodeEditingController] can also be used to provide an initial value for a
/// text field. If you build a text field with a controller that already has
/// [text], the text field will use that text as its initial value.
///
/// The [text] or [selection] properties can be set from within a listener
/// added to this controller. If both properties need to be changed then the
/// controller's [value] should be set instead.
///
/// Remember to [dispose] of the [CodeEditingController] when it is no longer needed.
/// This will ensure we discard any resources used by the object.
/// {@tool snippet --template=stateful_widget_material}
/// This example creates a [TextField] with a [CodeEditingController] whose
/// change listener forces the entered text to be lower case and keeps the
/// cursor at the end of the input.
///
/// ```dart
/// final _controller = CodeEditingController();
///
/// void initState() {
///   _controller.addListener(() {
///     final text = _controller.text.toLowerCase();
///     _controller.value = _controller.value.copyWith(
///       text: text,
///       selection: TextSelection(baseOffset: text.length, extentOffset: text.length),
///       composing: TextRange.empty,
///     );
///   });
///   super.initState();
/// }
///
/// void dispose() {
///   _controller.dispose();
///   super.dispose();
/// }
///
/// Widget build(BuildContext context) {
///   return Scaffold(
///     body: Container(
///      alignment: Alignment.center,
///       padding: const EdgeInsets.all(6),
///       child: TextFormField(
///         controller: _controller,
///        decoration: InputDecoration(border: OutlineInputBorder()),
///       ),
///     ),
///   );
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [TextField], which is a Material Design text field that can be controlled
///    with a [CodeEditingController].
///  * [CodeEditableText], which is a raw region of editable text that can be
///    controlled with a [CodeEditingController].
///  * Learn how to use a [CodeEditingController] in one of our [cookbook recipe]s.(https://flutter.dev/docs/cookbook/forms/text-field-changes#2-use-a-CodeEditingController)
class CodeEditingController extends ValueNotifier<CodeEditingValue> {
  /// Creates a controller for an editable text field.
  ///
  /// This constructor treats a null [text] argument as if it were the empty
  /// string.
  CodeEditingController({TextSpan textSpan})
      : super(textSpan == null
            ? CodeEditingValue.empty
            : CodeEditingValue(value: textSpan));

  /// Creates a controller for an editable text field from an initial [CodeEditingValue].
  ///
  /// This constructor treats a null [value] argument as if it were
  /// [CodeEditingValue.empty].
  CodeEditingController.fromValue(CodeEditingValue value)
      : super(value ?? CodeEditingValue.empty);

  /// The current string the user is editing.
  TextSpan get textSpan => value.value;

  /// Setting this will notify all the listeners of this [CodeEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this value should only be set between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  ///
  /// This property can be set from a listener added to this
  /// [CodeEditingController]; however, one should not also set [selection]
  /// in a separate statement. To change both the [text] and the [selection]
  /// change the controller's [value].
  set text(TextSpan newTextSpan) {
    value = value.copyWith(
      value: newTextSpan,
      selection: const TextSelection.collapsed(offset: -1),
      composing: TextRange.empty,
    );
  }

  /// The currently selected [text].
  ///
  /// If the selection is collapsed, then this property gives the offset of the
  /// cursor within the text.
  TextSelection get selection => value.selection;

  /// Setting this will notify all the listeners of this [CodeEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this value should only be set between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  ///
  /// This property can be set from a listener added to this
  /// [CodeEditingController]; however, one should not also set [text]
  /// in a separate statement. To change both the [text] and the [selection]
  /// change the controller's [value].
  set selection(TextSelection newSelection) {
    if (newSelection == null) {
      value = value;
      return;
    }
    if (newSelection.start > _getTextSpanLength(textSpan) ||
        newSelection.end > _getTextSpanLength(textSpan))
      throw FlutterError('invalid text selection: $newSelection');
    value = value.copyWith(selection: newSelection, composing: TextRange.empty);
  }

  /// Set the [value] to empty.
  ///
  /// After calling this function, [text] will be the empty string and the
  /// selection will be invalid.
  ///
  /// Calling this will notify all the listeners of this [CodeEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this method should only be called between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  void clear() {
    value = CodeEditingValue.empty;
  }

  /// Set the composing region to an empty range.
  ///
  /// The composing region is the range of text that is still being composed.
  /// Calling this function indicates that the user is done composing that
  /// region.
  ///
  /// Calling this will notify all the listeners of this [CodeEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this method should only be called between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  void clearComposing() {
    value = value.copyWith(composing: TextRange.empty);
  }
}

/// A basic text input field.
///
/// This widget interacts with the [TextInput] service to let the user edit the
/// text it contains. It also provides scrolling, selection, and cursor
/// movement. This widget does not provide any focus management (e.g.,
/// tap-to-focus).
///
/// ## Input Actions
///
/// A [TextInputAction] can be provided to customize the appearance of the
/// action button on the soft keyboard for Android and iOS. The default action
/// is [TextInputAction.done].
///
/// Many [TextInputAction]s are common between Android and iOS. However, if an
/// [inputAction] is provided that is not supported by the current
/// platform in debug mode, an error will be thrown when the corresponding
/// CodeEditableText receives focus. For example, providing iOS's "emergencyCall"
/// action when running on an Android device will result in an error when in
/// debug mode. In release mode, incompatible [TextInputAction]s are replaced
/// either with "unspecified" on Android, or "default" on iOS. Appropriate
/// [inputAction]s can be chosen by checking the current platform and then
/// selecting the appropriate action.
///
/// ## Lifecycle
///
/// Upon completion of editing, like pressing the "done" button on the keyboard,
/// two actions take place:
///
///   1st: Editing is finalized. The default behavior of this step includes
///   an invocation of [onChanged]. That default behavior can be overridden.
///   See [onEditingComplete] for details.
///
///   2nd: [onSubmitted] is invoked with the user's input value.
///
/// [onSubmitted] can be used to manually move focus to another input widget
/// when a user finishes with the currently focused input widget.
///
/// Rather than using this widget directly, consider using [TextField], which
/// is a full-featured, material-design text input field with placeholder text,
/// labels, and [Form] integration.
///
/// ## Gesture Events Handling
///
/// This widget provides rudimentary, platform-agnostic gesture handling for
/// user actions such as tapping, long-pressing and scrolling when
/// [rendererIgnoresPointer] is false (false by default). To tightly conform
/// to the platform behavior with respect to input gestures in text fields, use
/// [TextField] or [CupertinoTextField]. For custom selection behavior, call
/// methods such as [RenderEditable.selectPosition],
/// [RenderEditable.selectWord], etc. programmatically.
///
/// See also:
///
///  * [TextField], which is a full-featured, material-design text input field
///    with placeholder text, labels, and [Form] integration.
class CodeEditableText extends StatefulWidget {
  /// Creates a basic text input control.
  ///
  /// The [maxLines] property can be set to null to remove the restriction on
  /// the number of lines. By default, it is one, meaning this is a single-line
  /// text field. [maxLines] must be null or greater than zero.
  ///
  /// If [keyboardType] is not set or is null, it will default to
  /// [TextInputType.text] unless [maxLines] is greater than one, when it will
  /// default to [TextInputType.multiline].
  ///
  /// The text cursor is not shown if [showCursor] is false or if [showCursor]
  /// is null (the default) and [readOnly] is true.
  ///
  /// The [controller], [focusNode], [style], [cursorColor], [backgroundCursorColor],
  /// [textAlign], [dragStartBehavior], [rendererIgnoresPointer] and [readOnly]
  /// arguments must not be null.
  CodeEditableText({
    Key key,
    @required this.controller,
    @required this.focusNode,
    this.readOnly = false,
    this.autocorrect = false,
    @required this.style,
    StrutStyle strutStyle,
    @required this.cursorColor,
    @required this.backgroundCursorColor,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.locale,
    this.textScaleFactor,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.autofocus = false,
    bool showCursor,
    this.showSelectionHandles = false,
    this.selectionColor,
    this.selectionControls,
    TextInputType keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onSelectionChanged,
    this.onSelectionHandleTapped,
    List<TextInputFormatter> inputFormatters,
    this.rendererIgnoresPointer = false,
    this.cursorWidth = 2.0,
    this.cursorRadius,
    this.cursorOpacityAnimates = false,
    this.cursorOffset,
    this.paintCursorAboveText = false,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.keyboardAppearance = Brightness.light,
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection,
    this.scrollController,
    this.scrollPhysics,
    @required this.highlighter,
  })  : assert(controller != null),
        assert(focusNode != null),
        assert(autocorrect != null),
        assert(showSelectionHandles != null),
        assert(readOnly != null),
        assert(style != null),
        assert(cursorColor != null),
        assert(cursorOpacityAnimates != null),
        assert(paintCursorAboveText != null),
        assert(backgroundCursorColor != null),
        assert(textAlign != null),
        assert(highlighter != null),
        assert(maxLines == null || maxLines > 0),
        assert(minLines == null || minLines > 0),
        assert(
          (maxLines == null) || (minLines == null) || (maxLines >= minLines),
          'minLines can\'t be greater than maxLines',
        ),
        assert(expands != null),
        assert(
          !expands || (maxLines == null && minLines == null),
          'minLines and maxLines must be null when expands is true.',
        ),
        assert(autofocus != null),
        assert(rendererIgnoresPointer != null),
        assert(scrollPadding != null),
        assert(dragStartBehavior != null),
        _strutStyle = strutStyle,
        keyboardType = keyboardType ??
            (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
        inputFormatters = maxLines == 1
            ? (<TextInputFormatter>[
                BlacklistingTextInputFormatter.singleLineFormatter
              ]..addAll(
                inputFormatters ?? const Iterable<TextInputFormatter>.empty()))
            : inputFormatters,
        showCursor = showCursor ?? !readOnly,
        super(key: key);

  /// Controls the text being edited.
  final CodeEditingController controller;

  /// Controls whether this widget has keyboard focus.
  final FocusNode focusNode;

  /// Code Highlighter
  final CodeEditingValueHighlighterBase highlighter;

  /// {@template flutter.widgets.CodeEditableText.readOnly}
  /// Whether the text can be changed.
  ///
  /// When this is set to true, the text cannot be modified
  /// by any shortcut or keyboard operation. The text is still selectable.
  ///
  /// Defaults to false. Must not be null.
  /// {@endtemplate}
  final bool readOnly;

  /// Whether to show selection handles.
  ///
  /// When a selection is active, there will be two handles at each side of
  /// boundary, or one handle if the selection is collapsed. The handles can be
  /// dragged to adjust the selection.
  ///
  /// See also:
  ///
  ///  * [showCursor], which controls the visibility of the cursor..
  final bool showSelectionHandles;

  /// {@template flutter.widgets.CodeEditableText.showCursor}
  /// Whether to show cursor.
  ///
  /// The cursor refers to the blinking caret when the [CodeEditableText] is focused.
  ///
  /// See also:
  ///
  ///  * [showSelectionHandles], which controls the visibility of the selection handles..
  /// {@endtemplate}
  final bool showCursor;

  /// {@template flutter.widgets.CodeEditableText.autocorrect}
  /// Whether to enable autocorrection.
  ///
  /// Defaults to true. Cannot be null.
  /// {@endtemplate}
  final bool autocorrect;

  /// The text style to use for the editable text.
  final TextStyle style;

  /// {@template flutter.widgets.CodeEditableText.strutStyle}
  /// The strut style used for the vertical layout.
  ///
  /// [StrutStyle] is used to establish a predictable vertical layout.
  /// Since fonts may vary depending on user input and due to font
  /// fallback, [StrutStyle.forceStrutHeight] is enabled by default
  /// to lock all lines to the height of the base [TextStyle], provided by
  /// [style]. This ensures the typed text fits within the allotted space.
  ///
  /// If null, the strut used will is inherit values from the [style] and will
  /// have [StrutStyle.forceStrutHeight] set to true. When no [style] is
  /// passed, the theme's [TextStyle] will be used to generate [strutStyle]
  /// instead.
  ///
  /// To disable strut-based vertical alignment and allow dynamic vertical
  /// layout based on the glyphs typed, use [StrutStyle.disabled].
  ///
  /// Flutter's strut is based on [typesetting strut](https://en.wikipedia.org/wiki/Strut_(typesetting))
  /// and CSS's [line-height](https://www.w3.org/TR/CSS2/visudet.html#line-height).
  /// {@endtemplate}
  ///
  /// Within editable text and textfields, [StrutStyle] will not use its standalone
  /// default values, and will instead inherit omitted/null properties from the
  /// [TextStyle] instead. See [StrutStyle.inheritFromTextStyle].
  StrutStyle get strutStyle {
    if (_strutStyle == null) {
      return style != null
          ? StrutStyle.fromTextStyle(style, forceStrutHeight: true)
          : StrutStyle.disabled;
    }
    return _strutStyle.inheritFromTextStyle(style);
  }

  final StrutStyle _strutStyle;

  /// {@template flutter.widgets.CodeEditableText.textAlign}
  /// How the text should be aligned horizontally.
  ///
  /// Defaults to [TextAlign.start] and cannot be null.
  /// {@endtemplate}
  final TextAlign textAlign;

  /// {@template flutter.widgets.CodeEditableText.textDirection}
  /// The directionality of the text.
  ///
  /// This decides how [textAlign] values like [TextAlign.start] and
  /// [TextAlign.end] are interpreted.
  ///
  /// This is also used to disambiguate how to render bidirectional text. For
  /// example, if the text is an English phrase followed by a Hebrew phrase,
  /// in a [TextDirection.ltr] context the English phrase will be on the left
  /// and the Hebrew phrase to its right, while in a [TextDirection.rtl]
  /// context, the English phrase will be on the right and the Hebrew phrase on
  /// its left.
  ///
  /// Defaults to the ambient [Directionality], if any.
  ///
  /// See also:
  ///
  ///   * {@macro flutter.gestures.monodrag.dragStartExample}
  ///
  /// {@endtemplate}
  final TextDirection textDirection;

  /// {@template flutter.widgets.CodeEditableText.textCapitalization}
  /// Configures how the platform keyboard will select an uppercase or
  /// lowercase keyboard.
  ///
  /// Only supports text keyboards, other keyboard types will ignore this
  /// configuration. Capitalization is locale-aware.
  ///
  /// Defaults to [TextCapitalization.none]. Must not be null.
  ///
  /// See also:
  ///
  ///  * [TextCapitalization], for a description of each capitalization behavior.
  ///
  /// {@endtemplate}
  final TextCapitalization textCapitalization;

  /// Used to select a font when the same Unicode character can
  /// be rendered differently, depending on the locale.
  ///
  /// It's rarely necessary to set this property. By default its value
  /// is inherited from the enclosing app with `Localizations.localeOf(context)`.
  ///
  /// See [RenderEditable.locale] for more information.
  final Locale locale;

  /// The number of font pixels for each logical pixel.
  ///
  /// For example, if the text scale factor is 1.5, text will be 50% larger than
  /// the specified font size.
  ///
  /// Defaults to the [MediaQueryData.textScaleFactor] obtained from the ambient
  /// [MediaQuery], or 1.0 if there is no [MediaQuery] in scope.
  final double textScaleFactor;

  /// The color to use when painting the cursor.
  ///
  /// Cannot be null.
  final Color cursorColor;

  /// The color to use when painting the background cursor aligned with the text
  /// while rendering the floating cursor.
  ///
  /// Cannot be null. By default it is the disabled grey color from
  /// CupertinoColors.
  final Color backgroundCursorColor;

  /// {@template flutter.widgets.CodeEditableText.maxLines}
  /// The maximum number of lines for the text to span, wrapping if necessary.
  ///
  /// If this is 1 (the default), the text will not wrap, but will scroll
  /// horizontally instead.
  ///
  /// If this is null, there is no limit to the number of lines, and the text
  /// container will start with enough vertical space for one line and
  /// automatically grow to accommodate additional lines as they are entered.
  ///
  /// If this is not null, the value must be greater than zero, and it will lock
  /// the input to the given number of lines and take up enough horizontal space
  /// to accommodate that number of lines. Setting [minLines] as well allows the
  /// input to grow between the indicated range.
  ///
  /// The full set of behaviors possible with [minLines] and [maxLines] are as
  /// follows. These examples apply equally to `TextField`, `TextFormField`, and
  /// `CodeEditableText`.
  ///
  /// Input that occupies a single line and scrolls horizontally as needed.
  /// ```dart
  /// TextField()
  /// ```
  ///
  /// Input whose height grows from one line up to as many lines as needed for
  /// the text that was entered. If a height limit is imposed by its parent, it
  /// will scroll vertically when its height reaches that limit.
  /// ```dart
  /// TextField(maxLines: null)
  /// ```
  ///
  /// The input's height is large enough for the given number of lines. If
  /// additional lines are entered the input scrolls vertically.
  /// ```dart
  /// TextField(maxLines: 2)
  /// ```
  ///
  /// Input whose height grows with content between a min and max. An infinite
  /// max is possible with `maxLines: null`.
  /// ```dart
  /// TextField(minLines: 2, maxLines: 4)
  /// ```
  /// {@endtemplate}
  final int maxLines;

  /// {@template flutter.widgets.CodeEditableText.minLines}
  /// The minimum number of lines to occupy when the content spans fewer lines.

  /// When [maxLines] is set as well, the height will grow between the indicated
  /// range of lines. When [maxLines] is null, it will grow as high as needed,
  /// starting from [minLines].
  ///
  /// See the examples in [maxLines] for the complete picture of how [maxLines]
  /// and [minLines] interact to produce various behaviors.
  ///
  /// Defaults to null.
  /// {@endtemplate}
  final int minLines;

  /// {@template flutter.widgets.CodeEditableText.expands}
  /// Whether this widget's height will be sized to fill its parent.
  ///
  /// If set to true and wrapped in a parent widget like [Expanded] or
  /// [SizedBox], the input will expand to fill the parent.
  ///
  /// [maxLines] and [minLines] must both be null when this is set to true,
  /// otherwise an error is thrown.
  ///
  /// Defaults to false.
  ///
  /// See the examples in [maxLines] for the complete picture of how [maxLines],
  /// [minLines], and [expands] interact to produce various behaviors.
  ///
  /// Input that matches the height of its parent
  /// ```dart
  /// Expanded(
  ///   child: TextField(maxLines: null, expands: true),
  /// )
  /// ```
  /// {@endtemplate}
  final bool expands;

  /// {@template flutter.widgets.CodeEditableText.autofocus}
  /// Whether this text field should focus itself if nothing else is already
  /// focused.
  ///
  /// If true, the keyboard will open as soon as this text field obtains focus.
  /// Otherwise, the keyboard is only shown after the user taps the text field.
  ///
  /// Defaults to false. Cannot be null.
  /// {@endtemplate}
  // See https://github.com/flutter/flutter/issues/7035 for the rationale for this
  // keyboard behavior.
  final bool autofocus;

  /// The color to use when painting the selection.
  final Color selectionColor;

  /// Optional delegate for building the text selection handles and toolbar.
  ///
  /// The [CodeEditableText] widget used on its own will not trigger the display
  /// of the selection toolbar by itself. The toolbar is shown by calling
  /// [CodeEditableTextState.showToolbar] in response to an appropriate user event.
  ///
  /// See also:
  ///
  ///  * [CupertinoTextField], which wraps an [CodeEditableText] and which shows the
  ///    selection toolbar upon user events that are appropriate on the iOS
  ///    platform.
  ///  * [TextField], a Material Design themed wrapper of [CodeEditableText], which
  ///    shows the selection toolbar upon appropriate user events based on the
  ///    user's platform set in [ThemeData.platform].
  final cs.TextSelectionControls selectionControls;

  /// {@template flutter.widgets.CodeEditableText.keyboardType}
  /// The type of keyboard to use for editing the text.
  ///
  /// Defaults to [TextInputType.text] if [maxLines] is one and
  /// [TextInputType.multiline] otherwise.
  /// {@endtemplate}
  final TextInputType keyboardType;

  /// The type of action button to use with the soft keyboard.
  final TextInputAction textInputAction;

  /// {@template flutter.widgets.CodeEditableText.onChanged}
  /// Called when the user initiates a change to the TextField's
  /// value: when they have inserted or deleted text.
  ///
  /// This callback doesn't run when the TextField's text is changed
  /// programmatically, via the TextField's [controller]. Typically it
  /// isn't necessary to be notified of such changes, since they're
  /// initiated by the app itself.
  ///
  /// To be notified of all changes to the TextField's text, cursor,
  /// and selection, one can add a listener to its [controller] with
  /// [CodeEditingController.addListener].
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [inputFormatters], which are called before [onChanged]
  ///    runs and can validate and change ("format") the input value.
  ///  * [onEditingComplete], [onSubmitted], [onSelectionChanged]:
  ///    which are more specialized input change notifications.
  final ValueChanged<String> onChanged;

  /// {@template flutter.widgets.CodeEditableText.onEditingComplete}
  /// Called when the user submits editable content (e.g., user presses the "done"
  /// button on the keyboard).
  ///
  /// The default implementation of [onEditingComplete] executes 2 different
  /// behaviors based on the situation:
  ///
  ///  - When a completion action is pressed, such as "done", "go", "send", or
  ///    "search", the user's content is submitted to the [controller] and then
  ///    focus is given up.
  ///
  ///  - When a non-completion action is pressed, such as "next" or "previous",
  ///    the user's content is submitted to the [controller], but focus is not
  ///    given up because developers may want to immediately move focus to
  ///    another input widget within [onSubmitted].
  ///
  /// Providing [onEditingComplete] prevents the aforementioned default behavior.
  /// {@endtemplate}
  final VoidCallback onEditingComplete;

  /// {@template flutter.widgets.CodeEditableText.onSubmitted}
  /// Called when the user indicates that they are done editing the text in the
  /// field.
  /// {@endtemplate}
  final ValueChanged<String> onSubmitted;

  /// Called when the user changes the selection of text (including the cursor
  /// location).
  final SelectionChangedCallback onSelectionChanged;

  /// {@macro flutter.widgets.textSelection.onSelectionHandleTapped}
  final VoidCallback onSelectionHandleTapped;

  /// {@template flutter.widgets.CodeEditableText.inputFormatters}
  /// Optional input validation and formatting overrides.
  ///
  /// Formatters are run in the provided order when the text input changes.
  /// {@endtemplate}
  final List<TextInputFormatter> inputFormatters;

  /// If true, the [RenderEditable] created by this widget will not handle
  /// pointer events, see [renderEditable] and [RenderEditable.ignorePointer].
  ///
  /// This property is false by default.
  final bool rendererIgnoresPointer;

  /// {@template flutter.widgets.CodeEditableText.cursorWidth}
  /// How thick the cursor will be.
  ///
  /// Defaults to 2.0
  ///
  /// The cursor will draw under the text. The cursor width will extend
  /// to the right of the boundary between characters for left-to-right text
  /// and to the left for right-to-left text. This corresponds to extending
  /// downstream relative to the selected position. Negative values may be used
  /// to reverse this behavior.
  /// {@endtemplate}
  final double cursorWidth;

  /// {@template flutter.widgets.CodeEditableText.cursorRadius}
  /// How rounded the corners of the cursor should be.
  ///
  /// By default, the cursor has no radius.
  /// {@endtemplate}
  final Radius cursorRadius;

  /// Whether the cursor will animate from fully transparent to fully opaque
  /// during each cursor blink.
  ///
  /// By default, the cursor opacity will animate on iOS platforms and will not
  /// animate on Android platforms.
  final bool cursorOpacityAnimates;

  ///{@macro flutter.rendering.editable.cursorOffset}
  final Offset cursorOffset;

  ///{@macro flutter.rendering.editable.paintCursorOnTop}
  final bool paintCursorAboveText;

  /// The appearance of the keyboard.
  ///
  /// This setting is only honored on iOS devices.
  ///
  /// Defaults to [Brightness.light].
  final Brightness keyboardAppearance;

  /// {@template flutter.widgets.CodeEditableText.scrollPadding}
  /// Configures padding to edges surrounding a [Scrollable] when the Textfield scrolls into view.
  ///
  /// When this widget receives focus and is not completely visible (for example scrolled partially
  /// off the screen or overlapped by the keyboard)
  /// then it will attempt to make itself visible by scrolling a surrounding [Scrollable], if one is present.
  /// This value controls how far from the edges of a [Scrollable] the TextField will be positioned after the scroll.
  ///
  /// Defaults to EdgeInserts.all(20.0).
  /// {@endtemplate}
  final EdgeInsets scrollPadding;

  /// {@template flutter.widgets.CodeEditableText.enableInteractiveSelection}
  /// If true, then long-pressing this TextField will select text and show the
  /// cut/copy/paste menu, and tapping will move the text caret.
  ///
  /// True by default.
  ///
  /// If false, most of the accessibility support for selecting text, copy
  /// and paste, and moving the caret will be disabled.
  /// {@endtemplate}
  final bool enableInteractiveSelection;

  /// Setting this property to true makes the cursor stop blinking or fading
  /// on and off once the cursor appears on focus. This property is useful for
  /// testing purposes.
  ///
  /// It does not affect the necessity to focus the CodeEditableText for the cursor
  /// to appear in the first place.
  ///
  /// Defaults to false, resulting in a typical blinking cursor.
  static bool debugDeterministicCursor = false;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// {@template flutter.widgets.CodeEditableText.scrollController}
  /// The [ScrollController] to use when vertically scrolling the input.
  ///
  /// If null, it will instantiate a new ScrollController.
  ///
  /// See [Scrollable.controller].
  /// {@endtemplate}
  final ScrollController scrollController;

  /// {@template flutter.widgets.CodeEditableText.scrollPhysics}
  /// The [ScrollPhysics] to use when vertically scrolling the input.
  ///
  /// If not specified, it will behave according to the current platform.
  ///
  /// See [Scrollable.physics].
  /// {@endtemplate}
  final ScrollPhysics scrollPhysics;

  /// {@macro flutter.rendering.editable.selectionEnabled}
  bool get selectionEnabled {
    return enableInteractiveSelection ?? true;
  }

  @override
  CodeEditableTextState createState() => CodeEditableTextState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        DiagnosticsProperty<CodeEditingController>('controller', controller));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode));
    properties.add(DiagnosticsProperty<bool>('autocorrect', autocorrect,
        defaultValue: true));
    style?.debugFillProperties(properties);
    properties.add(
        EnumProperty<TextAlign>('textAlign', textAlign, defaultValue: null));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
    properties
        .add(DiagnosticsProperty<Locale>('locale', locale, defaultValue: null));
    properties.add(
        DoubleProperty('textScaleFactor', textScaleFactor, defaultValue: null));
    properties.add(IntProperty('maxLines', maxLines, defaultValue: 1));
    properties.add(IntProperty('minLines', minLines, defaultValue: null));
    properties.add(
        DiagnosticsProperty<bool>('expands', expands, defaultValue: false));
    properties.add(
        DiagnosticsProperty<bool>('autofocus', autofocus, defaultValue: false));
    properties.add(DiagnosticsProperty<TextInputType>(
        'keyboardType', keyboardType,
        defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollController>(
        'scrollController', scrollController,
        defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollPhysics>(
        'scrollPhysics', scrollPhysics,
        defaultValue: null));
  }
}

/// State for a [CodeEditableText].
class CodeEditableTextState extends State<CodeEditableText>
    with
        AutomaticKeepAliveClientMixin<CodeEditableText>,
        WidgetsBindingObserver,
        TickerProviderStateMixin<CodeEditableText>
    implements TextInputClient, TextSelectionDelegate {
  Timer _cursorTimer;
  bool _targetCursorVisibility = false;
  final ValueNotifier<bool> _cursorVisibilityNotifier =
      ValueNotifier<bool>(true);
  final GlobalKey _editableKey = GlobalKey();

  CodeEditingValueHighlighterBase _highlighter;

  TextInputConnection _textInputConnection;
  cs.TextSelectionOverlay _selectionOverlay;

  ScrollController _scrollController;

  AnimationController _cursorBlinkOpacityController;

  final LayerLink _layerLink = LayerLink();
  bool _didAutoFocus = false;
  FocusAttachment _focusAttachment;

  // This value is an eyeball estimation of the time it takes for the iOS cursor
  // to ease in and out.
  static const Duration _fadeDuration = Duration(milliseconds: 250);

  // The time it takes for the floating cursor to snap to the text aligned
  // cursor position after the user has finished placing it.
  static const Duration _floatingCursorResetTime = Duration(milliseconds: 125);

  AnimationController _floatingCursorResetController;

  @override
  bool get wantKeepAlive => widget.focusNode.hasFocus;

  Color get _cursorColor =>
      widget.cursorColor.withOpacity(_cursorBlinkOpacityController.value);

  @override
  bool get cutEnabled => !widget.readOnly;

  @override
  bool get copyEnabled => true;

  @override
  bool get pasteEnabled => !widget.readOnly;

  @override
  bool get selectAllEnabled => true;

  // State lifecycle:

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_didChangeCodeEditingValue);
    _focusAttachment = widget.focusNode.attach(context);
    widget.focusNode.addListener(_handleFocusChanged);
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(() {
      _selectionOverlay?.updateForScroll();
    });
    _cursorBlinkOpacityController =
        AnimationController(vsync: this, duration: _fadeDuration);
    _cursorBlinkOpacityController.addListener(_onCursorColorTick);
    _floatingCursorResetController = AnimationController(vsync: this);
    _floatingCursorResetController.addListener(_onFloatingCursorResetTick);
    _cursorVisibilityNotifier.value = widget.showCursor;

    _highlighter = widget.highlighter;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoFocus && widget.autofocus) {
      FocusScope.of(context).autofocus(widget.focusNode);
      _didAutoFocus = true;
    }
  }

  _toTextEditingValue(CodeEditingValue codeEditingValue) {
    return TextEditingValue(
        text: codeEditingValue.text,
        composing: codeEditingValue.composing,
        selection: codeEditingValue.selection);
  }

  @override
  void didUpdateWidget(CodeEditableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_didChangeCodeEditingValue);
      widget.controller.addListener(_didChangeCodeEditingValue);
      _updateRemoteEditingValueIfNeeded();
    }
    if (widget.controller.selection != oldWidget.controller.selection) {
      _selectionOverlay?.update(_toTextEditingValue(_value));
    }
    _selectionOverlay?.handlesVisible = widget.showSelectionHandles;
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      _focusAttachment?.detach();
      _focusAttachment = widget.focusNode.attach(context);
      widget.focusNode.addListener(_handleFocusChanged);
      updateKeepAlive();
    }
    if (widget.readOnly) {
      _closeInputConnectionIfNeeded();
    } else {
      if (oldWidget.readOnly && _hasFocus) _openInputConnection();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_didChangeCodeEditingValue);
    _cursorBlinkOpacityController.removeListener(_onCursorColorTick);
    _floatingCursorResetController.removeListener(_onFloatingCursorResetTick);
    _closeInputConnectionIfNeeded();
    assert(!_hasInputConnection);
    _stopCursorTimer();
    assert(_cursorTimer == null);
    _selectionOverlay?.dispose();
    _selectionOverlay = null;
    _focusAttachment.detach();
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  // TextInputClient implementation:

  CodeEditingValue _lastKnownRemoteCodeEditingValue;

  @override
  void updateEditingValue(TextEditingValue value) {
    // Since we still have to support keyboard select, this is the best place
    // to disable text updating.
    if (widget.readOnly) {
      return;
    }

    if (value.text != _value.text) {
      _hideSelectionOverlayIfNeeded();
      _showCaretOnScreen();
    }

    var newValue = new CodeEditingValue(
      value: new TextSpan(text: value.text, style: widget.style),
      selection: new TextSelection(
        baseOffset: value.selection.baseOffset ?? -1,
        extentOffset: value.selection.extentOffset ?? -1,
        affinity: TextAffinity.downstream,
        isDirectional: value.selection.isDirectional ?? false,
      ),
      composing: new TextRange(
        start: value.composing.start ?? -1,
        end: value.composing.end ?? -1,
      ),
      remotelyEdited: false,
    );

    if (_lastKnownRemoteCodeEditingValue.text == value.text &&
        !pendingPasteUpdate) {
      // There is no difference between this value and the last known value text.
      return;
    }

    _lastKnownRemoteCodeEditingValue = newValue;
    _formatAndSetValue(newValue);

    // To keep the cursor from blinking while typing, we want to restart the
    // cursor timer every time a new character is typed.
    _stopCursorTimer(resetCharTicks: false);
    _startCursorTimer();
  }

  @override
  void performAction(TextInputAction action) {
    switch (action) {
      case TextInputAction.newline:
        // If this is a multiline CodeEditableText, do nothing for a "newline"
        // action; The newline is already inserted. Otherwise, finalize
        // editing.
        if (!_isMultiline) _finalizeEditing(true);
        break;
      case TextInputAction.done:
      case TextInputAction.go:
      case TextInputAction.send:
      case TextInputAction.search:
        _finalizeEditing(true);
        break;
      default:
        // Finalize editing, but don't give up focus because this keyboard
        //  action does not imply the user is done inputting information.
        _finalizeEditing(false);
        break;
    }
  }

  // The original position of the caret on FloatingCursorDragState.start.
  Rect _startCaretRect;

  // The most recent text position as determined by the location of the floating
  // cursor.
  TextPosition _lastTextPosition;

  // The offset of the floating cursor as determined from the first update call.
  Offset _pointOffsetOrigin;

  // The most recent position of the floating cursor.
  Offset _lastBoundedOffset;

  // Because the center of the cursor is preferredLineHeight / 2 below the touch
  // origin, but the touch origin is used to determine which line the cursor is
  // on, we need this offset to correctly render and move the cursor.
  Offset get _floatingCursorOffset =>
      Offset(0, renderEditable.preferredLineHeight / 2);

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    switch (point.state) {
      case FloatingCursorDragState.Start:
        if (_floatingCursorResetController.isAnimating) {
          _floatingCursorResetController.stop();
          _onFloatingCursorResetTick();
        }
        final TextPosition currentTextPosition =
            TextPosition(offset: renderEditable.selection.baseOffset);
        _startCaretRect =
            renderEditable.getLocalRectForCaret(currentTextPosition);
        renderEditable.setFloatingCursor(
            point.state,
            _startCaretRect.center - _floatingCursorOffset,
            currentTextPosition);
        break;
      case FloatingCursorDragState.Update:
        // We want to send in points that are centered around a (0,0) origin, so we cache the
        // position on the first update call.
        if (_pointOffsetOrigin != null) {
          final Offset centeredPoint = point.offset - _pointOffsetOrigin;
          final Offset rawCursorOffset =
              _startCaretRect.center + centeredPoint - _floatingCursorOffset;
          _lastBoundedOffset = renderEditable
              .calculateBoundedFloatingCursorOffset(rawCursorOffset);
          _lastTextPosition = renderEditable.getPositionForPoint(renderEditable
              .localToGlobal(_lastBoundedOffset + _floatingCursorOffset));
          renderEditable.setFloatingCursor(
              point.state, _lastBoundedOffset, _lastTextPosition);
        } else {
          _pointOffsetOrigin = point.offset;
        }
        break;
      case FloatingCursorDragState.End:
        _floatingCursorResetController.value = 0.0;
        _floatingCursorResetController.animateTo(1.0,
            duration: _floatingCursorResetTime, curve: Curves.decelerate);
        break;
    }
  }

  void _onFloatingCursorResetTick() {
    final Offset finalPosition =
        renderEditable.getLocalRectForCaret(_lastTextPosition).centerLeft -
            _floatingCursorOffset;
    if (_floatingCursorResetController.isCompleted) {
      renderEditable.setFloatingCursor(
          FloatingCursorDragState.End, finalPosition, _lastTextPosition);
      if (_lastTextPosition.offset != renderEditable.selection.baseOffset)
        // The cause is technically the force cursor, but the cause is listed as tap as the desired functionality is the same.
        _handleSelectionChanged(
            TextSelection.collapsed(offset: _lastTextPosition.offset),
            renderEditable,
            ce.SelectionChangedCause.forcePress);
      _startCaretRect = null;
      _lastTextPosition = null;
      _pointOffsetOrigin = null;
      _lastBoundedOffset = null;
    } else {
      final double lerpValue = _floatingCursorResetController.value;
      final double lerpX =
          ui.lerpDouble(_lastBoundedOffset.dx, finalPosition.dx, lerpValue);
      final double lerpY =
          ui.lerpDouble(_lastBoundedOffset.dy, finalPosition.dy, lerpValue);

      renderEditable.setFloatingCursor(FloatingCursorDragState.Update,
          Offset(lerpX, lerpY), _lastTextPosition,
          resetLerpValue: lerpValue);
    }
  }

  void _finalizeEditing(bool shouldUnfocus) {
    // Take any actions necessary now that the user has completed editing.
    if (widget.onEditingComplete != null) {
      widget.onEditingComplete();
    } else {
      // Default behavior if the developer did not provide an
      // onEditingComplete callback: Finalize editing and remove focus.
      widget.controller.clearComposing();
      if (shouldUnfocus) widget.focusNode.unfocus();
    }

    // Invoke optional callback with the user's submitted content.
    if (widget.onSubmitted != null) widget.onSubmitted(_value.text);
  }

  void _updateRemoteEditingValueIfNeeded() {
    if (!_hasInputConnection) return;
    final CodeEditingValue localValue = _value;
    if (localValue == _lastKnownRemoteCodeEditingValue) return;
    _lastKnownRemoteCodeEditingValue = localValue;
    _textInputConnection.setEditingState(_toTextEditingValue(localValue));
  }

  void updateRemoteEditingValue(CodeEditingValue newValue) {
    _lastKnownRemoteCodeEditingValue = newValue;
    _textInputConnection.setEditingState(_toTextEditingValue(newValue));
  }

  CodeEditingValue get _value => widget.controller.value;
  set _value(CodeEditingValue value) {
    widget.controller.value = value;
  }

  bool get _hasFocus => widget.focusNode.hasFocus;
  bool get _isMultiline => widget.maxLines != 1;

  // Calculate the new scroll offset so the cursor remains visible.
  double _getScrollOffsetForCaret(Rect caretRect) {
    double caretStart;
    double caretEnd;
    if (_isMultiline) {
      // The caret is vertically centered within the line. Expand the caret's
      // height so that it spans the line because we're going to ensure that the entire
      // expanded caret is scrolled into view.
      final double lineHeight = renderEditable.preferredLineHeight;
      final double caretOffset = (lineHeight - caretRect.height) / 2;
      caretStart = caretRect.top - caretOffset;
      caretEnd = caretRect.bottom + caretOffset;
    } else {
      caretStart = caretRect.left;
      caretEnd = caretRect.right;
    }

    double scrollOffset = _scrollController.offset;
    final double viewportExtent = _scrollController.position.viewportDimension;
    if (caretStart < 0.0) {
      // cursor before start of bounds
      scrollOffset += caretStart;
    } else if (caretEnd >= viewportExtent) {
      // cursor after end of bounds
      scrollOffset += caretEnd - viewportExtent;
    }
    return scrollOffset;
  }

  // Calculates where the `caretRect` would be if `_scrollController.offset` is set to `scrollOffset`.
  Rect _getCaretRectAtScrollOffset(Rect caretRect, double scrollOffset) {
    final double offsetDiff = _scrollController.offset - scrollOffset;
    return _isMultiline
        ? caretRect.translate(0.0, offsetDiff)
        : caretRect.translate(offsetDiff, 0.0);
  }

  bool get _hasInputConnection =>
      _textInputConnection != null && _textInputConnection.attached;

  void _openInputConnection() {
    if (widget.readOnly) {
      return;
    }
    if (!_hasInputConnection) {
      final CodeEditingValue localValue = _value;
      _lastKnownRemoteCodeEditingValue = localValue;
      _textInputConnection = TextInput.attach(
        this,
        TextInputConfiguration(
          inputType: widget.keyboardType,
          obscureText: false,
          autocorrect: widget.autocorrect,
          inputAction: widget.textInputAction ??
              (widget.keyboardType == TextInputType.multiline
                  ? TextInputAction.newline
                  : TextInputAction.done),
          textCapitalization: widget.textCapitalization,
          keyboardAppearance: widget.keyboardAppearance,
        ),
      )..setEditingState(_toTextEditingValue(localValue));
    }
    _textInputConnection.show();
  }

  void _closeInputConnectionIfNeeded() {
    if (_hasInputConnection) {
      _textInputConnection.close();
      _textInputConnection = null;
      _lastKnownRemoteCodeEditingValue = null;
    }
  }

  void _openOrCloseInputConnectionIfNeeded() {
    if (_hasFocus && widget.focusNode.consumeKeyboardToken()) {
      _openInputConnection();
    } else if (!_hasFocus) {
      _closeInputConnectionIfNeeded();
      widget.controller.clearComposing();
    }
  }

  /// Express interest in interacting with the keyboard.
  ///
  /// If this control is already attached to the keyboard, this function will
  /// request that the keyboard become visible. Otherwise, this function will
  /// ask the focus system that it become focused. If successful in acquiring
  /// focus, the control will then attach to the keyboard and request that the
  /// keyboard become visible.
  void requestKeyboard() {
    if (_hasFocus) {
      _openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  void _hideSelectionOverlayIfNeeded() {
    _selectionOverlay?.hide();
    _selectionOverlay = null;
  }

  void _updateOrDisposeSelectionOverlayIfNeeded() {
    if (_selectionOverlay != null) {
      if (_hasFocus) {
        _selectionOverlay.update(_toTextEditingValue(_value));
      } else {
        _selectionOverlay.dispose();
        _selectionOverlay = null;
      }
    }
  }

  /// If user tried to move the cursor to a tabbed space,
  /// push it to next available text's begining position.
  _resetSelectionPoint(int baseOffset) {
    if (widget.controller.value.value.children != null) {
      var mapItem = _highlighter.getSpanForPosition(
          widget.controller.value.value, baseOffset);

      if (mapItem != null && mapItem.length > 0) {
        var tabbedSpace = "    ";
        if (mapItem.values.first.text == tabbedSpace) {
          var afterBaseText =
              widget.controller.value.text.substring(baseOffset);
          var nextWordOffset =
              afterBaseText.length - afterBaseText.trimLeft().length;
          baseOffset = baseOffset + nextWordOffset;
        }
      }

      return TextSelection.fromPosition(TextPosition(offset: baseOffset));
    }
  }

  void _handleSelectionChanged(TextSelection selection,
      ce.RenderEditableCode renderObject, ce.SelectionChangedCause cause) {
    //the line below prevents users from moving the cursor selection to a tabbed space.
    //if you want to allow users to tap into tabbed space, you can probably uncomment the line below.
    //or you can also configure this with a parameter.
    widget.controller.selection = _resetSelectionPoint(selection.baseOffset);

    // This will show the keyboard for all selection changes on the
    // EditableWidget, not just changes triggered by user gestures.
    requestKeyboard();

    _hideSelectionOverlayIfNeeded();

    if (widget.selectionControls != null) {
      _selectionOverlay = cs.TextSelectionOverlay(
        context: context,
        value: _toTextEditingValue(_value),
        debugRequiredFor: widget,
        layerLink: _layerLink,
        renderObject: renderObject,
        selectionControls: widget.selectionControls,
        selectionDelegate: this,
        dragStartBehavior: widget.dragStartBehavior,
        onSelectionHandleTapped: widget.onSelectionHandleTapped,
      );
      _selectionOverlay.handlesVisible = widget.showSelectionHandles;
      _selectionOverlay.showHandles();
      if (widget.onSelectionChanged != null)
        widget.onSelectionChanged(selection, cause);
    }
  }

  bool _textChangedSinceLastCaretUpdate = false;
  Rect _currentCaretRect;

  void _handleCaretChanged(Rect caretRect) {
    _currentCaretRect = caretRect;
    // If the caret location has changed due to an update to the text or
    // selection, then scroll the caret into view.
    if (_textChangedSinceLastCaretUpdate) {
      _textChangedSinceLastCaretUpdate = false;
      _showCaretOnScreen();
    }
  }

  // Animation configuration for scrolling the caret back on screen.
  static const Duration _caretAnimationDuration = Duration(milliseconds: 100);
  static const Curve _caretAnimationCurve = Curves.fastOutSlowIn;

  bool _showCaretOnScreenScheduled = false;

  void _showCaretOnScreen() {
    if (_showCaretOnScreenScheduled) {
      return;
    }
    _showCaretOnScreenScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _showCaretOnScreenScheduled = false;
      if (_currentCaretRect == null || !_scrollController.hasClients) {
        return;
      }
      final double scrollOffsetForCaret =
          _getScrollOffsetForCaret(_currentCaretRect);
      _scrollController.animateTo(
        scrollOffsetForCaret,
        duration: _caretAnimationDuration,
        curve: _caretAnimationCurve,
      );
      final Rect newCaretRect =
          _getCaretRectAtScrollOffset(_currentCaretRect, scrollOffsetForCaret);
      // Enlarge newCaretRect by scrollPadding to ensure that caret is not
      // positioned directly at the edge after scrolling.
      double bottomSpacing = widget.scrollPadding.bottom;
      if (_selectionOverlay?.selectionControls != null) {
        final double handleHeight = _selectionOverlay.selectionControls
            .getHandleSize(renderEditable.preferredLineHeight)
            .height;
        final double interactiveHandleHeight = math.max(
          handleHeight,
          kMinInteractiveSize,
        );
        final Offset anchor =
            _selectionOverlay.selectionControls.getHandleAnchor(
          cs.TextSelectionHandleType.collapsed,
          renderEditable.preferredLineHeight,
        );
        final double handleCenter = handleHeight / 2 - anchor.dy;
        bottomSpacing = math.max(
          handleCenter + interactiveHandleHeight / 2,
          bottomSpacing,
        );
      }
      final Rect inflatedRect = Rect.fromLTRB(
        newCaretRect.left - widget.scrollPadding.left,
        newCaretRect.top - widget.scrollPadding.top,
        newCaretRect.right + widget.scrollPadding.right,
        newCaretRect.bottom + bottomSpacing,
      );
      _editableKey.currentContext.findRenderObject().showOnScreen(
            rect: inflatedRect,
            duration: _caretAnimationDuration,
            curve: _caretAnimationCurve,
          );
    });
  }

  double _lastBottomViewInset;

  @override
  void didChangeMetrics() {
    if (_lastBottomViewInset <
        WidgetsBinding.instance.window.viewInsets.bottom) {
      _showCaretOnScreen();
    }
    _lastBottomViewInset = WidgetsBinding.instance.window.viewInsets.bottom;
  }

  void _formatAndSetValue(CodeEditingValue value) {
    if (pendingPasteUpdate) {
      // in this case we need to update styles and setEditingState
      var _parsed = _highlighter.updateStyle(value);
      _lastKnownRemoteCodeEditingValue = _parsed;
      _textInputConnection.setEditingState(_toTextEditingValue(_parsed));
      _value = _parsed;
      return;
    }

    final bool textChanged = _value?.text != value?.text;
    if (textChanged) {
      var _parsed = _highlighter.parse(
          oldValue: _value, newValue: value, style: widget.style);
      if (_parsed.remotelyEdited) {
        _lastKnownRemoteCodeEditingValue = _parsed;
        _textInputConnection.setEditingState(_toTextEditingValue(_parsed));
      }
      _value = _parsed;
    }
    if (textChanged && widget.onChanged != null) widget.onChanged(value.text);
  }

  void _onCursorColorTick() {
    renderEditable.cursorColor =
        widget.cursorColor.withOpacity(_cursorBlinkOpacityController.value);
    _cursorVisibilityNotifier.value =
        widget.showCursor && _cursorBlinkOpacityController.value > 0;
  }

  /// Whether the blinking cursor is actually visible at this precise moment
  /// (it's hidden half the time, since it blinks).
  @visibleForTesting
  bool get cursorCurrentlyVisible => _cursorBlinkOpacityController.value > 0;

  /// The cursor blink interval (the amount of time the cursor is in the "on"
  /// state or the "off" state). A complete cursor blink period is twice this
  /// value (half on, half off).
  @visibleForTesting
  Duration get cursorBlinkInterval => _kCursorBlinkHalfPeriod;

  /// The current status of the text selection handles.
  @visibleForTesting
  cs.TextSelectionOverlay get selectionOverlay => _selectionOverlay;

  //if user tried to paste on the editor, this value sets to true
  bool pendingPasteUpdate = false;

  void _cursorTick(Timer timer) {
    _targetCursorVisibility = !_targetCursorVisibility;
    final double targetOpacity = _targetCursorVisibility ? 1.0 : 0.0;
    if (widget.cursorOpacityAnimates) {
      // If we want to show the cursor, we will animate the opacity to the value
      // of 1.0, and likewise if we want to make it disappear, to 0.0. An easing
      // curve is used for the animation to mimic the aesthetics of the native
      // iOS cursor.
      //
      // These values and curves have been obtained through eyeballing, so are
      // likely not exactly the same as the values for native iOS.
      _cursorBlinkOpacityController.animateTo(targetOpacity,
          curve: Curves.easeOut);
    } else {
      _cursorBlinkOpacityController.value = targetOpacity;
    }
  }

  void _cursorWaitForStart(Timer timer) {
    assert(_kCursorBlinkHalfPeriod > _fadeDuration);
    _cursorTimer?.cancel();
    _cursorTimer = Timer.periodic(_kCursorBlinkHalfPeriod, _cursorTick);
  }

  void _startCursorTimer() {
    _targetCursorVisibility = true;
    _cursorBlinkOpacityController.value = 1.0;
    if (CodeEditableText.debugDeterministicCursor) return;
    if (widget.cursorOpacityAnimates) {
      _cursorTimer =
          Timer.periodic(_kCursorBlinkWaitForStart, _cursorWaitForStart);
    } else {
      _cursorTimer = Timer.periodic(_kCursorBlinkHalfPeriod, _cursorTick);
    }
  }

  void _stopCursorTimer({bool resetCharTicks = true}) {
    _cursorTimer?.cancel();
    _cursorTimer = null;
    _targetCursorVisibility = false;
    _cursorBlinkOpacityController.value = 0.0;
    if (CodeEditableText.debugDeterministicCursor) return;
    if (widget.cursorOpacityAnimates) {
      _cursorBlinkOpacityController.stop();
      _cursorBlinkOpacityController.value = 0.0;
    }
  }

  void _startOrStopCursorTimerIfNeeded() {
    if (_cursorTimer == null && _hasFocus && _value.selection.isCollapsed)
      _startCursorTimer();
    else if (_cursorTimer != null &&
        (!_hasFocus || !_value.selection.isCollapsed)) _stopCursorTimer();
  }

  void _didChangeCodeEditingValue() {
    //update editing value required to be called during paste interaction only
    //_updateRemoteEditingValueIfNeeded();
    if (_value != null &&
        _lastKnownRemoteCodeEditingValue != null &&
        _value.text == _lastKnownRemoteCodeEditingValue.text &&
        _value.selection != _lastKnownRemoteCodeEditingValue.selection) {
      _updateRemoteEditingValueIfNeeded();
    }
    if (pendingPasteUpdate) {
      updateEditingValue(_toTextEditingValue(_value));
      pendingPasteUpdate = false;
    }
    _startOrStopCursorTimerIfNeeded();
    _updateOrDisposeSelectionOverlayIfNeeded();
    _textChangedSinceLastCaretUpdate = true;
    // TODO(abarth): Teach RenderEditable about ValueNotifier<CodeEditingValue>
    // to avoid this setState().
    setState(() {/* We use widget.controller.value in build(). */});
  }

  void _handleFocusChanged() {
    _openOrCloseInputConnectionIfNeeded();
    _startOrStopCursorTimerIfNeeded();
    _updateOrDisposeSelectionOverlayIfNeeded();
    if (_hasFocus) {
      // Listen for changing viewInsets, which indicates keyboard showing up.
      WidgetsBinding.instance.addObserver(this);
      _lastBottomViewInset = WidgetsBinding.instance.window.viewInsets.bottom;
      _showCaretOnScreen();
      if (!_value.selection.isValid) {
        // Place cursor at the end if the selection is invalid when we receive focus.
        widget.controller.selection =
            TextSelection.collapsed(offset: _value.text.length);
      }
    } else {
      WidgetsBinding.instance.removeObserver(this);
      // Clear the selection and composition state if this widget lost focus.
      _value = CodeEditingValue(value: _value.value);
    }
    updateKeepAlive();
  }

  TextDirection get _textDirection {
    final TextDirection result =
        widget.textDirection ?? Directionality.of(context);
    assert(result != null,
        '$runtimeType created without a textDirection and with no ambient Directionality.');
    return result;
  }

  /// The renderer for this widget's [Editable] descendant.
  ///
  /// This property is typically used to notify the renderer of input gestures
  /// when [ignorePointer] is true. See [RenderEditable.ignorePointer].
  ce.RenderEditableCode get renderEditable =>
      _editableKey.currentContext.findRenderObject();

  double get _devicePixelRatio =>
      MediaQuery.of(context).devicePixelRatio ?? 1.0;

  @override
  void bringIntoView(TextPosition position) {
    _scrollController.jumpTo(_getScrollOffsetForCaret(
        renderEditable.getLocalRectForCaret(position)));
  }

  /// Shows the selection toolbar at the location of the current cursor.
  ///
  /// Returns `false` if a toolbar couldn't be shown, such as when the toolbar
  /// is already shown, or when no text selection currently exists.
  bool showToolbar() {
    if (_selectionOverlay == null || _selectionOverlay.toolbarIsVisible) {
      return false;
    }

    _selectionOverlay.showToolbar();
    return true;
  }

  @override
  void hideToolbar() {
    _selectionOverlay?.hide();
  }

  /// Toggles the visibility of the toolbar.
  void toggleToolbar() {
    assert(_selectionOverlay != null);
    if (_selectionOverlay.toolbarIsVisible) {
      hideToolbar();
    } else {
      showToolbar();
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    _focusAttachment.reparent();
    super.build(context); // See AutomaticKeepAliveClientMixin.

    final cs.TextSelectionControls controls = widget.selectionControls;
    return Scrollable(
      excludeFromSemantics: true,
      axisDirection: _isMultiline ? AxisDirection.down : AxisDirection.right,
      controller: _scrollController,
      physics: widget.scrollPhysics,
      dragStartBehavior: widget.dragStartBehavior,
      viewportBuilder: (BuildContext context, ViewportOffset offset) {
        return CompositedTransformTarget(
          link: _layerLink,
          child: _Editable(
            key: _editableKey,
            textSpan: _value.value,
            value: _value,
            cursorColor: _cursorColor,
            backgroundCursorColor: widget.backgroundCursorColor,
            showCursor: CodeEditableText.debugDeterministicCursor
                ? ValueNotifier<bool>(widget.showCursor)
                : _cursorVisibilityNotifier,
            hasFocus: _hasFocus,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            expands: widget.expands,
            strutStyle: widget.strutStyle,
            selectionColor: widget.selectionColor,
            textScaleFactor:
                widget.textScaleFactor ?? MediaQuery.textScaleFactorOf(context),
            textAlign: widget.textAlign,
            textDirection: _textDirection,
            locale: widget.locale,
            autocorrect: widget.autocorrect,
            offset: offset,
            onSelectionChanged: _handleSelectionChanged,
            onCaretChanged: _handleCaretChanged,
            rendererIgnoresPointer: widget.rendererIgnoresPointer,
            cursorWidth: widget.cursorWidth,
            cursorRadius: widget.cursorRadius,
            cursorOffset: widget.cursorOffset,
            paintCursorAboveText: widget.paintCursorAboveText,
            enableInteractiveSelection: widget.enableInteractiveSelection,
            textSelectionDelegate: this,
            devicePixelRatio: _devicePixelRatio,
          ),
        );
      },
    );
  }

  @override
  TextEditingValue get textEditingValue => _toTextEditingValue(_value);

  @override
  set textEditingValue(TextEditingValue value) {
    var ts = TextSpan(text: value.text, style: widget.style);
    _value = _value.copyWith(
        value: ts,
        selection: cs.TextSelection.fromPosition(
            cs.TextPosition(offset: value.text.length)));
  }
}

class _Editable extends LeafRenderObjectWidget {
  const _Editable({
    Key key,
    this.textSpan,
    this.value,
    this.cursorColor,
    this.backgroundCursorColor,
    this.showCursor,
    this.hasFocus,
    this.maxLines,
    this.minLines,
    this.expands,
    this.strutStyle,
    this.selectionColor,
    this.textScaleFactor,
    this.textAlign,
    @required this.textDirection,
    this.locale,
    this.autocorrect,
    this.offset,
    this.onSelectionChanged,
    this.onCaretChanged,
    this.rendererIgnoresPointer = false,
    this.cursorWidth,
    this.cursorRadius,
    this.cursorOffset,
    this.enableInteractiveSelection = true,
    this.textSelectionDelegate,
    this.paintCursorAboveText,
    this.devicePixelRatio,
  })  : assert(textDirection != null),
        assert(rendererIgnoresPointer != null),
        super(key: key);

  final TextSpan textSpan;
  final CodeEditingValue value;
  final Color cursorColor;
  final Color backgroundCursorColor;
  final ValueNotifier<bool> showCursor;
  final bool hasFocus;
  final int maxLines;
  final int minLines;
  final bool expands;
  final StrutStyle strutStyle;
  final Color selectionColor;
  final double textScaleFactor;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final Locale locale;
  final bool autocorrect;
  final ViewportOffset offset;
  final ce.SelectionChangedHandler onSelectionChanged;
  final ce.CaretChangedHandler onCaretChanged;
  final bool rendererIgnoresPointer;
  final double cursorWidth;
  final Radius cursorRadius;
  final Offset cursorOffset;
  final bool enableInteractiveSelection;
  final TextSelectionDelegate textSelectionDelegate;
  final double devicePixelRatio;
  final bool paintCursorAboveText;

  @override
  ce.RenderEditableCode createRenderObject(BuildContext context) {
    return ce.RenderEditableCode(
      text: _styledTextSpan,
      cursorColor: cursorColor,
      backgroundCursorColor: backgroundCursorColor,
      showCursor: showCursor,
      hasFocus: hasFocus,
      maxLines: maxLines,
      minLines: minLines,
      expands: expands,
      strutStyle: strutStyle,
      selectionColor: selectionColor,
      textScaleFactor: textScaleFactor,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale ?? Localizations.localeOf(context, nullOk: true),
      selection: value.selection,
      offset: offset,
      onSelectionChanged: onSelectionChanged,
      onCaretChanged: onCaretChanged,
      ignorePointer: rendererIgnoresPointer,
      cursorWidth: cursorWidth,
      cursorRadius: cursorRadius,
      cursorOffset: cursorOffset,
      paintCursorAboveText: paintCursorAboveText,
      enableInteractiveSelection: enableInteractiveSelection,
      textSelectionDelegate: textSelectionDelegate,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, ce.RenderEditableCode renderObject) {
    renderObject
      ..text = textSpan
      ..cursorColor = cursorColor
      ..showCursor = showCursor
      ..hasFocus = hasFocus
      ..maxLines = maxLines
      ..minLines = minLines
      ..expands = expands
      ..strutStyle = strutStyle
      ..selectionColor = selectionColor
      ..textScaleFactor = textScaleFactor
      ..textAlign = textAlign
      ..textDirection = textDirection
      ..locale = locale ?? Localizations.localeOf(context, nullOk: true)
      ..selection = value.selection
      ..offset = offset
      ..onSelectionChanged = onSelectionChanged
      ..onCaretChanged = onCaretChanged
      ..ignorePointer = rendererIgnoresPointer
      ..cursorWidth = cursorWidth
      ..cursorRadius = cursorRadius
      ..cursorOffset = cursorOffset
      ..textSelectionDelegate = textSelectionDelegate
      ..devicePixelRatio = devicePixelRatio
      ..paintCursorAboveText = paintCursorAboveText;
  }

  TextSpan get _styledTextSpan {
    if (value.composing.isValid) {
      return value.value;
    }

    return value.value;
  }
}

/// Return the length of the text contained in this [TextSpan] tree.
int _getTextSpanLength(TextSpan textSpan) {
  assert(textSpan.debugAssertIsValid());
  int length = 0;
  textSpan.visitChildren((InlineSpan span) {
    length += span.toPlainText().length;
    return true;
  });
  return length;
}
