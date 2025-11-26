import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logistics_toolkit/providers/chat_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:logistics_toolkit/widgets/open_screen.dart';


class ChatScreen extends StatefulWidget {
  final Function(String screen) onNavigate; // provide navigation callback

  const ChatScreen({
    required this.onNavigate,
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final stt.SpeechToText _speech;
  bool _listening = false;
  late String _language = context.locale.languageCode;

  bool _speechAvailable = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    // _language = context.locale.languageCode;

    // // for when we click on the floating action start mic
    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   await _ensurePermissionsAndInit();
    //   if (widget.startListening) {
    //     _toggleListen();
    //   }
    // }
    // );
  }

  //addednew
  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<bool> _requestMicrophonePermission() async {
    //request runtime permission using permission_handler
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> _ensurePermissionsAndInit() async {
    try {
      final granted = await _requestMicrophonePermission();
      if (!granted) {
        setState(() {
          _speechAvailable = false;
          _lastError = 'Microphone permission denied';
        });
        if (kDebugMode) debugPrint('ChatScreen: mic permission denied');
        return;
      }

      // Initialize speech with status and error callbacks
      final available = await _speech.initialize(
        onStatus: (status) {
          if (kDebugMode) debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (!mounted) return;
            setState(() => _listening = false);
          } else if (status == 'listening') {
            if (!mounted) return;
            setState(() => _listening = true);
          }
        },
        onError: (error) {
          if (kDebugMode) debugPrint('Speech error: $error');
          if (!mounted) return;
          setState(() {
            _lastError = error?.errorMsg ?? error.toString();
            _listening = false;
            _speechAvailable = false;
          });
        },
      );

      setState(() {
        _speechAvailable = available;
        if (!available)
          _lastError = 'Speech recognition not available on this device';
      });

      if (kDebugMode) debugPrint('Speech available: $available');
    } catch (e, st) {
      if (kDebugMode) debugPrint('Speech init exception: $e\n$st');
      setState(() {
        _speechAvailable = false;
        _lastError = e.toString();
      });
    }
  }

  Future<void> _toggleListen() async {
    // Ensure we have permission + initialized
    if (!_speechAvailable) {
      await _ensurePermissionsAndInit();
      if (!_speechAvailable) {
        // can't listen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Microphone unavailable: ${_lastError ?? 'unknown'}',
              ),
            ),
          );
        }
        return;
      }
    }

    if (!_listening) {
      try {
        setState(() => _listening = true);
        await _speech.listen(
          onResult: (result) {
            if (!mounted) return;
            setState(() {
              _controller.text = result.recognizedWords;
              // Optionally place cursor at end
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            });
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: _language == 'hi' ? 'hi_IN' : 'en_US',
          // keep or make dynamic
          cancelOnError: true,
          partialResults: true,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Error starting listen: $e');
        setState(() {
          _listening = false;
          _lastError = e.toString();
        });
      }
    } else {
      // stop listening
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
    }
  }

  // Future<void> _toggleListen() async {
  //   if (!_listening) {
  //     final available = await _speech.initialize();
  //     if (available) {
  //       // listen for ONDONE / AUTO STOP
  //       _speech.statusListener = (status) {
  //         if (status == 'done' || status == 'notListening') {
  //           if (!mounted) return;
  //           setState(() => _listening = false);
  //         }
  //       };
  //
  //       //if error is come stop listening
  //       _speech.statusListener = (error) {
  //         if (mounted) setState(() => _listening = false);
  //       };
  //
  //       // for start
  //       setState(() => _listening = true);
  //       _speech.listen(
  //         onResult: (result) {
  //           if (!mounted) return;
  //           setState(() {
  //             _controller.text = result.recognizedWords;
  //           });
  //         },
  //         listenFor: const Duration(seconds: 30),
  //         pauseFor: const Duration(seconds: 3),
  //         localeId: "hi_IN",
  //         cancelOnError: true,
  //         onSoundLevelChange: null,
  //
  //         // partialResults: true,
  //         // listenMode: stt.ListenMode.dictation
  //
  //         // onDone: () {
  //         //   setState(() => _listening = false);
  //         //   //optional : auto send on done
  //         //   //_send();
  //         // }
  //       );
  //     }
  //   } else {
  //     await _speech.stop();
  //     setState(() => _listening = false);
  //   }
  // }

  Future<void> _send() async {
    final txt = _controller.text.trim();
    if (txt.isEmpty) return;
    final provider = Provider.of<ChatProvider>(context, listen: false);
    _controller.clear();
    // _scrollDown();
    await provider.send(
      txt,
      onNavigate: (screen) {
        // navigate when user presses button in message or provider calls back
        widget.onNavigate(screen);
      },
    );

    _scrollDown();
  }

  void _scrollDown(){
    Future.delayed(const Duration(milliseconds: 200), (){
      if(_scroll.hasClients){
        _scroll.animateTo(
        _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut
        );
      }
    });
  }

  Future<void> _showDialogue() async {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('chooseLanguage'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('English'.tr()),
              leading: const Icon(Icons.language),
              onTap: () {
                setState(() => _language = 'en');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('हिंदी'),
              leading: const Icon(Icons.translate),
              onTap: () {
                setState(() => _language = 'hi');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ChatProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Image.asset('assets/chatbot.png', width: 35, height: 40),
            ),
            SizedBox(width: 8),
            Text(
              'Ai Assistance',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),

            Spacer(),

            circleIcon(
              iconColor: provider.ttsEnabled ? Colors.blue : Colors.white,
              icon: provider.ttsEnabled ? Icons.volume_up : Icons.volume_down,
              onTap: provider.toggleTts,
            ),
            SizedBox(width: 8),

            circleIcon(icon: Icons.translate, onTap: _showDialogue),
            SizedBox(width: 2),
          ],
        ),



      ),
      body: Column(
        children: [
          Expanded(
            //agr empty hua message list to ye text ayega centre me bas
            child: provider.messages.isEmpty
                ? Center(
                    child: Text(
                      'Type or speak to ask the chatbot...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                :
                  // agr empty ni hui list to messages
                  ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: provider.messages.length,
                    itemBuilder: (context, index) {
                      final msg = provider.messages[index];
                      return Align(
                        alignment: msg.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: msg.isUser ? Colors.blue : Colors.grey[200],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.text,
                                style: TextStyle(
                                  color: msg.isUser
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                              if (msg.actionButtonScreen != null)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      // widget.onNavigate(
                                      //   msg.actionButtonScreen!,
                                      // );

                                      openScreen(
                                        msg.actionButtonScreen!,
                                        context,
                                        msg.actionParameters ?? {}
                                      );

                                    },
                                    child: Text(
                                      msg.actionButtonLabel ?? 'Open',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // input
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                    onPressed: _toggleListen,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Type or speak...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _send),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget circleIcon({
  required IconData icon,
  required VoidCallback onTap,
  Color iconColor = Colors.white,
  Color iconBgColor = Colors.white24,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(30),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: 20),
    ),
  );
}
