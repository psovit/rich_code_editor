import 'package:flutter/material.dart';
import 'package:rich_code_editor/editor/widget/rich_editable_text.dart';
import 'package:rich_code_editor/rich_code_editor.dart';

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
          child: FlatButton(
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
  GlobalKey<RichTextFieldState> _richTextFieldState =
      new GlobalKey<RichTextFieldState>();

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Dummy Editor"),
      ),
      body: new Container(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new Expanded(
              child: new Container(
                padding: new EdgeInsets.all(16.0),
                child: new Container(
                  padding: EdgeInsets.all(24.0),
                  decoration: new BoxDecoration(
                      border: new Border.all(
                          color: Theme.of(context).primaryColor)),
                  child: new RichTextField(
                    richTextEditingValueParser: DummyParser(),//replace this with your parser implementation
                    key: _richTextFieldState,
                    onChangedSpan: (span) {},
                    onChanged: (text) {},
                    maxLines: null,
                    decoration: null,
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.black
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
