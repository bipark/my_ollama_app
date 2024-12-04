import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:ollama_dart/ollama_dart.dart';
import 'package:easy_localization/easy_localization.dart';

import '../provider/main_provider.dart';
import '../helpers/event_bus.dart';
import '../widgets/title_list.dart';

import 'home_view.dart';

class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key});

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  final _drawer = AdvancedDrawerController();
  List<Widget>? _action;
  Widget? _currentWidget;
  final MenuController _menuController = MenuController();

  //--------------------------------------------------------------------------//
  @override
  void initState() {
    super.initState();
    _initEventConnector();
    _currentWidget = MyHome();
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
      _selectModel();
    });

  }

  //--------------------------------------------------------------------------//
  void _handleMenuButtonPressed() {
    _drawer.showDrawer();
  }

  //--------------------------------------------------------------------------//
  Widget _selectModel() {
    final provider = context.read<MainProvider>();
    List models = [];
    if (provider.modelList != null) {
      models = provider.modelList!.map((Model e) => e.model).toList();
    } else {
      models = [provider.selectedModel];
    }

    return MenuAnchor(
      alignmentOffset: Offset(0, 8),
      controller: _menuController,
      menuChildren: <Widget>[
        for (final String option in models)
          MenuItemButton(
            onPressed: () {
              setState(() {
                provider.selectedModel = option;
                provider.setSelectedModel(option);
                _menuController.close();
              });
            },
            child: Text(option, style: TextStyle(color: Colors.black)),
          ),
      ],
      builder: (context, controller, child) {
        return TextButton.icon(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: Text(provider.selectedModel!, style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
          label: Icon(Icons.arrow_drop_down, color: Colors.white,),
        );
      },
    );
  }

  //--------------------------------------------------------------------------//
  PreferredSizeWidget _appbar() {
    return AppBar(
      title: _selectModel(),
      leading: IconButton(
        onPressed: _handleMenuButtonPressed,
        icon: ValueListenableBuilder<AdvancedDrawerValue>(
          valueListenable: _drawer,
          builder: (_, value, __) {
            return AnimatedSwitcher(
              duration: Duration(milliseconds: 250),
              child: Icon(
                value.visible ? Icons.clear : Icons.menu,
                key: ValueKey<bool>(value.visible),
              ),
            );
          },
        ),
      ),
      actions: _action != null ? _action! : [],
    );
  }

  //--------------------------------------------------------------------------//
  Widget _listContainer() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            height: 56,
            child: Row(
              children: [
                SizedBox(width: 10),
                Image.asset("assets/images/ollama.png", width: 24, height: 20),
                SizedBox(width: 6),
                Text(tr("l_myollama"), style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo)),
                Spacer(),
                IconButton(
                    onPressed: () {
                      MyEventBus().fire(RefreshMainListEvent());
                    }, icon: Icon(Icons.refresh, color: Colors.black)),
              ],
            ),
          ),
          Expanded(child: TitleList()),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------//
  @override
  Widget build(BuildContext context) {
    return AdvancedDrawer(
      backdropColor: Colors.white,
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
    ;
  }
}
