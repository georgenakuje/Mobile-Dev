import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/gemini.dart';

part 'gemini_chat_service.g.dart';

/// Represents the outcome of an LLM call.
/// Holds either the successful content or an error message.
class LLMResponse {
  final String? content;
  final String? error;

  LLMResponse({this.content, this.error})
    : assert(
        content != null || error != null,
        'Content or error must be present',
      ),
      assert(
        content == null || error == null,
        'Cannot have both content and error',
      );

  /// Factory constructor for a successful response.
  factory LLMResponse.success(String content) {
    return LLMResponse(content: content);
  }

  /// Factory constructor for an error response.
  factory LLMResponse.error(String error) {
    return LLMResponse(error: error);
  }

  bool get isSuccess => content != null;
  bool get isError => error != null;
}

class GeminiChatService {
  GeminiChatService(this.ref);
  final Ref ref;

  /// Sends a message and returns an LLMResponse object.
  Future<LLMResponse> sendMessage(String message) async {
    final chatSession = await ref.read(chatSessionProvider.future);

    try {
      final response = await chatSession.sendMessage(Content.text(message));

      final responseText = response.text;

      // Check if responseText is not null and not empty
      if (responseText != null && responseText.isNotEmpty) {
        return LLMResponse.success(responseText);
      } else {
        // Handle cases where the response is received but has no text content
        return LLMResponse.error(
          'Received response, but content was empty or null.',
        );
      }
    } on Exception catch (e, st) {
      // Catch specific Firebase AI exceptions or general Exceptions
      print(
        'Gemini Chat Error: $e\nStackTrace: $st',
      ); // Log the error for debugging
      return LLMResponse.error(
        'An error occurred during the LLM call: ${e.toString()}',
      );
    } catch (e, st) {
      // Catch any other unexpected errors
      print('Unexpected Error: $e\nStackTrace: $st');
      return LLMResponse.error('An unexpected error occurred: ${e.toString()}');
    }
  }
}

@Riverpod(keepAlive: true)
GeminiChatService geminiChatService(Ref ref) => GeminiChatService(ref);
