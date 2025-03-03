import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:ollama_dart/ollama_dart.dart';
import 'package:easy_localization/easy_localization.dart';

import '../provider/main_provider.dart';
import '../helpers/event_bus.dart';
import '../widgets/title_list.dart';
import '../widgets/model_selector.dart';
import '../widgets/list_header.dart';

import 'chat_view.dart';

class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key});

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  final _drawer = AdvancedDrawerController();
  List<Widget>? _action;
  Widget? _currentWidget;

  //--------------------------------------------------------------------------//
  @override
  void initState() {
    super.initState();
    _initEventConnector();
    _currentWidget = const ChatView();
  }

  //--------------------------------------------------------------------------//
  void _initEventConnector() async {
    MyEventBus().on<ChangeTitleEvent>().listen((event) {
      if (mounted) {
        _action = event.action;
        setState(() {});
      }
    });

    MyEventBus().on<CloseDrawerEvent>().listen((event) {
      _drawer.hideDrawer();
    });

    MyEventBus().on<ReloadModelEvent>().listen((event) {
      setState(() {}); // Just refresh the state to rebuild ModelSelector
    });
  }

  //--------------------------------------------------------------------------//
  void _handleMenuButtonPressed() {
    _drawer.showDrawer();
  }

  //--------------------------------------------------------------------------//
  PreferredSizeWidget _appbar() {
    return AppBar(
      title: const ModelSelector(),
      leading: IconButton(
        onPressed: _handleMenuButtonPressed,
        icon: ValueListenableBuilder<AdvancedDrawerValue>(
          valueListenable: _drawer,
          builder: (_, value, __) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                value.visible ? Icons.clear : Icons.menu,
                key: ValueKey<bool>(value.visible),
              ),
            );
          },
        ),
      ),
      actions: _action,
    );
  }

  //--------------------------------------------------------------------------//
  Widget _listContainer() {
    return Container(
      color: Colors.white,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ListHeader(),
          Expanded(child: TitleList()),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------//
  @override
  Widget build(BuildContext context) {
    return AdvancedDrawer(
      backdropColor: Colors.indigo,
      controller: _drawer,
      animateChildDecoration: true,
      rtlOpening: false,
      openScale: 1.0,
      openRatio: 0.8,
      disabledGestures: true,
      child: Scaffold(
        appBar: _appbar(),
        body: Container(child: _currentWidget),
      ),
      drawer: SafeArea(
        child: _listContainer(),
      ),
    );
  }
}
