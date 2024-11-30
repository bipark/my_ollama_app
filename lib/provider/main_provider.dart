import 'dart:ffi';

import 'package:flutter/foundation.dart';

import 'package:ollama_dart/ollama_dart.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;

import '../models/model_manager.dart';

final FEED_IMAGE_SIZE = 200.0;


class MainProvider with ChangeNotifier {
  final _prefs = SharedPreferencesAsync();
  PackageInfo? _packageInfo;
  QDatabase qdb = QDatabase();

  bool isInitialized = false;
  bool serveConnected = false;
  String version = "1.0.0";
  int buildNumber = 0;

  String baseUrl = "http://192.168.0.1:11434";
  OllamaClient? ollient;
  List<Model>? modelList;
  String? selectedModel;

  String instruction = "You are a helpful assistant.";
  String curGroupId = Uuid().v4();
  double temperature = 0.5;

  //--------------------------------------------------------------------------//
  Future<void> initialize() async {
    await loadPreferences();

    // Init Ollama
    ollient = OllamaClient(baseUrl: baseUrl + "/api");
    await checkServerConnection();
    await _initPackageInfo();

    // Init DB
    await qdb.init();

    isInitialized = true;
    notifyListeners();
  }

  //--------------------------------------------------------------------------//
  Future<void> loadPreferences() async {
    temperature = await _prefs.getDouble("temperature") ?? 0.5;
    baseUrl = await _prefs.getString("baseUrl") ?? baseUrl;
    instruction = await _prefs.getString("instruction") ?? instruction;

    notifyListeners();
  }

  //--------------------------------------------------------------------------//
  Future<bool> _loadModels() async {
    final model = await _prefs.getString("selectedModel");
    try {
      final res = await ollient!.listModels();
      if (res.models != null) {
        modelList = res.models!;

        if (modelList!.length > 0) {
          bool modelExists = modelList!.any((m) => m.model == model);
          selectedModel = modelExists ? model : modelList!.first.model;
          serveConnected = true;
        }
      }
      notifyListeners();

      return true;
    } catch (e) {
      print(e);
      selectedModel = "No Ollama Models";
      modelList = [];
      notifyListeners();

      return false;
    }
  }

  //--------------------------------------------------------------------------//
  Future<bool> checkServerConnection() async {
    if (await _isOllamaOpen()) {
      serveConnected = true;
      return await _loadModels();
    } else {
      selectedModel = "No Ollama Models";
      return false;
    }
  }

  //--------------------------------------------------------------------------//
  Future<bool> _isOllamaOpen() async {
    try {
      final response = await http.get(Uri.parse(baseUrl)).timeout(Duration(seconds: 1));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  //--------------------------------------------------------------------------//
  void setSelectedModel(String model) {
    selectedModel = model;
    _prefs.setString("selectedModel", model);
    notifyListeners();
  }

  //--------------------------------------------------------------------------//
  Future<void> _initPackageInfo() async {
    _packageInfo = await PackageInfo.fromPlatform();
    version = _packageInfo!.version;
    buildNumber = int.parse(_packageInfo!.buildNumber);
  }

  //--------------------------------------------------------------------------//
  void setTemperature(double temp) {
    temperature = temp;
    _prefs.setDouble("temperature", temp);
    notifyListeners();
  }

  //--------------------------------------------------------------------------//
  Future<bool> setBaseUrl(String url) async {
    baseUrl = url;
    _prefs.setString("baseUrl", url);

    ollient = null;
    ollient = OllamaClient(baseUrl: baseUrl + "/api");
    try {
      await ollient!.listModels();
      notifyListeners();
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  //--------------------------------------------------------------------------//
  void setInstruction(String instruction) {
    this.instruction = instruction;
    _prefs.setString("instruction", instruction);
    notifyListeners();
  }

}