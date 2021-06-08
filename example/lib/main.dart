import 'package:flutter/material.dart';
import 'package:rich_code_editor/exports.dart';

import 'DummySyntaxHighlighter.dart';

void main() {
  runApp(MaterialApp(
    home: Home(),
  ));
}

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Center(
          child: TextButton(
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => DemoCodeEditor()));
            },
            child: Text("My Code Editor"),
          ),
        ),
      ),
    );
  }
}

class DemoCodeEditor extends StatefulWidget {
  @override
  _DemoCodeEditorState createState() => _DemoCodeEditorState();
}

class _DemoCodeEditorState extends State<DemoCodeEditor> {
  RichCodeEditingController? _rec;
  SyntaxHighlighterBase? _syntaxHighlighterBase;

  @override
  void initState() {
    super.initState();
    _syntaxHighlighterBase = DummySyntaxHighlighter();
    _rec = RichCodeEditingController(_syntaxHighlighterBase, text: '');
  }

  @override
  void dispose() {
    //_richTextFieldState.currentState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Dummy Editor"),
      ),
      body: Container(
          height: 300.0,
          margin: EdgeInsets.all(24.0),
          padding: EdgeInsets.all(24.0),
          decoration:
              new BoxDecoration(border: new Border.all(color: Colors.grey)),
          child: RichCodeField(
            autofocus: true,
            controller: _rec,
            textCapitalization: TextCapitalization.none,
            decoration: null,
            syntaxHighlighter: _syntaxHighlighterBase,
            maxLines: null,
            onChanged: (String s) {},
            onBackSpacePress: (TextEditingValue oldValue) {},
            onEnterPress: (TextEditingValue oldValue) {
              var result = _syntaxHighlighterBase!.onEnterPress(oldValue);
              if (result != null) {
                _rec!.value = result;
              }
            },
          )),
    );
  }
}
