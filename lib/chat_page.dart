import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import './providers/gemini.dart';
import './services/gemini_chat_service.dart';
import 'ics_import.dart';
import 'package:intl/intl.dart';

/// A simple model to represent a single chat message.
class Message {
  final String text;
  final String sender; // 'user' or 'llm'
  final bool isLoading;
  final bool isError;

  Message({
    required this.text,
    required this.sender,
    this.isLoading = false,
    this.isError = false,
  });

  // Factory constructor for user messages
  factory Message.user(String text) => Message(text: text, sender: 'user');

  // Factory constructor for loading (LLM is thinking)
  factory Message.loading() =>
      Message(text: 'Typing...', sender: 'llm', isLoading: true);

  // Factory constructor for successful LLM response
  factory Message.llm(String text) => Message(text: text, sender: 'llm');

  // Factory constructor for error LLM response
  factory Message.error(String error) =>
      Message(text: 'Error: $error', sender: 'llm', isError: true);
}

class ChatApp extends ConsumerWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the FutureProvider for the GenerativeModel
    final modelAsyncValue = ref.watch(geminiModelProvider);

    return modelAsyncValue.when(
      // === State 1: Data Loaded (Model Initialized) ===
      data: (model) {
        return ChatScreen((icsText) async {
          // no-op when ChatApp is used standalone
        });
      },
      // === State 2: Loading ===
      loading: () {
        // Display a progress indicator while the model is initializing.
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading AI Model...'),
              ],
            ),
          ),
        );
      },

      // === State 3: Error Occurred ===
      error: (error, stackTrace) {
        // Display an error message if the model failed to load.
        return Scaffold(
          body: Center(
            child: Text(
              'Failed to load model: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );
      },
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  final Future<void> Function(String icsText) onIcsDetected;

  const ChatScreen(this.onIcsDetected, {super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final RegExp _iCalRegex = RegExp(
    r'BEGIN:VCALENDAR.*?END:VCALENDAR',
    caseSensitive: false,
    dotAll: true, // Allows '.' to match newlines
  );
  final TextEditingController _textController = TextEditingController();
  final List<Message> _messages = [];
  bool firstMessage = true; // State variable to track the first message

  // Function to handle sending the message
  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return; // Prevent sending empty messages

    String userMessageText = text;
    if (firstMessage) {
      final now = DateTime.now();
      final dateString = '${now.year}-${now.month}-${now.day}';
      final timezone = now.timeZoneName;

      final contextPrefix =
          'Today\'s date is $dateString and the timezone is $timezone.\n\n';

      // Prepend the context to the message sent to the LLM
      userMessageText = contextPrefix + text;

      // Update the flag after processing the first message
      firstMessage = false;
    }
    _textController.clear(); // Clear the input field

    // Add the user's message
    setState(() {
      _messages.add(Message.user(userMessageText));
    });

    // Add a 'loading' message placeholder
    setState(() {
      _messages.add(Message.loading());
    });

    // Call the LLM service
    respond(userMessageText);
  }

  // Function to call the LLM service
  void respond(String message) async {
    // Read the chat service provider
    final chatService = ref.read(geminiChatServiceProvider);

    // Find the index of the loading message (always the last one added)
    final int loadingIndex = _messages.length - 1;

    // Call the service
    final llmResponse = await chatService.sendMessage(message);

    String? detectedIcs; // will hold ICS block if found

    // Remove the loading indicator and add the actual response/error
    setState(() {
      // Safety check: ensure the last message is still the loading indicator
      if (loadingIndex >= 0 && _messages[loadingIndex].isLoading) {
        _messages.removeAt(loadingIndex); // Remove the 'loading' message
      }

      if (llmResponse.isSuccess && llmResponse.content != null) {
        final text = llmResponse.content!;

        // Add the successful response
        _messages.add(Message.llm(text));

        final match = _iCalRegex.firstMatch(text);
        if (match != null) {
          detectedIcs = match.group(0);
        }
      } else {
        // Add an error message
        _messages.add(
          Message.error(llmResponse.error ?? 'Unknown error occurred.'),
        );
      }
    });

    if (detectedIcs != null) {
      await widget.onIcsDetected(detectedIcs!);
    }
  }

  Future<void> _importAndSummarizeIcs() async {
    String? events = await importIcsFile();
    // if (events.isEmpty) return;
    //
    // final formatter = DateFormat('EEE MMM d, h:mm a');
    // final summaryPrompt = StringBuffer();
    //
    // summaryPrompt.writeln("These events were imported from a calendar file:");
    // for (final e in events) {
    //   summaryPrompt.writeln(
    //     "- ${e.title} (${formatter.format(e.startTime)} to ${formatter.format(e.endTime)})",
    //   );
    // }
    // summaryPrompt.writeln("Summarize these events briefly for the user.");
    //
    // // Add user prompt visually
    // setState(() {
    //   _messages.add(Message.user(summaryPrompt.toString()));
    //   _messages.add(Message.loading());
    // });
    //
    // final chatService = ref.read(geminiChatServiceProvider);
    // final response = await chatService.sendMessage(summaryPrompt.toString());
    //
    // setState(() {
    //   _messages.removeWhere((m) => m.isLoading);
    //   _messages.add(
    //     response.isSuccess && response.content != null
    //         ? Message.llm(response.content!)
    //         : Message.error(response.error ?? 'Unknown error'),
    //   );
    // });
    late final match = _iCalRegex.firstMatch(events!);
    if (match != null) {
      final icsText = match.group(0)!;
      widget.onIcsDetected(icsText);
    }
  }


  // Function to copy text to the clipboard and show a confirmation
  // void _copyToClipboard(String text) async {
  //   await Clipboard.setData(ClipboardData(text: text));
  //
  //   // Optionally show a confirmation to the user
  //   if (mounted) {
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import .ics file',
            onPressed: _importAndSummarizeIcs,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Message List
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true, // Show newest messages at the bottom
              itemCount: _messages.length,
              itemBuilder: (_, int index) {
                final message = _messages[_messages.length - 1 - index];
                return _buildMessage(message);
              },
            ),
          ),
          const Divider(height: 1.0),
          // Input Field and Send Button
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  // Helper widget to build the message input area
  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 30.0),
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: <Widget>[
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                decoration: const InputDecoration.collapsed(
                  hintText: 'Send a message',
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to display an individual message
  Widget _buildMessage(Message message) {
    final bool isUser = message.sender == 'user';
    final bool isLLM =
        message.sender == 'llm' && !message.isLoading && !message.isError;

    // **NEW: Check for iCalendar content**
    final RegExpMatch? iCalMatch = isLLM
        ? _iCalRegex.firstMatch(message.text)
        : null;
    final bool hasICal = iCalMatch != null;
    final String iCalContent = hasICal ? iCalMatch.group(0)! : '';

    // Determine colors and alignment based on status
    final Color backgroundColor = isUser
        ? Colors.blue.shade100
        : message.isError
        ? Colors.red.shade100
        : Colors.grey.shade200;

    final CrossAxisAlignment alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            //text box and copy button
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ), // Constrain message width
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: message.isLoading
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Typing...',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      )
                    : isLLM
                    ? MarkdownBody(
                        data: message
                            .text, // The LLM response containing markdown
                        shrinkWrap:
                            true, // Important to prevent unbounded height errors
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(color: Colors.black87),
                          code: TextStyle(color: Colors.deepPurple),
                        ),
                      )
                    : Text(
                        message.text,
                        style: TextStyle(
                          color: isUser
                              ? Colors.black87
                              : (message.isError
                                    ? Colors.red.shade900
                                    : Colors.black),
                        ),
                      ),
              ),
              if (isLLM && hasICal && !isUser)
                // Padding(
                //   padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                //   child: IconButton(
                //     icon: const Icon(Icons.copy, size: 20),
                //     onPressed: () => _copyToClipboard(iCalContent),
                //     tooltip: 'Copy iCalendar content',
                //     color: Colors.grey.shade600,
                //   ),
                // ),
              if (isUser &&
                  hasICal) // Although generally not needed for user, keep consistent structure
                const SizedBox(width: 36), // Placeholder for alignment
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 8.0, right: 8.0),
            child: Text(
              isUser
                  ? 'You'
                  : message.isError
                  ? 'LLM (Error)'
                  : 'LLM',
              style: TextStyle(fontSize: 12.0),
            ),
          ),
        ],
      ),
    );
  }
}
