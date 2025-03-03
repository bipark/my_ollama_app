import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ollama_dart/ollama_dart.dart';
import 'package:easy_localization/easy_localization.dart';

import '../provider/main_provider.dart';
import '../helpers/event_bus.dart';

class ModelSelector extends StatefulWidget {
  const ModelSelector({super.key});

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  final MenuController _menuController = MenuController();
  List<String> _models = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initEventConnector();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadModels();
    });
  }

  //--------------------------------------------------------------------------//
  void _initEventConnector() async {
    MyEventBus().on<ReloadModelEvent>().listen((event) {
      _loadModels();
    });
  }

  //--------------------------------------------------------------------------//
  void _loadModels() {
    setState(() => _isLoading = true);

    final provider = context.read<MainProvider>();
    if (provider.modelList != null && provider.modelList!.isNotEmpty) {
      _models = provider.modelList!
          .map((Model e) => e.model)
          .where((model) => model != null)
          .map((model) => model!)
          .toList();

      if (provider.selectedModel == null && _models.isNotEmpty) {
        Future.microtask(() {
          provider.setSelectedModel(_models.first);
        });
      }
    } else {
      _models = [];
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MainProvider>(
      builder: (context, provider, child) {
        if (_isLoading) {
          return SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        if (_models.isEmpty) {
          return TextButton.icon(
            onPressed: null,
            icon: Text(tr("l_no_models"),
                style: TextStyle(
                    color: Colors.red[300], fontWeight: FontWeight.bold)),
            label: Icon(Icons.error_outline, color: Colors.red[300]),
          );
        }

        final displayModel = provider.selectedModel ??
            (_models.isNotEmpty ? _models.first : tr("l_no_model"));

        return MenuAnchor(
          alignmentOffset: Offset(0, 8),
          controller: _menuController,
          menuChildren: <Widget>[
            for (final String option in _models)
              MenuItemButton(
                onPressed: () {
                  provider.setSelectedModel(option);
                  _menuController.close();
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
              icon: Text(displayModel,
                  style: TextStyle(
                      color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
              label: Icon(Icons.arrow_drop_down, color: Colors.white),
            );
          },
        );
      },
    );
  }
}
