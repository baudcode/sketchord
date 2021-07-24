import 'package:flutter/material.dart';

class Gallery extends StatelessWidget {
  final int numItemsPerRow;
  final List<Widget> items;
  final double padding;
  final double widthHeightRatio;

  int get maxRows => (items.length / numItemsPerRow).ceil();

  Gallery(
      {@required this.numItemsPerRow,
      @required this.items,
      this.padding = 8.0,
      this.widthHeightRatio = 1.0});

  EdgeInsetsGeometry _getPadding(int row, int col) {
    double top = (row == 0) ? padding : padding / 2;
    double bottom = (row == maxRows - 1) ? padding : padding / 2;
    double left = (col == 0) ? padding : padding / 2;
    double right = (col == numItemsPerRow - 1) ? padding : padding / 2;
    return new EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  Widget _getItem(int row, int col, double width) {
    int index = row * numItemsPerRow + col;
    // maximum item width
    double _itemWidth = width / numItemsPerRow;
    double _itemHeight = _itemWidth * widthHeightRatio;

    EdgeInsetsGeometry _padding = _getPadding(row, col);
    if (index >= items.length)
      return new Container(
          width: _itemWidth, height: _itemHeight, padding: _padding);
    else
      return new Container(
        width: _itemWidth,
        height: _itemHeight,
        padding: _padding,
        child: items[index],
      );
  }

  @override
  Widget build(BuildContext context) {
    int rows = (items.length / numItemsPerRow).ceil();
    double width = MediaQuery.of(context).size.width;
    return ListView.builder(
      itemCount: rows,
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return new Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //crossAxisAlignment: CrossAxisAlignment.center,
            //mainAxisSize: MainAxisSize.min,
            children: List.generate(
                numItemsPerRow, (col) => _getItem(index, col, width)));
      },
    );
  }
}
