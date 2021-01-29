# rich_code_editor

A simple package that supports creating code editors in Flutter.

Flutter version supported: Flutter 1.22.5

![](https://github.com/psovit/rich_code_editor/blob/master/demo.gif)

# Getting Started

There are two main components of the rich code editor:

1) Editor
2) Syntax Highlighter

The editor is a text area which is identical to Flutter's `TextField` widget. However, unlike a regular `TextField` the editor uses an instance of syntax highlighter object to parse and highlight code syntax.

Since the editor itself is independent of the syntax highlighting rules, the same editor can be used for any other programming langugages. Only the syntax highlighter implementation needs to be created separately for each new programming language.

The example demo uses a dummy syntax highlighter implementation `DummySyntaxHighlighter`.

Get Started by creating your own implementation for `SyntaxHighlighterBase` class.

The syntax highlight logic part is not much implemented in this package as that will change as per the choice of programming language.
