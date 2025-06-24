import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Your Agora App ID
const String appId = 'eebc91dcf2bc42ad9dbdc13c09f1a618'; // Replace with your actual Agora App ID

class CallScreen extends StatefulWidget {
  final String channelId;
  final int uid; // The UID for the local user joining the channel
  final int? initialRemoteUid; // Optional: If you already know the remote UID

  const CallScreen({
    super.key,
    required this.channelId,
    required this.uid,
    this.initialRemoteUid,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine _engine;
  bool _joined = false;
  int? _remoteUid;
  bool _muted = false;
  bool _videoOff = false; // Track local video state
  late final int _finalLocalUid; // The actual UID used by the local user

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep screen on during call

    // Determine the final local UID: use provided widget.uid, or generate random if 0
    _finalLocalUid = widget.uid != 0 ? widget.uid : Random().nextInt(99999999);
    _remoteUid = widget.initialRemoteUid; // Initialize with provided remote UID if any

    _initAgora();
  }

  Future<void> _initAgora() async {
    // Request permissions again just in case, though main.dart should handle initial requests
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() => _joined = true);
          print('✅ Joined channel ${widget.channelId}, Local UID: $_finalLocalUid');
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          print('👤 Remote user joined: $remoteUid');
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          print('👋 User left: $remoteUid, Reason: $reason');
          setState(() => _remoteUid = null);
          // Optional: Show a message that the other party has left
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('User $remoteUid has left the call.')),
            );
          }
        },
        onLeaveChannel: (connection, stats) {
          print('📴 Left channel');
          // No need to pop here, Navigator.pop(context) will trigger this.
        },
        onError: (errorType, errMsg) {
          print('❌ Agora error: $errorType - $errMsg');
          // Optional: Show an error dialog
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Agora Error'),
                content: Text('Error: $errorType\nMessage: $errMsg'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        },
        onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
          print('Remote video state changed for $remoteUid: $state, reason: $reason');
          // You can use this to show loading indicators or blur effects if video is frozen/off
        },
      ),
    );

    await _engine.enableVideo();
    await _engine.startPreview(); // Start local video preview before joining

    // Join the channel
    await _engine.joinChannel(
      token: '', // Leave empty if you are not using Agora tokens (only App ID)
      channelId: widget.channelId,
      uid: _finalLocalUid, // Use the determined local UID
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable(); // Allow screen to turn off
    _engine.leaveChannel();
    _engine.release(); // Release the Agora engine resources
    super.dispose();
  }

  Widget _renderLocalPreview() {
    if (!_joined) {
      return const Center(child: Text('🔌 Joining channel...', style: TextStyle(color: Colors.white)));
    }
    if (_videoOff) {
      return Center(
        child: Icon(Icons.videocam_off, size: 50, color: Colors.white.withOpacity(0.7)),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: const VideoCanvas(uid: 0), // Use UID 0 for local video rendering always
      ),
    );
  }

  Widget _renderRemoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid!), // Render remote user's video
          connection: RtcConnection(channelId: widget.channelId),
        ),
      );
    } else {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              '⏳ Waiting for remote user...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (main view)
          Positioned.fill(child: _renderRemoteVideo()),

          // Local preview (picture-in-picture)
          Positioned(
            top: 40,
            right: 20,
            width: 120,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.black, // Background color when no video/camera off
              ),
              clipBehavior: Clip.antiAlias, // Clip children to border radius
              child: _renderLocalPreview(),
            ),
          ),

          // Control buttons
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute/Unmute Audio
                  FloatingActionButton(
                    heroTag: 'mute',
                    backgroundColor: Colors.white,
                    child: Icon(_muted ? Icons.mic_off : Icons.mic, color: Colors.black),
                    onPressed: () {
                      setState(() => _muted = !_muted);
                      _engine.muteLocalAudioStream(_muted);
                    },
                  ),
                  // End Call
                  FloatingActionButton(
                    heroTag: 'end',
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.call_end, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context); // Go back to the previous screen
                    },
                  ),
                  // Toggle Local Video
                  FloatingActionButton(
                    heroTag: 'video',
                    backgroundColor: Colors.white,
                    child: Icon(_videoOff ? Icons.videocam_off : Icons.videocam, color: Colors.black),
                    onPressed: () {
                      setState(() => _videoOff = !_videoOff);
                      _engine.enableLocalVideo(!_videoOff);
                      _engine.muteLocalVideoStream(_videoOff); // Mute stream visually
                    },
                  ),
                  // Switch Camera
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
          ),
        ],
      ),
    );
  }
}