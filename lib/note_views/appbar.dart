import 'package:flutter/material.dart';
import 'package:sound/storage.dart';

typedef FilterByCallback = bool Function(FilterBy);
typedef FilterCallback = bool Function(Filter);

class FilterView extends StatelessWidget {
  final bool active;
  final Filter filter;
  final ValueChanged<Filter> remove, add;

  const FilterView(
      {required this.filter,
      required this.active,
      required this.remove,
      required this.add,
      super.key});

  @override
  Widget build(BuildContext context) {
    Color? backgroundColor = (active)
        ? Theme.of(context).chipTheme.selectedColor
        : Theme.of(context).chipTheme.backgroundColor;

    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: ActionChip(
            backgroundColor: backgroundColor,
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

  const FilterOptionsView(
      {required this.title,
      required this.data,
      required this.by,
      required this.showMore,
      required this.mustShowMore,
      required this.isFilterApplied,
      super.key});

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
                      style: Theme.of(context).textTheme.bodySmall),
                  (mustShowMore)
                      ? GestureDetector(
                          onTap: () => toggleShowMore(by),
                          child: Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: Text(
                                  (showMore) ? 'Show Less' : 'Show More',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color:
                                              Theme.of(context).colorScheme.secondary))))
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

  const ActiveFiltersView(
      {required this.filters, required this.removeFilter, super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.only(left: 25, top: 70),
        child: Container(
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
                      Color color =
                          Theme.of(context).chipTheme.selectedColor ??
                              Theme.of(context).colorScheme.secondary;

                      return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: ActionChip(
                              backgroundColor: color,
                              label: Text(
                                filter.content,
                              ),
                              onPressed: () => removeFilter(filter)));
                    },
                  ))
            ])));
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
