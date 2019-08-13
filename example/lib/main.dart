import 'package:flutter/material.dart';
import 'package:rich_code_editor/rich_code_editor.dart';
import 'package:rich_code_editor/code_editor/widgets/code_text_field.dart';

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
  // GlobalKey<RichTextFieldState> _richTextFieldState =
  //     new GlobalKey<RichTextFieldState>();

  @override
  void dispose() {
    //_richTextFieldState.currentState?.dispose();
    super.dispose();
  }

  var tbKey = 1;

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
                    child: PageView(
                      onPageChanged: (i) {
                        if(i == 1) {
                          setState(() {
                            tbKey ++;
                          });
                        }
                      },
                      children: <Widget>[
                        new CodeTextField(
                          highlighter: DummyHighlighter(), 
                          onChanged: (t) {
                            print("text: ");
                            print(t);
                          },
                          controller: CodeEditingController(),
                          maxLines: null,
                          decoration: null,
                          autofocus: true,
                          style: TextStyle(fontSize: 16.0, color: Colors.black),
                        ),
                      ],
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
