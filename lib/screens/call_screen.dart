// ✅ Updated call_screen.dart with fixed local preview
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const String appId = 'eebc91dcf2bc42ad9dbdc13c09f1a618';

class CallScreen extends StatefulWidget {
  final String channelId;
  final int uid;

  const CallScreen({super.key, required this.channelId, required this.uid});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine _engine;
  bool _joined = false;
  int? _remoteUid;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep screen on during call
    _initAgora();
}

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));

    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        setState(() {
          _joined = true;
        });
        print('✅ Joined channel: ${widget.channelId}, UID: ${widget.uid}');
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        setState(() {
          _remoteUid = remoteUid;
        });
        print('👤 Remote user joined: $remoteUid');
      },
      onUserOffline: (connection, remoteUid, reason) {
        setState(() {
          _remoteUid = null;
        });
        print('🚪 User left: $remoteUid');
      },
    ));

    await _engine.enableVideo();

    await _engine.joinChannel(
      token: '',
      channelId: widget.channelId,
      uid: widget.uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable(); // Allow screen to sleep again
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
}

 Widget _renderLocalPreview() {
    if (_joined) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    } else {
      return const Center(child: Text('Joining channel...'));
    }
  }

  Widget _renderRemoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelId),
        ),
      );
    } else {
      return const Center(child: Text('Waiting for user to join...', style: TextStyle(color: Colors.white)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _renderRemoteVideo()),
          Positioned(
            top: 40,
            right: 20,
            width: 120,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white),
              ),
              child: _renderLocalPreview(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: 'mute',
                    backgroundColor: Colors.white,
                    child: Icon(
                      _muted ? Icons.mic_off : Icons.mic,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      _engine.muteLocalAudioStream(!_muted);
                      setState(() => _muted = !_muted);
                    },
                  ),
                  FloatingActionButton(
                    heroTag: 'end',
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.call_end),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  FloatingActionButton(
                    heroTag: 'switch',
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.cameraswitch, color: Colors.black),
                    onPressed: () {
                      _engine.switchCamera();
                    },
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
