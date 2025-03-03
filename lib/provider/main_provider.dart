import 'dart:ffi';

import 'package:flutter/foundation.dart';

import 'package:ollama_dart/ollama_dart.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;

import '../models/model_manager.dart';
import '../models/chat_session.dart';
import '../helpers/event_bus.dart';

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
  Map<String, ChatSession> activeSessions = {};
  List<Model>? modelList;
  String? selectedModel;

  String instruction = "You are a helpful assistant.";
  String curGroupId = Uuid().v4();
  double temperature = 0.5;

  //--------------------------------------------------------------------------//
  Future<void> initialize() async {
    await loadPreferences();
    await checkServerConnection();
    await _initPackageInfo();
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
  Future<bool> checkServerConnection() async {
    if (await _isOllamaOpen()) {
      serveConnected = true;
      return await _loadModels();
    } else {
      return false;
    }
  }

  //--------------------------------------------------------------------------//
  Future<bool> _loadModels() async {
    try {
      final client = OllamaClient(baseUrl: baseUrl + "/api");
      final res = await client.listModels();
      if (res.models != null) {
        modelList = res.models!;
        serveConnected = modelList!.isNotEmpty;
      }
      notifyListeners();
      return true;
    } catch (e) {
      print(e);
      modelList = [];
      notifyListeners();
      return false;
    }
  }

  //--------------------------------------------------------------------------//
  Future<bool> _isOllamaOpen() async {
    try {
      final response =
          await http.get(Uri.parse(baseUrl)).timeout(Duration(seconds: 1));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  //--------------------------------------------------------------------------//
  ChatSession createChatSession(String modelName) {
    Future.microtask(() {
      _cleanupInactiveSessions();
    });

    final chatId = Uuid().v4();
    final client = OllamaClient(baseUrl: baseUrl + "/api");

    final session = ChatSession(
      chatId: chatId,
      modelName: modelName,
      client: client,
    );

    activeSessions[chatId] = session;

    Future.microtask(() {
      notifyListeners();
    });

    return session;
  }

  //--------------------------------------------------------------------------//
  void _cleanupInactiveSessions() {
    final inactiveSessions = activeSessions.entries
        .where((entry) => !entry.value.isActive)
        .map((entry) => entry.key)
        .toList();

    for (final sessionId in inactiveSessions) {
      disposeChatSession(sessionId);
    }
  }

  //--------------------------------------------------------------------------//
  void disposeChatSession(String chatId) {
    final session = activeSessions[chatId];
    if (session != null) {
      try {
        session.dispose();
      } catch (e) {
        print("Error disposing session: $e");
      }
      activeSessions.remove(chatId);

      Future.microtask(() {
        notifyListeners();
      });
    }
  }

  //--------------------------------------------------------------------------//
  void disposeAllSessions() {
    for (final session in activeSessions.values) {
      try {
        session.dispose();
      } catch (e) {
        print("Error disposing session: $e");
      }
    }
    activeSessions.clear();

    Future.microtask(() {
      notifyListeners();
    });
  }

  //--------------------------------------------------------------------------//
  void setSelectedModel(String model) {
    selectedModel = model;
    _prefs.setString("selectedModel", model);

    Future.microtask(() {
      notifyListeners();
    });
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

    // Dispose all active sessions
    disposeAllSessions();

    return await checkServerConnection();
  }

  //--------------------------------------------------------------------------//
  void setInstruction(String instruction) {
    this.instruction = instruction;
    _prefs.setString("instruction", instruction);
    notifyListeners();
  }
}
