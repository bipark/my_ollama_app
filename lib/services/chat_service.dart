import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:ollama_dart/ollama_dart.dart' as ollama;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../provider/main_provider.dart';
import '../models/chat_session.dart';
import '../helpers/event_bus.dart';

class ChatService {
  final BuildContext context;
  final List questions;
  final List<types.Message> messages;
  final types.User answerer;
  final types.User user;
  final Function setState;
  String? selectedImage;
  ChatSession? _chatSession;
  StreamSubscription? _sessionSubscription;

  Function(String)? onMessageUpdate;

  ChatService({
    required this.context,
    required this.questions,
    required this.messages,
    required this.answerer,
    required this.user,
    required this.setState,
    this.selectedImage,
    this.onMessageUpdate,
  });

  void dispose() {
    _cleanupCurrentSession();
  }

  void _cleanupCurrentSession() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;

    if (_chatSession != null) {
      final provider = context.read<MainProvider>();
      provider.disposeChatSession(_chatSession!.chatId);
      _chatSession = null;
    }
  }

  Future<void> startGeneration({
    required String question,
    required String modelName,
    required Function(String) onMessageUpdate,
    required Function(String) onError,
    required Function() onComplete,
  }) async {
    _cleanupCurrentSession();
    final provider = context.read<MainProvider>();
    _chatSession = provider.createChatSession(modelName);

    List<ollama.Message> qmsg = [];

    questions.forEach((item) {
      qmsg.add(ollama.Message(
        role: ollama.MessageRole.system,
        content: item,
      ));
    });

    qmsg.add(ollama.Message(
      role: ollama.MessageRole.system,
      content: provider.instruction,
    ));

    qmsg.add(ollama.Message(
      role: ollama.MessageRole.user,
      content: question,
    ));

    try {
      final stream = _chatSession!.client.generateChatCompletionStream(
        request: ollama.GenerateChatCompletionRequest(
          model: modelName,
          messages: qmsg,
          keepAlive: 5,
          options: ollama.RequestOptions(
            temperature: provider.temperature,
          ),
        ),
      );

      bool receivedResponse = false;
      Timer? timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (!receivedResponse) {
          onError(tr("l_timeout"));
        }
      });

      String answer = '';
      int tokens = 0;
      final stopwatch = Stopwatch()..start();

      try {
        await for (final response in stream) {
          if (!receivedResponse) {
            receivedResponse = true;
            if (timeoutTimer != null && timeoutTimer.isActive) {
              timeoutTimer.cancel();
              timeoutTimer = null;
            }

            onMessageUpdate("Processing...");
          }

          final token = response.message.content ?? '';

          if (token.isNotEmpty) {
            tokens++;
            answer += token;
            onMessageUpdate(answer);

            await Future.delayed(Duration(milliseconds: 1));
          }
        }

        if (timeoutTimer != null && timeoutTimer.isActive) {
          timeoutTimer.cancel();
          timeoutTimer = null;
        }

        stopwatch.stop();
        final seconds = stopwatch.elapsedMilliseconds / 1000;
        final tokensPerSecond = tokens / seconds;

        answer += "\n\n   _MyOllama - $modelName   " +
            "\nToken/Sec: ${tokensPerSecond.toStringAsFixed(1)}" +
            "_";

        onMessageUpdate(answer);

        await provider.qdb.insertQuestion(provider.curGroupId,
            provider.instruction, question, answer, selectedImage, modelName);

        MyEventBus().fire(ChatDoneEvent());

        selectedImage = null;

        onComplete();
      } catch (e) {
        onError(e.toString());
      }
    } catch (e) {
      onError(e.toString());
    }
  }
}
