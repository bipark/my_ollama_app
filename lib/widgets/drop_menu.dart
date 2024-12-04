import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class DropMenu extends StatefulWidget {
  final Function netCheck;
  final Function newNote;
  final Function shareAll;
  final Function showSettings;
  const DropMenu(this.netCheck, this.newNote, this.shareAll, this.showSettings, {super.key});

  @override
  State<DropMenu> createState() => _DropMenuState();
}

class _DropMenuState extends State<DropMenu> {
  final FocusNode _buttonFocusNode = FocusNode(debugLabel: 'DropMenu');

  @override
  void dispose() {
    _buttonFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      childFocusNode: _buttonFocusNode,
      menuChildren: <Widget>[
        MenuItemButton(
          child: Row(
            children: <Widget>[
              const Icon(Icons.network_check),
              const SizedBox(width: 8),
              Text(tr("l_server_check")),
            ],
          ),
          onPressed: (){
            widget.netCheck();
          },
        ),
        MenuItemButton(
          child: Row(
            children: <Widget>[
              const Icon(Icons.note_add_outlined),
              const SizedBox(width: 8),
              Text(tr("l_new_chat")),
            ],
          ),
          onPressed: () {
            widget.newNote();
          },
        ),
        MenuItemButton(
          child: Row(
            children: <Widget>[
              const Icon(Icons.share),
              const SizedBox(width: 8),
              Text(tr("l_share_all")),
            ],
          ),
          onPressed: () {
            widget.shareAll();
          },
        ),
        MenuItemButton(
          child: Row(
            children: <Widget>[
              const Icon(Icons.settings),
              const SizedBox(width: 8),
              Text(tr("l_settings")),
            ],
          ),
          onPressed: () {
            widget.showSettings();
          },
        ),
      ],
      builder: (_, MenuController controller, Widget? child) {
        return IconButton(
          focusNode: _buttonFocusNode,
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.more_vert),
        );
      },
    );
  }
}
