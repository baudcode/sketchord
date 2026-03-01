import 'package:flutter/material.dart';

class SearchTextView extends StatelessWidget {
  final Function({bool searching}) toggleIsSearching;
  final ValueChanged<String> onChanged;
  final TextEditingController controller;

  const SearchTextView(
      {required this.toggleIsSearching,
      required this.onChanged,
      required this.controller,
      super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
        controller: controller,
        autofocus: false,
        style: Theme.of(context).textTheme.titleMedium,
        onTap: () => toggleIsSearching(searching: true),
        onSubmitted: (s) => toggleIsSearching(searching: false),
        decoration: InputDecoration(
            border: InputBorder.none,
            hintText: "Search...",
            hintStyle: Theme.of(context).textTheme.titleMedium),
        maxLines: 1,
        minLines: 1,
        onChanged: (String s) => onChanged(s));
  }
}
