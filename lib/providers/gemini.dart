import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'system_prompt.dart';

part 'gemini.g.dart';

@Riverpod(keepAlive: true)
Future<GenerativeModel> geminiModel(Ref ref) async {
  final systemPrompt = await ref.watch(systemPromptProvider.future);

  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
    systemInstruction: Content.system(systemPrompt),
  );
  return model;
}

@Riverpod(keepAlive: true)
Future<ChatSession> chatSession(Ref ref) async {
  final model = await ref.watch(geminiModelProvider.future);
  return model.startChat();
}
