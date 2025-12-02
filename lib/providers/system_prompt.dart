import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'system_prompt.g.dart';

//loads a markdown with an initial system prompt letting the ai know
//its purpose over the course of the to be chat
@Riverpod(keepAlive: true)
Future<String> systemPrompt(Ref ref) =>
    rootBundle.loadString('assets/system_prompt.md');
