import 'package:flutter/material.dart';

class SearchTextView extends StatelessWidget {
  final Function toggleIsSearching;
  final ValueChanged<String> onChanged;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String text;

  SearchTextView(
      {this.toggleIsSearching,
      this.onChanged,
      this.controller,
      Key key,
      this.focusNode,
      this.text = "Search...",
      this.enabled = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: toggleIsSearching,
        child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            style: Theme.of(context).appBarTheme.textTheme.subtitle1,
            onTap: () => toggleIsSearching(searching: true),
            onSubmitted: (s) => toggleIsSearching(searching: false),
            enabled: enabled,
            decoration: InputDecoration(
                border: InputBorder.none,
                hintText: text,
                hintStyle: Theme.of(context).appBarTheme.textTheme.subtitle1),
            maxLines: 1,
            minLines: 1,
            onChanged: (String s) => onChanged(s)));
  }
}
