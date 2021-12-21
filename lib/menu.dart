import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:sound/audio_list.dart';
import 'package:sound/home.dart';
import 'package:sound/intent_receive.dart';
import 'package:sound/collections.dart';
import 'package:sound/menu_store.dart';
import 'package:sound/settings.dart';
import 'package:sound/trash.dart';

class Menu extends StatefulWidget {
  Menu();

  @override
  State<StatefulWidget> createState() {
    return _MenuState();
  }
}

class _MenuState extends State<Menu>
    with SingleTickerProviderStateMixin, StoreWatcherMixin<Menu> {
  final animateMenuDuration = const Duration(milliseconds: 300);

  AnimationController _controller;
  Animation<Offset> _slideAnimation; // slide menu from left to right
  Animation<double> _scaleAnimation,
      _menuScaleAnimation; // scale home content from 1.0 to 0.8

  MenuStore store;

  @override
  void initState() {
    super.initState();
    store = listenToStore(menuStoreToken);
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
    setMenuItem(item);
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
                          .map((e) => TextButton.icon(
                                label: Text(e.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .button
                                        .copyWith(fontSize: 20)),
                                icon: Icon(e.icon,
                                    color: Theme.of(context)
                                        .textTheme
                                        .button
                                        .color),
                                onPressed: () => _switch(e.item),
                              ))
                          .toList()),
                ))));
  }

  _getView() {
    switch (store.item) {
      case MenuItem.HOME:
        return Home(this._onMenuPressed);
      case MenuItem.SETTINGS:
        return Settings(this._onMenuPressed);
      case MenuItem.TRASH:
        return Trash(this._onMenuPressed);
      case MenuItem.SETS:
        return Collections(this._onMenuPressed);
      case MenuItem.AUDIO:
        return AudioList(onMenuPressed: this._onMenuPressed);
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
        left: store.collapsed ? 0 : 0.6 * screenWidth,
        right: store.collapsed ? 0 : -0.4 * screenWidth,
        child: ScaleTransition(
            scale: _scaleAnimation,
            child: MediaQuery.removePadding(
                context: context,
                removeTop: store.collapsed ? false : true,
                child: Material(
                  animationDuration: animateMenuDuration,
                  child: !store.collapsed
                      ? GestureDetector(
                          onTap: _onMenuPressed,
                          child: AbsorbPointer(child: _getView()))
                      : _getView(),
                  borderRadius: BorderRadius.all(
                      Radius.circular(store.collapsed ? 0 : 10)),
                  color: Theme.of(context).appBarTheme.color,
                  clipBehavior: Clip.antiAlias,
                  elevation: 5,
                ))));
  }

  _onMenuPressed() {
    if (store.collapsed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    toggleMenu();
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
