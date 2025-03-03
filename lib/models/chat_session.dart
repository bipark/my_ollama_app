import 'package:ollama_dart/ollama_dart.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class ChatSession {
  final String chatId;
  final String modelName;
  final OllamaClient client;
  final StreamController<ChatSessionUpdate> messageController;
  bool isActive;
  bool hasError = false;
  String? errorMessage;

  ChatSession({
    required this.chatId,
    required this.modelName,
    required this.client,
  })  : messageController = StreamController<ChatSessionUpdate>.broadcast(),
        isActive = true;

  void dispose() {
    if (!messageController.isClosed) {
      messageController.close();
    }
    isActive = false;
  }

  void addMessage(String content, {bool isError = false}) {
    if (!isActive || messageController.isClosed) return;

    if (isError) {
      hasError = true;
      errorMessage = content;
    }

    messageController.add(ChatSessionUpdate(
      content: content,
      isError: isError,
      timestamp: DateTime.now(),
    ));
  }

  Stream<ChatSessionUpdate> get messageStream => messageController.stream;
}

class ChatSessionUpdate {
  final String content;
  final bool isError;
  final DateTime timestamp;

  ChatSessionUpdate({
    required this.content,
    this.isError = false,
    required this.timestamp,
  });
}
