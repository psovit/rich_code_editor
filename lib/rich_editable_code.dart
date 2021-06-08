// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui hide TextStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/widgets.dart';

import 'exports.dart';

export 'package:flutter/services.dart'
    show TextEditingValue, TextSelection, TextInputType;
export 'package:flutter/rendering.dart'; //show SelectionChangedCause;

/// Signature for the callback that reports when the user changes the selection
/// (including the cursor location).
typedef SelectionChangedCallback = void Function(
    TextSelection selection, SelectionChangedCause? cause);

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

/// Toolbar configuration for [RichEditableCode].
///
/// Toolbar is a context menu that will show up when user right click or long
/// press the [RichEditableCode]. It includes several options: cut, copy, paste,
/// and select all.
///
/// [RichEditableCode] and its derived widgets have their own default [ToolbarOptions].
/// Create a custom [ToolbarOptions] if you want explicit control over the toolbar
/// option.

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
/// SynEditableCode receives focus. For example, providing iOS's "emergencyCall"
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
class RichEditableCode extends EditableText {
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
  /// The [controller], [focusNode], [obscureText], [autocorrect], [autofocus],
  /// [showSelectionHandles], [enableInteractiveSelection], [forceLine],
  /// [style], [cursorColor], [cursorOpacityAnimates],[backgroundCursorColor],
  /// [enableSuggestions], [paintCursorAboveText], [textAlign], [dragStartBehavior],
  /// [scrollPadding], [dragStartBehavior], [toolbarOptions],
  /// [rendererIgnoresPointer], and [readOnly] arguments must not be null.
  RichEditableCode({
    Key? key,
    required this.controller,
    required this.focusNode,
    this.readOnly = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    required this.style,
    StrutStyle? strutStyle,
    required this.cursorColor,
    required this.backgroundCursorColor,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.locale,
    this.textScaleFactor,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.forceLine = true,
    this.textWidthBasis = TextWidthBasis.parent,
    this.autofocus = false,
    bool? showCursor,
    this.showSelectionHandles = false,
    this.selectionColor,
    this.selectionControls,
    TextInputType? keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onSelectionChanged,
    this.onSelectionHandleTapped,
    List<TextInputFormatter>? inputFormatters,
    this.rendererIgnoresPointer = false,
    this.cursorWidth = 2.0,
    this.cursorRadius,
    this.cursorOpacityAnimates = false,
    this.cursorOffset,
    this.onBackSpacePress,
    this.onEnterPress,
    this.paintCursorAboveText = false,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.keyboardAppearance = Brightness.light,
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection = true,
    this.scrollController,
    this.scrollPhysics,
    this.toolbarOptions = const ToolbarOptions(
      copy: true,
      cut: true,
      paste: true,
      selectAll: true,
    ),
  })  : assert(maxLines == null || maxLines > 0),
        assert(minLines == null || minLines > 0),
        assert(
          (maxLines == null) || (minLines == null) || (maxLines >= minLines),
          'minLines can\'t be greater than maxLines',
        ),
        assert(
          !expands || (maxLines == null && minLines == null),
          'minLines and maxLines must be null when expands is true.',
        ),
        assert(!obscureText || maxLines == 1,
            'Obscured fields cannot be multiline.'),
        _strutStyle = strutStyle,
        keyboardType = keyboardType ??
            (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
        inputFormatters = maxLines == 1
            ? <TextInputFormatter>[
                FilteringTextInputFormatter.singleLineFormatter,
                ...inputFormatters ??
                    const Iterable<TextInputFormatter>.empty(),
              ]
            : inputFormatters,
        showCursor = showCursor ?? !readOnly,
        super(
            key: key,
            controller: controller,
            focusNode: focusNode,
            style: style,
            cursorColor: cursorColor,
            autofocus: autofocus,
            selectionColor: selectionColor,
            backgroundCursorColor: backgroundCursorColor);

  // Trigger when backspace was pressed with value before backspace was pressed
  final ValueChanged<TextEditingValue>? onBackSpacePress;

  // Trigger when enter was pressed with value before enter was pressed
  final ValueChanged<TextEditingValue>? onEnterPress;

  /// Controls the text being edited.
  final RichCodeEditingController controller;

  /// Controls whether this widget has keyboard focus.
  final FocusNode focusNode;

  /// {@template flutter.widgets.SynEditableCode.obscureText}
  /// Whether to hide the text being edited (e.g., for passwords).
  ///
  /// When this is set to true, all the characters in the text field are
  /// replaced by U+2022 BULLET characters (•).
  ///
  /// Defaults to false. Cannot be null.
  /// {@endtemplate}
  final bool obscureText;

  /// {@macro flutter.widgets.text.DefaultTextStyle.textWidthBasis}
  final TextWidthBasis textWidthBasis;

  /// {@template flutter.widgets.SynEditableCode.readOnly}
  /// Whether the text can be changed.
  ///
  /// When this is set to true, the text cannot be modified
  /// by any shortcut or keyboard operation. The text is still selectable.
  ///
  /// Defaults to false. Must not be null.
  /// {@endtemplate}
  final bool readOnly;

  /// Whether the text will take the full width regardless of the text width.
  ///
  /// When this is set to false, the width will be based on text width, which
  /// will also be affected by [textWidthBasis].
  ///
  /// Defaults to true. Must not be null.
  ///
  /// See also:
  ///
  ///  * [textWidthBasis], which controls the calculation of text width.
  final bool forceLine;

  /// Configuration of toolbar options.
  ///
  /// By default, all options are enabled. If [readOnly] is true,
  /// paste and cut will be disabled regardless.
  final ToolbarOptions toolbarOptions;

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

  /// {@template flutter.widgets.SynEditableCode.showCursor}
  /// Whether to show cursor.
  ///
  /// The cursor refers to the blinking caret when the [RichEditableCode] is focused.
  ///
  /// See also:
  ///
  ///  * [showSelectionHandles], which controls the visibility of the selection handles.
  /// {@endtemplate}
  final bool showCursor;

  /// {@template flutter.widgets.SynEditableCode.autocorrect}
  /// Whether to enable autocorrection.
  ///
  /// Defaults to true. Cannot be null.
  /// {@endtemplate}
  final bool autocorrect;

  /// {@macro flutter.services.textInput.enableSuggestions}
  final bool enableSuggestions;

  /// The text style to use for the editable text.
  final TextStyle style;

  /// {@template flutter.widgets.SynEditableCode.strutStyle}
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
  /// Within editable text and text fields, [StrutStyle] will not use its standalone
  /// default values, and will instead inherit omitted/null properties from the
  /// [TextStyle] instead. See [StrutStyle.inheritFromTextStyle].
  StrutStyle get strutStyle {
    if (_strutStyle == null) {
      return StrutStyle.fromTextStyle(style, forceStrutHeight: true);
    }
    return _strutStyle!.inheritFromTextStyle(style);
  }

  final StrutStyle? _strutStyle;

  /// {@template flutter.widgets.SynEditableCode.textAlign}
  /// How the text should be aligned horizontally.
  ///
  /// Defaults to [TextAlign.start] and cannot be null.
  /// {@endtemplate}
  final TextAlign textAlign;

  /// {@template flutter.widgets.SynEditableCode.textDirection}
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
  final TextDirection? textDirection;

  /// {@template flutter.widgets.SynEditableCode.textCapitalization}
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
  final Locale? locale;

  /// The number of font pixels for each logical pixel.
  ///
  /// For example, if the text scale factor is 1.5, text will be 50% larger than
  /// the specified font size.
  ///
  /// Defaults to the [MediaQueryData.textScaleFactor] obtained from the ambient
  /// [MediaQuery], or 1.0 if there is no [MediaQuery] in scope.
  final double? textScaleFactor;

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

  /// {@template flutter.widgets.SynEditableCode.maxLines}
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
  /// `SynEditableCode`.
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
  final int? maxLines;

  /// {@template flutter.widgets.SynEditableCode.minLines}
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
  final int? minLines;

  /// {@template flutter.widgets.SynEditableCode.expands}
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

  /// {@template flutter.widgets.SynEditableCode.autofocus}
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
  final Color? selectionColor;

  /// Optional delegate for building the text selection handles and toolbar.
  ///
  /// The [RichEditableCode] widget used on its own will not trigger the display
  /// of the selection toolbar by itself. The toolbar is shown by calling
  /// [RichEditableCodeState.showToolbar] in response to an appropriate user event.
  ///
  /// See also:
  ///
  ///  * [CupertinoTextField], which wraps an [RichEditableCode] and which shows the
  ///    selection toolbar upon user events that are appropriate on the iOS
  ///    platform.
  ///  * [TextField], a Material Design themed wrapper of [RichEditableCode], which
  ///    shows the selection toolbar upon appropriate user events based on the
  ///    user's platform set in [ThemeData.platform].
  final TextSelectionControls? selectionControls;

  /// {@template flutter.widgets.SynEditableCode.keyboardType}
  /// The type of keyboard to use for editing the text.
  ///
  /// Defaults to [TextInputType.text] if [maxLines] is one and
  /// [TextInputType.multiline] otherwise.
  /// {@endtemplate}
  final TextInputType keyboardType;

  /// The type of action button to use with the soft keyboard.
  final TextInputAction? textInputAction;

  /// {@template flutter.widgets.SynEditableCode.onChanged}
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
  /// [RichCodeEditingController.addListener].
  ///
  /// {@tool dartpad --template=stateful_widget_material}
  ///
  /// This example shows how onChanged could be used to check the TextField's
  /// current value each time the user inserts or deletes a character.
  ///
  /// ```dart
  /// RichCodeEditingController _controller;
  ///
  /// void initState() {
  ///   super.initState();
  ///   _controller = RichCodeEditingController();
  /// }
  ///
  /// void dispose() {
  ///   _controller.dispose();
  ///   super.dispose();
  /// }
  ///
  /// Widget build(BuildContext context) {
  ///   return Scaffold(
  ///     body: Column(
  ///       mainAxisAlignment: MainAxisAlignment.center,
  ///       children: <Widget>[
  ///         const Text('What number comes next in the sequence?'),
  ///         const Text('1, 1, 2, 3, 5, 8...?'),
  ///         TextField(
  ///           controller: _controller,
  ///           onChanged: (String value) async {
  ///             if (value != '13') {
  ///               return;
  ///             }
  ///             await showDialog<void>(
  ///               context: context,
  ///               builder: (BuildContext context) {
  ///                 return AlertDialog(
  ///                   title: const Text('Thats correct!'),
  ///                   content: Text ('13 is the right answer.'),
  ///                   actions: <Widget>[
  ///                     FlatButton(
  ///                       onPressed: () { Navigator.pop(context); },
  ///                       child: const Text('OK'),
  ///                     ),
  ///                   ],
  ///                 );
  ///               },
  ///             );
  ///           },
  ///         ),
  ///       ],
  ///     ),
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [inputFormatters], which are called before [onChanged]
  ///    runs and can validate and change ("format") the input value.
  ///  * [onEditingComplete], [onSubmitted], [onSelectionChanged]:
  ///    which are more specialized input change notifications.
  final ValueChanged<String>? onChanged;

  /// {@template flutter.widgets.SynEditableCode.onEditingComplete}
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
  final VoidCallback? onEditingComplete;

  /// {@template flutter.widgets.SynEditableCode.onSubmitted}
  /// Called when the user indicates that they are done editing the text in the
  /// field.
  /// {@endtemplate}
  ///
  /// {@tool snippet --template=stateful_widget_material}
  /// When a non-completion action is pressed, such as "next" or "previous", it
  /// is often desirable to move the focus to the next or previous field.  To do
  /// this, handle it as in this example, by calling [FocusNode.focusNext] in
  /// the [TextFormField.onFieldSubmitted] callback ([TextFormField] wraps
  /// [RichEditableCode] internally, and uses the value of `onFieldSubmitted` as its
  /// [onSubmitted]).
  ///
  /// ```dart
  /// FocusScopeNode _focusScopeNode = FocusScopeNode();
  /// final _controller1 = RichCodeEditingController();
  /// final _controller2 = RichCodeEditingController();
  ///
  /// void dispose() {
  ///   _focusScopeNode.dispose();
  ///   _controller1.dispose();
  ///   _controller2.dispose();
  ///   super.dispose();
  /// }
  ///
  /// void _handleSubmitted(String value) {
  ///   _focusScopeNode.nextFocus();
  /// }
  ///
  /// Widget build(BuildContext context) {
  ///   return Scaffold(
  ///     body: FocusScope(
  ///       node: _focusScopeNode,
  ///       child: Column(
  ///         mainAxisAlignment: MainAxisAlignment.center,
  ///         children: <Widget>[
  ///           Padding(
  ///             padding: const EdgeInsets.all(8.0),
  ///             child: TextFormField(
  ///               textInputAction: TextInputAction.next,
  ///               onFieldSubmitted: _handleSubmitted,
  ///               controller: _controller1,
  ///               decoration: InputDecoration(border: OutlineInputBorder()),
  ///             ),
  ///           ),
  ///           Padding(
  ///             padding: const EdgeInsets.all(8.0),
  ///             child: TextFormField(
  ///               textInputAction: TextInputAction.next,
  ///               onFieldSubmitted: _handleSubmitted,
  ///               controller: _controller2,
  ///               decoration: InputDecoration(border: OutlineInputBorder()),
  ///             ),
  ///           ),
  ///         ],
  ///       ),
  ///     ),
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  final ValueChanged<String>? onSubmitted;

  /// Called when the user changes the selection of text (including the cursor
  /// location).
  final SelectionChangedCallback? onSelectionChanged;

  /// {@macro flutter.widgets.textSelection.onSelectionHandleTapped}
  final VoidCallback? onSelectionHandleTapped;

  /// {@template flutter.widgets.SynEditableCode.inputFormatters}
  /// Optional input validation and formatting overrides.
  ///
  /// Formatters are run in the provided order when the text input changes.
  /// {@endtemplate}
  final List<TextInputFormatter>? inputFormatters;

  /// If true, the [RenderEditable] created by this widget will not handle
  /// pointer events, see [renderEditable] and [RenderEditable.ignorePointer].
  ///
  /// This property is false by default.
  final bool rendererIgnoresPointer;

  /// {@template flutter.widgets.SynEditableCode.cursorWidth}
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

  /// {@template flutter.widgets.SynEditableCode.cursorRadius}
  /// How rounded the corners of the cursor should be.
  ///
  /// By default, the cursor has no radius.
  /// {@endtemplate}
  final Radius? cursorRadius;

  /// Whether the cursor will animate from fully transparent to fully opaque
  /// during each cursor blink.
  ///
  /// By default, the cursor opacity will animate on iOS platforms and will not
  /// animate on Android platforms.
  final bool cursorOpacityAnimates;

  ///{@macro flutter.rendering.editable.cursorOffset}
  final Offset? cursorOffset;

  ///{@macro flutter.rendering.editable.paintCursorOnTop}
  final bool paintCursorAboveText;

  /// The appearance of the keyboard.
  ///
  /// This setting is only honored on iOS devices.
  ///
  /// Defaults to [Brightness.light].
  final Brightness keyboardAppearance;

  /// {@template flutter.widgets.SynEditableCode.scrollPadding}
  /// Configures padding to edges surrounding a [Scrollable] when the Textfield scrolls into view.
  ///
  /// When this widget receives focus and is not completely visible (for example scrolled partially
  /// off the screen or overlapped by the keyboard)
  /// then it will attempt to make itself visible by scrolling a surrounding [Scrollable], if one is present.
  /// This value controls how far from the edges of a [Scrollable] the TextField will be positioned after the scroll.
  ///
  /// Defaults to EdgeInsets.all(20.0).
  /// {@endtemplate}
  final EdgeInsets scrollPadding;

  /// {@template flutter.widgets.SynEditableCode.enableInteractiveSelection}
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
  /// It does not affect the necessity to focus the SynEditableCode for the cursor
  /// to appear in the first place.
  ///
  /// Defaults to false, resulting in a typical blinking cursor.
  static bool debugDeterministicCursor = false;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// {@template flutter.widgets.SynEditableCode.scrollController}
  /// The [ScrollController] to use when vertically scrolling the input.
  ///
  /// If null, it will instantiate a new ScrollController.
  ///
  /// See [Scrollable.controller].
  /// {@endtemplate}
  final ScrollController? scrollController;

  /// {@template flutter.widgets.SynEditableCode.scrollPhysics}
  /// The [ScrollPhysics] to use when vertically scrolling the input.
  ///
  /// If not specified, it will behave according to the current platform.
  ///
  /// See [Scrollable.physics].
  /// {@endtemplate}
  final ScrollPhysics? scrollPhysics;

  /// {@macro flutter.rendering.editable.selectionEnabled}
  bool get selectionEnabled => enableInteractiveSelection;

  @override
  RichEditableCodeState createState() => RichEditableCodeState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<RichCodeEditingController>(
        'controller', controller));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode));
    properties.add(DiagnosticsProperty<bool>('obscureText', obscureText,
        defaultValue: false));
    properties.add(DiagnosticsProperty<bool>('autocorrect', autocorrect,
        defaultValue: true));
    properties.add(DiagnosticsProperty<bool>(
        'enableSuggestions', enableSuggestions,
        defaultValue: true));
    style.debugFillProperties(properties);
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

