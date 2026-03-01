import 'package:flutter/material.dart';

import 'model.dart';
import 'utils.dart';

class AbstractNoteItem extends StatelessWidget {
  final Note note;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String? highlight;

  const AbstractNoteItem({
    required this.note,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.highlight,
    super.key,
  });

  bool get empty => (note.title.trim().isEmpty && sectionText().trim().isEmpty);

  String sectionText() => note.sections.map((s) => s.content).join('\n');

  Widget singleText(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(fontWeight: FontWeight.w200),
      ),
    );
  }

  Widget highlightTitle(BuildContext context, String title, String? highlight) {
    if (highlight == null || highlight.isEmpty) {
      return Text(title, style: Theme.of(context).textTheme.titleLarge);
    }
    final lowerTitle = title.toLowerCase();
    final lowerHighlight = highlight.toLowerCase();
    final start = lowerTitle.indexOf(lowerHighlight);
    if (start == -1) {
      return Text(title, style: Theme.of(context).textTheme.titleLarge);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: title.substring(0, start)),
          TextSpan(
            text: title.substring(start, start + highlight.length),
            style: TextStyle(backgroundColor: Theme.of(context).highlightColor),
          ),
          TextSpan(text: title.substring(start + highlight.length)),
        ],
      ),
      style: Theme.of(context).textTheme.titleLarge,
      textAlign: TextAlign.left,
    );
  }

  Widget highlightSectionText(
    BuildContext context,
    String text,
    String? highlight, {
    int maxLines = 9,
  }) {
    if (highlight == null || highlight.isEmpty) {
      return Text(
        text,
        softWrap: true,
        overflow: TextOverflow.clip,
        maxLines: maxLines,
        textAlign: TextAlign.left,
      );
    }
    final start = text.toLowerCase().indexOf(highlight.toLowerCase());
    if (start == -1) {
      return Text(
        text,
        softWrap: true,
        overflow: TextOverflow.clip,
        maxLines: maxLines,
        textAlign: TextAlign.left,
      );
    }
    final end = start + highlight.length;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: TextStyle(backgroundColor: Theme.of(context).highlightColor),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
      softWrap: true,
      overflow: TextOverflow.clip,
      maxLines: maxLines,
      textAlign: TextAlign.left,
    );
  }

  Widget emptyText(BuildContext context) => singleText(context, 'Empty');
  Widget onlyTitle(BuildContext context) => singleText(context, note.title);
  bool get hasOnlyTitle => note.title.isNotEmpty && sectionText().trim().isEmpty;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SmallNoteItem extends AbstractNoteItem {
  final double width;
  final EdgeInsets padding;

  SmallNoteItem(
    Note note,
    bool isSelected,
    VoidCallback onTap,
    VoidCallback onLongPress,
    String? highlight,
    this.width,
    this.padding, {
    super.key,
  }) : super(
          note: note,
          isSelected: isSelected,
          onTap: onTap,
          onLongPress: onLongPress,
          highlight: highlight,
        );

  @override
  Widget build(BuildContext context) {
    final child = Card(
      color: note.color,
      child: Container(
        decoration: isSelected ? getSelectedDecoration(context) : null,
        child: empty
            ? emptyText(context)
            : hasOnlyTitle
                ? onlyTitle(context)
                : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: highlightTitle(context, note.title, highlight),
                        ),
                        highlightSectionText(context, sectionText(), highlight),
                      ],
                    ),
                  ),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: width,
        height: empty ? 50 : null,
        padding: padding,
        child: child,
      ),
    );
  }
}

class NoteItem extends AbstractNoteItem {
  final double padding;

  NoteItem(
    Note note,
    bool isSelected,
    VoidCallback onTap,
    VoidCallback onLongPress,
    String? highlight, {
    this.padding = 8,
    super.key,
  }) : super(
          note: note,
          isSelected: isSelected,
          onTap: onTap,
          onLongPress: onLongPress,
          highlight: highlight,
        );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        color: note.color,
        child: Container(
          decoration: isSelected ? getSelectedDecoration(context) : null,
          child: empty
              ? emptyText(context)
              : hasOnlyTitle
                  ? onlyTitle(context)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.all(padding),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(note.key ?? 'No Key'),
                              Text(note.capo == null ? 'No Capo' : 'Capo ${note.capo}'),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(padding),
                          child: highlightTitle(context, note.title, highlight),
                        ),
                        Padding(
                          padding: EdgeInsets.all(padding),
                          child: highlightSectionText(
                            context,
                            sectionText(),
                            highlight,
                            maxLines: 6,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(padding),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text('${note.sections.length} Sections'),
                              Text(note.tuning ?? 'Standard'),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
