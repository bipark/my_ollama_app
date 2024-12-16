import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ollama_dart/ollama_dart.dart';

import '../provider/main_provider.dart';
import '../helpers/event_bus.dart';

class ModelSelector extends StatefulWidget {
  const ModelSelector({super.key});

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  final MenuController _menuController = MenuController();
  List _models = [];

  @override
  void initState() {
    super.initState();
    _initEventConnector();
    _loadModels();
  }

  //--------------------------------------------------------------------------//
  void _initEventConnector() async {
    MyEventBus().on<ReloadModelEvent>().listen((event) {
      _loadModels();
    });
  }


  //--------------------------------------------------------------------------//
  void _loadModels() {
    final provider = context.read<MainProvider>();
    if (provider.modelList != null) {
      _models = provider.modelList!.map((Model e) => e.model).toList();
    } else {
      _models = [provider.selectedModel];
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MainProvider>();

    return MenuAnchor(
      alignmentOffset: Offset(0, 8),
      controller: _menuController,
      menuChildren: <Widget>[
        for (final String option in _models)
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
          icon: Text(
            provider.selectedModel!, 
            style: TextStyle(
              color: Colors.yellowAccent, 
              fontWeight: FontWeight.bold
            )
          ),
          label: Icon(Icons.arrow_drop_down, color: Colors.white),
        );
      },
    );
  }
}
