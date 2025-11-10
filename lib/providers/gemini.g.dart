// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gemini.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(geminiModel)
const geminiModelProvider = GeminiModelProvider._();

final class GeminiModelProvider
    extends
        $FunctionalProvider<
          AsyncValue<GenerativeModel>,
          GenerativeModel,
          FutureOr<GenerativeModel>
        >
    with $FutureModifier<GenerativeModel>, $FutureProvider<GenerativeModel> {
  const GeminiModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'geminiModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$geminiModelHash();

  @$internal
  @override
  $FutureProviderElement<GenerativeModel> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GenerativeModel> create(Ref ref) {
    return geminiModel(ref);
  }
}

String _$geminiModelHash() => r'cab34641565fd1823286344d4b0d725d0113464d';

@ProviderFor(chatSession)
const chatSessionProvider = ChatSessionProvider._();

final class ChatSessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChatSession>,
          ChatSession,
          FutureOr<ChatSession>
        >
    with $FutureModifier<ChatSession>, $FutureProvider<ChatSession> {
  const ChatSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatSessionHash();

  @$internal
  @override
  $FutureProviderElement<ChatSession> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ChatSession> create(Ref ref) {
    return chatSession(ref);
  }
}

String _$chatSessionHash() => r'fdd5e4ed9d06db9712c9300eeb8a1b54a115b10a';