/// State for a [RichEditableCode].
class RichEditableCodeState extends EditableTextState {
  Timer? _cursorTimer;
  bool _targetCursorVisibility = false;
  final ValueNotifier<bool> _cursorVisibilityNotifier =
      ValueNotifier<bool>(true);
  final GlobalKey _editableKey = GlobalKey();
  final ClipboardStatusNotifier? _clipboardStatus =
      kIsWeb ? null : ClipboardStatusNotifier();

  TextInputConnection? _textInputConnection;
  TextSelectionOverlay? _selectionOverlay;

  ScrollController? _scrollController;

  late AnimationController _cursorBlinkOpacityController;

  final LayerLink _toolbarLayerLink = LayerLink();
  final LayerLink _startHandleLayerLink = LayerLink();
  final LayerLink _endHandleLayerLink = LayerLink();

  bool _didAutoFocus = false;
  FocusAttachment? _focusAttachment;

  // This value is an eyeball estimation of the time it takes for the iOS cursor
  // to ease in and out.
  static const Duration _fadeDuration = Duration(milliseconds: 250);

  // The time it takes for the floating cursor to snap to the text aligned
  // cursor position after the user has finished placing it.
  static const Duration _floatingCursorResetTime = Duration(milliseconds: 125);

  late AnimationController _floatingCursorResetController;

