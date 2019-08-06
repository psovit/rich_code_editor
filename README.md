# rich_code_editor

A simple package that supports creating code editors in Flutter.

![](https://github.com/psovit/rich_code_editor/blob/master/demo.gif)


## Getting Started

Create your own implementation of `RichTextEditingValueParserBase` for any programming language of your choice and pass it to the `RichTextField`.

Check out example project for getting started with this project.

## Explanation of most of the classes/widgets created

1. RichTextField
	- similar to TextField widget
	- top level widget that wraps everything inside	
2. RichTextFieldState
	- extends State<RichTextField>
3. RenderRichEditable
	- extends RenderBox
	- renderer for an editable text field
	- It does not directly provide affordances for editing the text, 
	- but it does handle text selection and manipulation of the text cursor.
4. RichTextEditingValueParser
	- responsible for parsing text and style
5. RichTextEditingValue
	- similar to TextEditingValue
	- uses TextSpan instead of String
11. RichTextEditingController
	- extends ValueNotifier of type <RichTextEditingValue>
	- similar to TextEditingController but for <RichTextEditingValue>
12. RichEditableText
	- similar to EditableText
13. RichEditableTextState
	- extends State<RichEditableText>
	- implements TextInputClient<RichTextEditingValue>
    - parent for `_RichEditable`
14. _RichEditable
	- extends LeafRenderObjectWidget
    - The createRenderObject & updateRenderObject methods update output TextSpans by calling `RichTextEditingValueParser.updateSpansWithStyle`  
15. Extensions
    - utilities for working with TextSpan


# Credits
A big thanks to Razvan Lung for starting the Rich text editor project "https://github.com/long1eu/rich_editor". Most of the codes have been used from his repo and adjusted as needed.