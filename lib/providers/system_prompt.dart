import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'system_prompt.g.dart';

@Riverpod(keepAlive: true)
Future<String> systemPrompt(Ref ref) =>
    rootBundle.loadString('assets/system_prompt.md');
