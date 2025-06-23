import 'package:flutter/material.dart';
import 'package:vc/screens/call_screen.dart';
import 'package:audioplayers/audioplayers.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerId;
  final String channelId;

  const IncomingCallScreen({
    super.key,
    required this.callerId,
    required this.channelId,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playRingtone();
  }

  void _playRingtone() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/ringtone.mp3'));
  }

  void _stopRingtone() async => await _player.stop();

  void _onAnswer() async {
    _stopRingtone();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          channelId: 'default_channel',
          uid: 2,
          initialRemoteUid: null, // can be null initially
        ),
      ),
    );
  }

  void _onDecline() async {
    _stopRingtone();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Icon(Icons.videocam, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              '${widget.callerId} is calling...',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.call),
                  onPressed: _onAnswer,
                ),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end),
                  onPressed: _onDecline,
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
