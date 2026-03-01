import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tuple/tuple.dart';

import '../editor_store.dart';
import '../model.dart';
import '../utils.dart';

class Editable extends StatefulWidget {
  final String initialValue;
  final TextStyle? textStyle;
  final ValueChanged<String> onChange;
  final String? hintText;
  final int? maxLines;
  final bool multiline;
  final String? labelText;

  const Editable({
    super.key,
    required this.initialValue,
    this.textStyle,
    required this.onChange,
    this.hintText,
    this.maxLines,
    this.multiline = false,
    this.labelText,
  });

  @override
  State<StatefulWidget> createState() => EditableState();
}

class EditableState extends State<Editable> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration.collapsed(hintText: widget.hintText)
          .copyWith(labelText: widget.labelText),
      keyboardType: widget.multiline ? TextInputType.multiline : TextInputType.text,
      expands: false,
      minLines: 1,
      maxLines: widget.maxLines,
      enableInteractiveSelection: true,
      onChanged: widget.onChange,
      controller: _controller,
      textInputAction:
          widget.multiline ? TextInputAction.newline : TextInputAction.done,
      style: widget.textStyle,
    );
  }
}

class AddSectionItem extends StatelessWidget {
  const AddSectionItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).cardColor, width: 2),
        ),
        child: TextButton(
          child: Text('Add Section', style: Theme.of(context).textTheme.bodySmall),
          onPressed: () => addSection(Section(title: '', content: '')),
        ),
      ),
    );
  }
}

class SectionListItem extends StatelessWidget {
  final Section section;
  final bool moveDown;
  final bool moveUp;
  final GlobalKey globalKey;

  const SectionListItem({
    required this.section,
    required this.moveUp,
    required this.moveDown,
    required this.globalKey,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final trailingWidgets = <Widget>[];
    if (moveDown) {
      trailingWidgets.add(
        IconButton(
          icon: const Icon(Icons.arrow_drop_down),
          onPressed: () => moveSectionDown(section),
        ),
      );
    }
    if (moveUp) {
      trailingWidgets.add(
        IconButton(
          icon: const Icon(Icons.arrow_drop_up),
          onPressed: () => moveSectionUp(section),
        ),
      );
    }

    final card = Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Editable(
                      initialValue: section.title,
                      textStyle: Theme.of(context).textTheme.titleMedium,
                      onChange: (s) => changeSectionTitle(Tuple2(section, s)),
                      hintText: 'Title',
                      maxLines: 4,
                    ),
                  ),
                  Editable(
                    initialValue: section.content,
                    textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                        ),
                    onChange: (s) => changeContent(Tuple2(section, s)),
                    hintText: 'Content',
                    multiline: true,
                    maxLines: null,
                  ),
                ],
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: trailingWidgets,
          ),
        ],
      ),
    );

    return Dismissible(
      key: globalKey,
      direction: DismissDirection.startToEnd,
      background: Card(
        child: Container(
          color: Colors.redAccent,
          padding: const EdgeInsets.all(10),
          child: const Row(children: <Widget>[Icon(Icons.delete)]),
        ),
      ),
      onDismissed: (_) {
        deleteSection(section);
        showUndoSnackbar(
          context,
          section.hasEmptyTitle ? 'Section' : section.title,
          section,
          (_) => undoDeleteSection(),
        );
      },
      child: card,
    );
  }
}

class SectionView extends StatelessWidget {
  final Section section;
  final double textScaleFactor;
  final bool richChords;

  const SectionView({
    super.key,
    required this.section,
    required this.textScaleFactor,
    this.richChords = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                section.title,
                style: GoogleFonts.robotoMono(
                  textStyle: Theme.of(context).textTheme.titleMedium,
                  fontSize: 14,
                  fontFeatures: const [FontFeature.enable('smcp')],
                ),
                textScaler: TextScaler.linear(textScaleFactor),
                maxLines: 1,
              ),
            ),
            Text(
              richChords ? resolveRichContent(section.content) : section.content,
              style: GoogleFonts.robotoMono(
                textStyle: Theme.of(context).textTheme.bodyMedium,
                fontSize: 10,
                letterSpacing: 0,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.normal,
              ),
              textScaler: TextScaler.linear(textScaleFactor),
            ),
          ],
        ),
      ),
    );
  }
}
