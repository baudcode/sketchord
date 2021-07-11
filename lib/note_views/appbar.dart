import 'package:flutter/material.dart';
import 'package:sound/db.dart';
import 'package:sound/model.dart';
import 'package:sound/storage.dart';

typedef FilterByCallback = bool Function(FilterBy);
typedef FilterCallback = bool Function(Filter);

class CustomChip extends StatelessWidget {
  final bool active;
  final Widget label;
  final Function onPressed;

  CustomChip({this.active = false, this.label, this.onPressed, Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = (active)
        ? Theme.of(context).chipTheme.selectedColor
        : Theme.of(context).chipTheme.backgroundColor;

    TextStyle style = (active)
        ? Theme.of(context).chipTheme.secondaryLabelStyle
        : Theme.of(context).chipTheme.labelStyle;

    return ActionChip(
        backgroundColor: backgroundColor,
        labelStyle: style,
        label: label,
        clipBehavior: Clip.hardEdge,
        onPressed: onPressed);
  }
}

class FilterView extends StatelessWidget {
  final bool active;
  final Filter filter;
  final ValueChanged<Filter> remove, add;

  FilterView({this.filter, this.active, this.remove, this.add});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: CustomChip(
            active: active,
            label: Text(filter.content),
            onPressed: () => (active) ? remove(filter) : add(filter)));
  }
}

class FilterOptionsView extends StatelessWidget {
  final String title;
  final List<String> data;
  final FilterBy by;

  final bool showMore;
  final bool mustShowMore;
  final FilterCallback isFilterApplied;

  FilterOptionsView(
      {this.title,
      this.data,
      this.by,
      this.showMore,
      this.mustShowMore,
      this.isFilterApplied,
      Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<String> partialData = !showMore ? data.take(3).toList() : data;

    return Container(
        padding: EdgeInsets.only(bottom: 10),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title.toUpperCase(),
                      style: Theme.of(context).appBarTheme.textTheme.caption),
                  (mustShowMore)
                      ? GestureDetector(
                          onTap: () => toggleShowMore(by),
                          child: Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: Text(
                                  (showMore) ? 'Show Less' : 'Show More',
                                  style: Theme.of(context)
                                      .textTheme
                                      .caption
                                      .copyWith(
                                          color:
                                              Theme.of(context).accentColor))))
                      : Container(height: 0, width: 0),
                ],
              ),
              Container(
                  height: 50,
                  child: ListView.builder(
                    itemCount: partialData.length,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      Filter filter = Filter(by: by, content: data[index]);
                      return FilterView(
                          filter: filter,
                          active: isFilterApplied(filter),
                          remove: removeFilter,
                          add: addFilter);
                    },
                  ))
            ]));
  }
}

class ActiveFiltersView extends StatelessWidget {
  final List<Filter> filters;
  final ValueChanged<Filter> removeFilter;

  ActiveFiltersView({this.filters, this.removeFilter, Key key})
      : super(key: key);

  _getItem() {
    return Container(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
          Container(
              height: 50,
              child: ListView.builder(
                itemCount: this.filters.length,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  Filter filter = filters[index];

                  return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: CustomChip(
                          active: true,
                          label: Text(
                            filter.content,
                          ),
                          onPressed: () => removeFilter(filter)));
                },
              )),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.only(left: 10, top: 50),
        child: ListView.builder(
          itemBuilder: (context, i) => _getItem(),
          itemCount: 1,
        ));
  }
}

class SortingView extends StatelessWidget {
  final ValueChanged<SortDirection> onDirectionChange;
  final ValueChanged<SortBy> onSortByChange;
  final SortDirection direction;
  final SortBy by;

  const SortingView({
    @required this.by,
    @required this.direction,
    @required this.onDirectionChange,
    @required this.onSortByChange,
    Key key,
  }) : super(key: key);

  _onDirectionChange() {
    if (direction == SortDirection.down)
      onDirectionChange(SortDirection.up);
    else
      onDirectionChange(SortDirection.down);
  }

  byText() {
    switch (by) {
      case SortBy.created:
        return "Created";
      case SortBy.lastModified:
        return "Last Modified";
      case SortBy.az:
        return "AZ";
      default:
        return "null";
    }
  }

  _onSortByChange() {
    switch (by) {
      case SortBy.created:
        onSortByChange(SortBy.lastModified);
        break;

      case SortBy.lastModified:
        onSortByChange(SortBy.az);
        break;

      case SortBy.az:
        onSortByChange(SortBy.created);
        break;
      default:
        onSortByChange(SortBy.lastModified);
        break;
    }
  }

  arrowOption(BuildContext context) {
    // arrow icon not vanishing under the app bar
    Icon icon = Icon(
      direction == SortDirection.up ? Icons.arrow_upward : Icons.arrow_downward,
      size: 10,
      color: Theme.of(context).appBarTheme.textTheme.button.color,
    );
    return TextButton(
        onPressed: _onDirectionChange,
        child: Text(
          (direction == SortDirection.up) ? "Up" : "Down",
          style: Theme.of(context).appBarTheme.textTheme.button,
          textScaleFactor: 0.9,
        ),
        clipBehavior: Clip.hardEdge);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.only(top: 70),
        child: Container(
          color: Theme.of(context).appBarTheme.backgroundColor,
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: TextButton(
                      onPressed: _onSortByChange,
                      child: Text(byText(),
                          textScaleFactor: 0.9,
                          style:
                              Theme.of(context).appBarTheme.textTheme.button)),
                ),
                Expanded(
                  child: arrowOption(context),
                ),
              ]),
        ));
  }
}

// class SearchAppBar extends StatefulWidget {
//   SearchAppBar({Key key}) : super(key: key);

//   @override
//   _SearchAppBarState createState() => _SearchAppBarState();
// }

// class _SearchAppBarState extends State<SearchAppBar> {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       child: null,
//     );
//   }
// }
