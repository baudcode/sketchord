import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_flux/flutter_flux.dart' show Action, Store, StoreToken;

enum MenuItem { HOME, SETTINGS, TRASH, SETS, AUDIO }

class MenuOption {
  MenuItem item;
  String name;
  IconData icon;
  MenuOption({this.item, this.name, this.icon});
}

var options = [
  MenuOption(icon: Icons.dashboard, name: "Home", item: MenuItem.HOME),
  MenuOption(icon: Icons.music_note, name: "Ideas", item: MenuItem.AUDIO),
  MenuOption(icon: Icons.list_alt_outlined, name: "Sets", item: MenuItem.SETS),
  MenuOption(icon: Icons.delete_sweep, name: "Trash", item: MenuItem.TRASH),
  MenuOption(icon: Icons.settings, name: "Settings", item: MenuItem.SETTINGS),
];

class MenuStore extends Store {
  // default values

  MenuItem _item = MenuItem.HOME;

  bool _collapsed;

  bool get collapsed => _collapsed;
  MenuItem get item => _item;

  MenuStore() {
    // init listener
    _collapsed = true;

    toggleMenu.listen((s) {
      _collapsed = !_collapsed;
      trigger();
    });

    setMenuItem.listen((item) {
      _item = item;
      trigger();
    });
  }
}

Action<MenuItem> setMenuItem = Action();
Action toggleMenu = Action();
StoreToken menuStoreToken = StoreToken(MenuStore());
