import 'package:flutter/material.dart';

class SearchTextView extends StatelessWidget {
  final Function toggleIsSearching;
  final ValueChanged<String> onChanged;
  final TextEditingController controller;

  SearchTextView(
      {this.toggleIsSearching, this.onChanged, this.controller, Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
        controller: controller,
        autofocus: false,
        style: Theme.of(context).appBarTheme.textTheme.subtitle1,
        onTap: () => toggleIsSearching(searching: true),
        onSubmitted: (s) => toggleIsSearching(searching: false),
        decoration: InputDecoration(
            border: InputBorder.none,
            hintText: "Search...",
            hintStyle: Theme.of(context).appBarTheme.textTheme.subtitle1),
        maxLines: 1,
        minLines: 1,
        onChanged: (String s) => onChanged(s));
  }
}
