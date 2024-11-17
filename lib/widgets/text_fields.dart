import 'package:flutter/material.dart';


class QTextField extends StatefulWidget {
  final String label;
  final Function(String) onChanged;
  final TextEditingController controller;
  final maxLines;

  QTextField(this.label, this.controller, this.onChanged, {this.maxLines = 1});
  @override
  _QTextFieldState createState() => _QTextFieldState();
}

class _QTextFieldState extends State<QTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        widget.onChanged(widget.controller.text);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 20),
      child: TextField(
        keyboardType: TextInputType.multiline,
        controller: widget.controller,
        focusNode: _focusNode,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          isDense: true,
          labelText: widget.label,
          floatingLabelStyle: TextStyle(color: Colors.grey, fontSize: 16),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide(color: Colors.black12)
          ),
        ),
        onChanged: widget.onChanged,
      )
    );
  }
}
