import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:sound/home.dart';
import 'package:sound/intent_receive.dart';
import 'package:sound/settings.dart';
import 'package:sound/trash.dart';

class Menu extends StatefulWidget {
  Menu();

  @override
  State<StatefulWidget> createState() {
    return _MenuState();
  }
}

enum MenuItem { HOME, SETTINGS, TRASH }

class MenuOption {
  MenuItem item;
  String name;
  IconData icon;
  MenuOption({this.item, this.name, this.icon});
}

class _MenuState extends State<Menu> with SingleTickerProviderStateMixin {
  bool isCollapsed = true;
  final animateMenuDuration = const Duration(milliseconds: 300);

  AnimationController _controller;
  Animation<Offset> _slideAnimation; // slide menu from left to right
  Animation<double> _scaleAnimation,
      _menuScaleAnimation; // scale home content from 1.0 to 0.8

  MenuItem current = MenuItem.HOME;

  var options = [
    MenuOption(icon: Icons.dashboard, name: "Home", item: MenuItem.HOME),
    MenuOption(icon: Icons.delete_sweep, name: "Trash", item: MenuItem.TRASH),
    MenuOption(icon: Icons.settings, name: "Settings", item: MenuItem.SETTINGS),
  ];

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: animateMenuDuration);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(_controller);
    _menuScaleAnimation =
        Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
    _slideAnimation = Tween<Offset>(begin: Offset(-1.0, 0), end: Offset(0, 0))
        .animate(_controller);

    setupIntentReceivers(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _switch(MenuItem item) {
    _onMenuPressed();
    setState(() {
      current = item;
    });
    FirebaseAnalytics()
        .logEvent(name: 'Menu', parameters: {'Value': item.index});
    //Navigator.push(
    //    context, new MaterialPageRoute(builder: (context) => Settings()));
  }

  menu(BuildContext context) {
    return SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
            scale: _menuScaleAnimation,
            child: Padding(
                padding: EdgeInsets.only(left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                      spacing: 20,
                      runAlignment: WrapAlignment.spaceEvenly,
                      alignment: WrapAlignment.start,
                      direction: Axis.vertical,
                      //mainAxisSize: MainAxisSize.min,
                      //mainAxisAlignment: MainAxisAlignment.spaceAround,
                      //crossAxisAlignment: CrossAxisAlignment.start,
                      children: options
                          .map((e) => FlatButton.icon(
                                label: Text(e.name,
                                    style: TextStyle(fontSize: 20)),
                                icon: Icon(e.icon),
                                onPressed: () => _switch(e.item),
                              ))
                          .toList()),
                ))));
  }

  _getView() {
    switch (current) {
      case MenuItem.HOME:
        return Home(this._onMenuPressed);
      case MenuItem.SETTINGS:
        return Settings(this._onMenuPressed);
      case MenuItem.TRASH:
        return Trash(this._onMenuPressed);
      default:
        return Container();
    }
  }

  positioned(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double screenWidth = size.width;

    return AnimatedPositioned(
        duration: animateMenuDuration,
        top: 0,
        bottom: 0,
        left: isCollapsed ? 0 : 0.6 * screenWidth,
        right: isCollapsed ? 0 : -0.4 * screenWidth,
        child: ScaleTransition(
            scale: _scaleAnimation,
            child: MediaQuery.removePadding(
                context: context,
                removeTop: isCollapsed ? false : true,
                child: Material(
                  animationDuration: animateMenuDuration,
                  child: !isCollapsed
                      ? AbsorbPointer(child: _getView())
                      : _getView(),
                  borderRadius:
                      BorderRadius.all(Radius.circular(isCollapsed ? 0 : 10)),
                  color: Theme.of(context).appBarTheme.color,
                  clipBehavior: Clip.antiAlias,
                  elevation: 5,
                ))));
  }

  _onMenuPressed() {
    setState(() {
      if (isCollapsed) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      isCollapsed = !isCollapsed;
    });
  }

  _menuWithScaffold(BuildContext context) {
    return Scaffold(
      body: menu(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [_menuWithScaffold(context), positioned(context)]);
  }
}