  @override
  bool get wantKeepAlive => widget.focusNode.hasFocus;

  Color get _cursorColor =>
      widget.cursorColor.withOpacity(_cursorBlinkOpacityController.value);

  @override
  bool get cutEnabled => widget.toolbarOptions.cut && !widget.readOnly;

  @override
  bool get copyEnabled => widget.toolbarOptions.copy;

  @override
  bool get pasteEnabled => widget.toolbarOptions.paste && !widget.readOnly;

  @override
  bool get selectAllEnabled => widget.toolbarOptions.selectAll;

  PressedKey? _pressedKey;

  void _onChangedClipboardStatus() {
    setState(() {
      // Inform the widget that the value of clipboardStatus has changed.
    });
  }

  // State lifecycle:

  @override
  void initState() {
    super.initState();
    _clipboardStatus?.addListener(_onChangedClipboardStatus);
    widget.controller.addListener(_didChangeTextEditingValue);
    _focusAttachment = widget.focusNode.attach(context);
    widget.focusNode.addListener(_handleFocusChanged);
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController!.addListener(() {
      _selectionOverlay?.updateForScroll();
    });
    _cursorBlinkOpacityController =
        AnimationController(vsync: this, duration: _fadeDuration);
    _cursorBlinkOpacityController.addListener(_onCursorColorTick);
    _floatingCursorResetController = AnimationController(vsync: this);
    _floatingCursorResetController.addListener(_onFloatingCursorResetTick);
    _cursorVisibilityNotifier.value = widget.showCursor;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoFocus && widget.autofocus) {
      FocusScope.of(context).autofocus(widget.focusNode);
      _didAutoFocus = true;
    }
  }

  @override
  void didUpdateWidget(RichEditableCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_didChangeTextEditingValue);
      widget.controller.addListener(_didChangeTextEditingValue);
      _updateRemoteEditingValueIfNeeded();
    }
    if (widget.controller.selection != oldWidget.controller.selection) {
      _selectionOverlay?.update(_value);
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
    if (widget.style != oldWidget.style) {
      final TextStyle style = widget.style;
      _textInputConnection?.setStyle(
        fontFamily: style.fontFamily,
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
        textDirection: _textDirection,
        textAlign: widget.textAlign,
      );
    }
    if (widget.selectionEnabled &&
        pasteEnabled &&
        widget.selectionControls?.canPaste(this) == true) {
      _clipboardStatus?.update();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_didChangeTextEditingValue);
    _cursorBlinkOpacityController.removeListener(_onCursorColorTick);
    _floatingCursorResetController.removeListener(_onFloatingCursorResetTick);
    _closeInputConnectionIfNeeded();
    assert(!_hasInputConnection);
    _stopCursorTimer();
    assert(_cursorTimer == null);
    _selectionOverlay?.dispose();
    _selectionOverlay = null;
    _focusAttachment!.detach();
    widget.focusNode.removeListener(_handleFocusChanged);
    _clipboardStatus?.removeListener(_onChangedClipboardStatus);
    _clipboardStatus?.dispose();
    super.dispose();
  }

  // TextInputClient implementation:

  TextEditingValue? _lastKnownRemoteTextEditingValue;

  @override
  void updateEditingValue(TextEditingValue value) {
    // Since we still have to support keyboard select, this is the best place
    // to disable text updating.
    if (widget.readOnly) {
      return;
    }
    if (value.text != _value.text) {
      hideToolbar();
      _showCaretOnScreen();
      if (widget.obscureText && value.text.length == _value.text.length + 1) {
        _obscureShowCharTicksPending = _kObscureShowLatestCharCursorTicks;
        _obscureLatestCharIndex = _value.selection.baseOffset;
      }
    }

    _pressedKey = KeyboardUtilz.getPressedKey(_value, value);

    //if value hasn't changed, do nothing..
    if (value.text == _value.text) return;

    _lastKnownRemoteTextEditingValue = value;
    _formatAndSetValue(value);

    var editableCode = widget as RichEditableCode;

    if (_pressedKey == PressedKey.enter && editableCode.onEnterPress != null) {
      editableCode.onEnterPress!(value);
    }

    if (_pressedKey == PressedKey.backSpace &&
        editableCode.onBackSpacePress != null) {
      editableCode.onBackSpacePress!(value);
    }

    // To keep the cursor from blinking while typing, we want to restart the
    // cursor timer every time a new character is typed.
    _stopCursorTimer(resetCharTicks: false);
    _startCursorTimer();
  }

  @override
  void performAction(TextInputAction action) {
    switch (action) {
      case TextInputAction.newline:
        // If this is a multiline SynEditableCode, do nothing for a "newline"
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
  Rect? _startCaretRect;

  // The most recent text position as determined by the location of the floating
  // cursor.
  TextPosition? _lastTextPosition;

  // The offset of the floating cursor as determined from the first update call.
  Offset? _pointOffsetOrigin;

  // The most recent position of the floating cursor.
  Offset? _lastBoundedOffset;

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
            TextPosition(offset: renderEditable.selection!.baseOffset);
        _startCaretRect =
            renderEditable.getLocalRectForCaret(currentTextPosition);
        renderEditable.setFloatingCursor(
            point.state,
            _startCaretRect!.center - _floatingCursorOffset,
            currentTextPosition);
        break;
      case FloatingCursorDragState.Update:
        // We want to send in points that are centered around a (0,0) origin, so we cache the
        // position on the first update call.
        if (_pointOffsetOrigin != null) {
          final Offset centeredPoint = point.offset! - _pointOffsetOrigin!;
          final Offset rawCursorOffset =
              _startCaretRect!.center + centeredPoint - _floatingCursorOffset;
          _lastBoundedOffset = renderEditable
              .calculateBoundedFloatingCursorOffset(rawCursorOffset);
          _lastTextPosition = renderEditable.getPositionForPoint(renderEditable
              .localToGlobal(_lastBoundedOffset! + _floatingCursorOffset));
          renderEditable.setFloatingCursor(
              point.state, _lastBoundedOffset!, _lastTextPosition!);
        } else {
          _pointOffsetOrigin = point.offset;
        }
        break;
      case FloatingCursorDragState.End:
        // We skip animation if no update has happened.
        if (_lastTextPosition != null && _lastBoundedOffset != null) {
          _floatingCursorResetController.value = 0.0;
          _floatingCursorResetController.animateTo(1.0,
              duration: _floatingCursorResetTime, curve: Curves.decelerate);
        }
        break;
    }
  }

  void _onFloatingCursorResetTick() {
    final Offset finalPosition =
        renderEditable.getLocalRectForCaret(_lastTextPosition!).centerLeft -
            _floatingCursorOffset;
    if (_floatingCursorResetController.isCompleted) {
      renderEditable.setFloatingCursor(
          FloatingCursorDragState.End, finalPosition, _lastTextPosition!);
      if (_lastTextPosition!.offset != renderEditable.selection!.baseOffset)
        // The cause is technically the force cursor, but the cause is listed as tap as the desired functionality is the same.
        _handleSelectionChanged(
            TextSelection.collapsed(offset: _lastTextPosition!.offset),
            renderEditable,
            SelectionChangedCause.forcePress);
      _startCaretRect = null;
      _lastTextPosition = null;
      _pointOffsetOrigin = null;
      _lastBoundedOffset = null;
    } else {
      final double lerpValue = _floatingCursorResetController.value;
      final double lerpX =
          ui.lerpDouble(_lastBoundedOffset!.dx, finalPosition.dx, lerpValue)!;
      final double lerpY =
          ui.lerpDouble(_lastBoundedOffset!.dy, finalPosition.dy, lerpValue)!;

      renderEditable.setFloatingCursor(FloatingCursorDragState.Update,
          Offset(lerpX, lerpY), _lastTextPosition!,
          resetLerpValue: lerpValue);
    }
  }

  void _finalizeEditing(bool shouldUnfocus) {
    // Take any actions necessary now that the user has completed editing.
    if (widget.onEditingComplete != null) {
      widget.onEditingComplete!();
    } else {
      // Default behavior if the developer did not provide an
      // onEditingComplete callback: Finalize editing and remove focus.
      widget.controller.clearComposing();
      if (shouldUnfocus) widget.focusNode.unfocus();
    }

    // Invoke optional callback with the user's submitted content.
    if (widget.onSubmitted != null) widget.onSubmitted!(_value.text);
  }

  void _updateRemoteEditingValueIfNeeded() {
    if (!_hasInputConnection) return;
    final TextEditingValue localValue = _value;
    if (localValue == _lastKnownRemoteTextEditingValue) return;
    _lastKnownRemoteTextEditingValue = localValue;
    _textInputConnection!.setEditingState(localValue);
  }

  TextEditingValue get _value => widget.controller.value;
  set _value(TextEditingValue value) {
    widget.controller.value = value;
  }

  bool get _hasFocus => widget.focusNode.hasFocus;
  bool get _isMultiline => widget.maxLines != 1;

  // Calculate the new scroll offset so the cursor remains visible.
  double _getScrollOffsetForCaret(Rect? caretRect) {
    double caretStart;
    double caretEnd;
    if (_isMultiline) {
      // The caret is vertically centered within the line. Expand the caret's
      // height so that it spans the line because we're going to ensure that the entire
      // expanded caret is scrolled into view.
      final double lineHeight = renderEditable.preferredLineHeight;
      final double caretOffset = (lineHeight - caretRect!.height) / 2;
      caretStart = caretRect.top - caretOffset;
      caretEnd = caretRect.bottom + caretOffset;
    } else {
      // Scrolls horizontally for single-line fields.
      caretStart = caretRect!.left;
      caretEnd = caretRect.right;
    }

    double scrollOffset = _scrollController!.offset;
    final double viewportExtent = _scrollController!.position.viewportDimension;
    if (caretStart < 0.0) {
      // cursor before start of bounds
      scrollOffset += caretStart;
    } else if (caretEnd >= viewportExtent) {
      // cursor after end of bounds
      scrollOffset += caretEnd - viewportExtent;
    }

    if (_isMultiline) {
      // Clamp the final results to prevent programmatically scrolling to
      // out-of-paragraph-bounds positions when encountering tall fonts/scripts that
      // extend past the ascent.
      scrollOffset = scrollOffset.clamp(0.0, renderEditable.maxScrollExtent);
    }
    return scrollOffset;
  }

  // Calculates where the `caretRect` would be if `_scrollController.offset` is set to `scrollOffset`.
  Rect _getCaretRectAtScrollOffset(Rect? caretRect, double scrollOffset) {
    final double offsetDiff = _scrollController!.offset - scrollOffset;
    return _isMultiline
        ? caretRect!.translate(0.0, offsetDiff)
        : caretRect!.translate(offsetDiff, 0.0);
  }

  bool get _hasInputConnection =>
      _textInputConnection != null && _textInputConnection!.attached;

  void _openInputConnection() {
    if (widget.readOnly) {
      return;
    }
    if (!_hasInputConnection) {
      final TextEditingValue localValue = _value;
      _lastKnownRemoteTextEditingValue = localValue;
      _textInputConnection = TextInput.attach(
        this,
        TextInputConfiguration(
          inputType: widget.keyboardType,
          obscureText: widget.obscureText,
          autocorrect: widget.autocorrect,
          enableSuggestions: widget.enableSuggestions,
          inputAction: widget.textInputAction ??
              (widget.keyboardType == TextInputType.multiline
                  ? TextInputAction.newline
                  : TextInputAction.done),
          textCapitalization: widget.textCapitalization,
          keyboardAppearance: widget.keyboardAppearance,
        ),
      );
      _textInputConnection!.show();

      _updateSizeAndTransform();
      final TextStyle style = widget.style;
      assert(_textInputConnection != null);
      _textInputConnection!
        ..setStyle(
          fontFamily: style.fontFamily,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          textDirection: _textDirection,
          textAlign: widget.textAlign,
        )
        ..setEditingState(localValue);
    } else {
      _textInputConnection!.show();
    }
  }

  void _closeInputConnectionIfNeeded() {
    if (_hasInputConnection) {
      _textInputConnection!.close();
      _textInputConnection = null;
      _lastKnownRemoteTextEditingValue = null;
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

  @override
  void connectionClosed() {
    if (_hasInputConnection) {
      _textInputConnection!.connectionClosedReceived();
      _textInputConnection = null;
      _lastKnownRemoteTextEditingValue = null;
      _finalizeEditing(true);
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

  void _updateOrDisposeSelectionOverlayIfNeeded() {
    if (_selectionOverlay != null) {
      if (_hasFocus) {
        _selectionOverlay!.update(_value);
      } else {
        _selectionOverlay!.dispose();
        _selectionOverlay = null;
      }
    }
  }

  void _handleSelectionChanged(TextSelection selection,
      RenderEditable renderObject, SelectionChangedCause? cause) {
    // We return early if the selection is not valid. This can happen when the
    // text of [EditableText] is updated at the same time as the selection is
    // changed by a gesture event.
    if (!widget.controller.isSelectionWithinTextBounds(selection)) return;

    widget.controller.selection = selection;

    // This will show the keyboard for all selection changes on the
    // EditableWidget, not just changes triggered by user gestures.
    requestKeyboard();

    _selectionOverlay?.hide();
    _selectionOverlay = null;

    if (widget.selectionControls != null) {
      _selectionOverlay = TextSelectionOverlay(
        clipboardStatus: _clipboardStatus,
        context: context,
        value: _value,
        debugRequiredFor: widget,
        toolbarLayerLink: _toolbarLayerLink,
        startHandleLayerLink: _startHandleLayerLink,
        endHandleLayerLink: _endHandleLayerLink,
        renderObject: renderObject,
        selectionControls: widget.selectionControls,
        selectionDelegate: this,
        dragStartBehavior: widget.dragStartBehavior,
        onSelectionHandleTapped: widget.onSelectionHandleTapped,
      );
      _selectionOverlay!.handlesVisible = widget.showSelectionHandles;
      _selectionOverlay!.showHandles();
      if (widget.onSelectionChanged != null)
        widget.onSelectionChanged!(selection, cause);
    }
  }

  bool _textChangedSinceLastCaretUpdate = false;
  Rect? _currentCaretRect;

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
    SchedulerBinding.instance!.addPostFrameCallback((Duration _) {
      _showCaretOnScreenScheduled = false;
      if (_currentCaretRect == null || !_scrollController!.hasClients) {
        return;
      }
      final double scrollOffsetForCaret =
          _getScrollOffsetForCaret(_currentCaretRect);
      _scrollController!.animateTo(
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
        final double handleHeight = _selectionOverlay!.selectionControls!
            .getHandleSize(renderEditable.preferredLineHeight)
            .height;
        final double interactiveHandleHeight = math.max(
          handleHeight,
          kMinInteractiveDimension,
        );
        final Offset anchor =
            _selectionOverlay!.selectionControls!.getHandleAnchor(
          TextSelectionHandleType.collapsed,
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
      _editableKey.currentContext!.findRenderObject()!.showOnScreen(
            rect: inflatedRect,
            duration: _caretAnimationDuration,
            curve: _caretAnimationCurve,
          );
    });
  }

  late double _lastBottomViewInset;

  @override
  void didChangeMetrics() {
    if (_lastBottomViewInset <
        WidgetsBinding.instance!.window.viewInsets.bottom) {
      _showCaretOnScreen();
    }
    _lastBottomViewInset = WidgetsBinding.instance!.window.viewInsets.bottom;
  }

  void _formatAndSetValue(TextEditingValue value) {
    final bool textChanged = _value.text != value.text;
    if (textChanged &&
        widget.inputFormatters != null &&
        widget.inputFormatters!.isNotEmpty) {
      for (TextInputFormatter formatter in widget.inputFormatters!)
        value = formatter.formatEditUpdate(_value, value);
      _value = value;
      _updateRemoteEditingValueIfNeeded();
    } else {
      _value = value;
    }
    if (textChanged &&
        widget.onChanged != null &&
        _pressedKey ==
            PressedKey
                .regular) //backspace and enter press are handled separately
      widget.onChanged!(value.text);
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
  TextSelectionOverlay? get selectionOverlay => _selectionOverlay;

  int _obscureShowCharTicksPending = 0;
  int? _obscureLatestCharIndex;

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

    if (_obscureShowCharTicksPending > 0) {
      setState(() {
        _obscureShowCharTicksPending--;
      });
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
    if (RichEditableCode.debugDeterministicCursor) return;
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
    if (RichEditableCode.debugDeterministicCursor) return;
    if (resetCharTicks) _obscureShowCharTicksPending = 0;
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

  void _didChangeTextEditingValue() {
    _updateRemoteEditingValueIfNeeded();
    _startOrStopCursorTimerIfNeeded();
    _updateOrDisposeSelectionOverlayIfNeeded();
    _textChangedSinceLastCaretUpdate = true;
    // TODO(abarth): Teach RenderEditable about ValueNotifier<TextEditingValue>
    // to avoid this setState().
    setState(() {/* We use widget.controller.value in build(). */});
  }

  void _handleFocusChanged() {
    _openOrCloseInputConnectionIfNeeded();
    _startOrStopCursorTimerIfNeeded();
    _updateOrDisposeSelectionOverlayIfNeeded();
    if (_hasFocus) {
      // Listen for changing viewInsets, which indicates keyboard showing up.
      WidgetsBinding.instance!.addObserver(this);
      _lastBottomViewInset = WidgetsBinding.instance!.window.viewInsets.bottom;
      _showCaretOnScreen();
      if (!_value.selection.isValid) {
        // Place cursor at the end if the selection is invalid when we receive focus.
        _handleSelectionChanged(
            TextSelection.collapsed(offset: _value.text.length),
            renderEditable,
            null);
      }
    } else {
      WidgetsBinding.instance!.removeObserver(this);
      // Clear the selection and composition state if this widget lost focus.
      _value = TextEditingValue(text: _value.text);
    }
    updateKeepAlive();
  }

  void _updateSizeAndTransform() {
    if (_hasInputConnection) {
      final Size size = renderEditable.size;
      final Matrix4 transform = renderEditable.getTransformTo(null);
      _textInputConnection!.setEditableSizeAndTransform(size, transform);
      SchedulerBinding.instance!
          .addPostFrameCallback((Duration _) => _updateSizeAndTransform());
    }
  }

  TextDirection get _textDirection {
    final TextDirection result =
        widget.textDirection ?? Directionality.of(context);
    return result;
  }

  /// The renderer for this widget's [Editable] descendant.
  ///
  /// This property is typically used to notify the renderer of input gestures
  /// when [ignorePointer] is true. See [RenderEditable.ignorePointer].
  RenderEditable get renderEditable =>
      _editableKey.currentContext!.findRenderObject() as RenderEditable;

  @override
  TextEditingValue get textEditingValue => _value;

  double get _devicePixelRatio => MediaQuery.of(context).devicePixelRatio;

  @override
  set textEditingValue(TextEditingValue value) {
    _selectionOverlay?.update(value);
    _formatAndSetValue(value);
  }

  @override
  void bringIntoView(TextPosition position) {
    _scrollController!.jumpTo(_getScrollOffsetForCaret(
        renderEditable.getLocalRectForCaret(position)));
  }

  /// Shows the selection toolbar at the location of the current cursor.
  ///
  /// Returns `false` if a toolbar couldn't be shown, such as when the toolbar
  /// is already shown, or when no text selection currently exists.
  bool showToolbar() {
    // Web is using native dom elements to enable clipboard functionality of the
    // toolbar: copy, paste, select, cut. It might also provide additional
    // functionality depending on the browser (such as translate). Due to this
    // we should not show a Flutter toolbar for the editable text elements.
    if (kIsWeb) {
      return false;
    }

    if (_selectionOverlay == null || _selectionOverlay!.toolbarIsVisible) {
      return false;
    }

    _selectionOverlay!.showToolbar();
    return true;
  }

  @override
  void hideToolbar([bool hideHandles = true]) {
    _selectionOverlay?.hide();
  }

  /// Toggles the visibility of the toolbar.
  void toggleToolbar() {
    assert(_selectionOverlay != null);
    if (_selectionOverlay!.toolbarIsVisible) {
      hideToolbar();
    } else {
      showToolbar();
    }
  }

  VoidCallback? _semanticsOnCopy(TextSelectionControls? controls) {
    return widget.selectionEnabled &&
            copyEnabled &&
            _hasFocus &&
            controls?.canCopy(this) == true
        ? () => controls!.handleCopy(this, _clipboardStatus)
        : null;
  }

  VoidCallback? _semanticsOnCut(TextSelectionControls? controls) {
    return widget.selectionEnabled &&
            cutEnabled &&
            _hasFocus &&
            controls?.canCut(this) == true
        ? () => controls!.handleCut(this)
        : null;
  }

  VoidCallback? _semanticsOnPaste(TextSelectionControls? controls) {
    return widget.selectionEnabled &&
            pasteEnabled &&
            _hasFocus &&
            controls?.canPaste(this) == true &&
            (_clipboardStatus == null ||
                _clipboardStatus!.value == ClipboardStatus.pasteable)
        ? () => controls!.handlePaste(this)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    _focusAttachment!.reparent();
    super.build(context); // See AutomaticKeepAliveClientMixin.

    final TextSelectionControls? controls = widget.selectionControls;
    return Scrollable(
      excludeFromSemantics: true,
      axisDirection: _isMultiline ? AxisDirection.down : AxisDirection.right,
      controller: _scrollController,
      physics: widget.scrollPhysics,
      dragStartBehavior: widget.dragStartBehavior,
      viewportBuilder: (BuildContext context, ViewportOffset offset) {
        return CompositedTransformTarget(
          link: _toolbarLayerLink,
          child: Semantics(
            onCopy: _semanticsOnCopy(controls),
            onCut: _semanticsOnCut(controls),
            onPaste: _semanticsOnPaste(controls),
            child: _Editable(
              key: _editableKey,
              startHandleLayerLink: _startHandleLayerLink,
              endHandleLayerLink: _endHandleLayerLink,
              textSpan: buildTextSpan(),
              value: _value,
              cursorColor: _cursorColor,
              backgroundCursorColor: widget.backgroundCursorColor,
              showCursor: RichEditableCode.debugDeterministicCursor
                  ? ValueNotifier<bool>(widget.showCursor)
                  : _cursorVisibilityNotifier,
              forceLine: widget.forceLine,
              readOnly: widget.readOnly,
              hasFocus: _hasFocus,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              expands: widget.expands,
              strutStyle: widget.strutStyle,
              selectionColor: widget.selectionColor,
              textScaleFactor: widget.textScaleFactor ??
                  MediaQuery.textScaleFactorOf(context),
              textAlign: widget.textAlign,
              textDirection: _textDirection,
              locale: widget.locale,
              textWidthBasis: widget.textWidthBasis,
              obscureText: widget.obscureText,
              autocorrect: widget.autocorrect,
              enableSuggestions: widget.enableSuggestions,
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
          ),
        );
      },
    );
  }

  /// Builds [TextSpan] from current editing value.
  ///
  /// By default makes text in composing range appear as underlined.
  /// Descendants can override this method to customize appearance of text.
  TextSpan buildTextSpan() {
    if (widget.obscureText) {
      String text = _value.text;
      text = widget.obscuringCharacter * text.length;
      final int? o =
          _obscureShowCharTicksPending > 0 ? _obscureLatestCharIndex : null;
      if (o != null && o >= 0 && o < text.length)
        text = text.replaceRange(o, o + 1, _value.text.substring(o, o + 1));
      return TextSpan(style: widget.style, text: text);
    }
    // Read only mode should not paint text composing.
    return widget.controller.buildTextSpan(
      context: context,
      style: widget.style,
      withComposing: !widget.readOnly,
    );
  }
}

class _Editable extends LeafRenderObjectWidget {
  const _Editable({
    Key? key,
    this.textSpan,
    this.value,
    this.startHandleLayerLink,
    this.endHandleLayerLink,
    this.cursorColor,
    this.backgroundCursorColor,
    this.showCursor,
    this.forceLine,
    this.readOnly,
    this.textWidthBasis,
    this.hasFocus,
    this.maxLines,
    this.minLines,
    this.expands,
    this.strutStyle,
    this.selectionColor,
    this.textScaleFactor,
    this.textAlign,
    required this.textDirection,
    this.locale,
    this.obscureText,
    this.autocorrect,
    this.enableSuggestions,
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
  }) : super(key: key);

  final TextSpan? textSpan;
  final TextEditingValue? value;
  final Color? cursorColor;
  final LayerLink? startHandleLayerLink;
  final LayerLink? endHandleLayerLink;
  final Color? backgroundCursorColor;
  final ValueNotifier<bool>? showCursor;
  final bool? forceLine;
  final bool? readOnly;
  final bool? hasFocus;
  final int? maxLines;
  final int? minLines;
  final bool? expands;
  final StrutStyle? strutStyle;
  final Color? selectionColor;
  final double? textScaleFactor;
  final TextAlign? textAlign;
  final TextDirection textDirection;
  final Locale? locale;
  final bool? obscureText;
  final TextWidthBasis? textWidthBasis;
  final bool? autocorrect;
  final bool? enableSuggestions;
  final ViewportOffset? offset;
  final SelectionChangedHandler? onSelectionChanged;
  final CaretChangedHandler? onCaretChanged;
  final bool rendererIgnoresPointer;
  final double? cursorWidth;
  final Radius? cursorRadius;
  final Offset? cursorOffset;
  final bool enableInteractiveSelection;
  final TextSelectionDelegate? textSelectionDelegate;
  final double? devicePixelRatio;
  final bool? paintCursorAboveText;

  @override
  RenderEditable createRenderObject(BuildContext context) {
    return RenderEditable(
      text: textSpan,
      cursorColor: cursorColor,
      startHandleLayerLink: startHandleLayerLink!,
      endHandleLayerLink: endHandleLayerLink!,
      backgroundCursorColor: backgroundCursorColor,
      showCursor: showCursor,
      forceLine: forceLine!,
      readOnly: readOnly!,
      hasFocus: hasFocus,
      maxLines: maxLines,
      minLines: minLines,
      expands: expands!,
      strutStyle: strutStyle,
      selectionColor: selectionColor,
      textScaleFactor: textScaleFactor!,
      textAlign: textAlign!,
      textDirection: textDirection,
      locale: locale ?? Localizations.maybeLocaleOf(context),
      selection: value!.selection,
      offset: offset!,
      onSelectionChanged: onSelectionChanged,
      onCaretChanged: onCaretChanged,
      ignorePointer: rendererIgnoresPointer,
      obscureText: obscureText!,
      textWidthBasis: textWidthBasis!,
      cursorWidth: cursorWidth!,
      cursorRadius: cursorRadius,
      cursorOffset: cursorOffset!,
      paintCursorAboveText: paintCursorAboveText!,
      enableInteractiveSelection: enableInteractiveSelection,
      textSelectionDelegate: textSelectionDelegate!,
      devicePixelRatio: devicePixelRatio!,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderEditable renderObject) {
    renderObject
      ..text = textSpan
      ..cursorColor = cursorColor
      ..startHandleLayerLink = startHandleLayerLink!
      ..endHandleLayerLink = endHandleLayerLink!
      ..showCursor = showCursor!
      ..forceLine = forceLine!
      ..readOnly = readOnly!
      ..hasFocus = hasFocus!
      ..maxLines = maxLines
      ..minLines = minLines
      ..expands = expands!
      ..strutStyle = strutStyle
      ..selectionColor = selectionColor
      ..textScaleFactor = textScaleFactor!
      ..textAlign = textAlign!
      ..textDirection = textDirection
      ..locale = locale ?? Localizations.maybeLocaleOf(context)
      ..selection = value!.selection
      ..offset = offset!
      ..onSelectionChanged = onSelectionChanged
      ..onCaretChanged = onCaretChanged
      ..ignorePointer = rendererIgnoresPointer
      ..textWidthBasis = textWidthBasis!
      ..obscureText = obscureText!
      ..cursorWidth = cursorWidth!
      ..cursorRadius = cursorRadius
      ..cursorOffset = cursorOffset!
      ..textSelectionDelegate = textSelectionDelegate!
      ..devicePixelRatio = devicePixelRatio!
      ..paintCursorAboveText = paintCursorAboveText!;
  }
}

class KeyboardUtilz {
  /// Check and see if last pressed key was enter key.
  /// This is checked by looking if the last character text == "\n".
  static PressedKey getPressedKey(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.length == 1 && newValue.text == "\n") {
      return PressedKey.enter;
    }

    final TextSelection newSelection = newValue.selection;
    final TextSelection currentSelection = oldValue.selection;

    if (currentSelection.baseOffset > newSelection.baseOffset) {
      //backspace was pressed
      return PressedKey.backSpace;
    }

    var lastChar = newValue.text
        .substring(currentSelection.baseOffset, newSelection.baseOffset);
    return lastChar == "\n" ? PressedKey.enter : PressedKey.regular;
  }
}

enum PressedKey { enter, backSpace, regular }
