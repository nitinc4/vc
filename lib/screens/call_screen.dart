import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:vc/main.dart'; // Import main.dart to access activeChannelIds

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

    _finalLocalUid = widget.uid != 0 ? widget.uid : Random().nextInt(99999999);
    _remoteUid = widget.initialRemoteUid;

    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() => _joined = true);
          debugPrint('✅ Joined channel ${widget.channelId}, Local UID: $_finalLocalUid');
          activeChannelIds.add(widget.channelId);
          debugPrint('DEBUG: Channel ${widget.channelId} added to activeChannelIds on onJoinChannelSuccess.');
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('👤 Remote user joined: $remoteUid');
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('👋 User left: $remoteUid, Reason: $reason');
          setState(() => _remoteUid = null);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('User $remoteUid has left the call.')),
            );
          }
        },
        onLeaveChannel: (connection, stats) {
          debugPrint('📴 Left channel');
          activeChannelIds.remove(widget.channelId);
          debugPrint('DEBUG: Channel ${widget.channelId} removed from activeChannelIds on onLeaveChannel.');
        },
        onError: (errorType, errMsg) {
          debugPrint('❌ Agora error: $errorType - $errMsg');
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
          debugPrint('Remote video state changed for $remoteUid: $state, reason: $reason');
        },
      ),
    );

    await _engine.enableVideo();
    await _engine.startPreview();

    await _engine.joinChannel(
      token: '',
      channelId: widget.channelId,
      uid: _finalLocalUid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _engine.leaveChannel();
    _engine.release();
    activeChannelIds.remove(widget.channelId);
    debugPrint('DEBUG: Channel ${widget.channelId} removed from activeChannelIds on dispose.');
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
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget _renderRemoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid!),
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
    // UPDATED: WillPopScope to prevent navigating away while call is active
    return WillPopScope(
      onWillPop: () async {
        // If the current channelId is still in the activeChannelIds set, prevent popping
        if (activeChannelIds.contains(widget.channelId)) {
          debugPrint('DEBUG: Preventing pop from CallScreen: Channel ${widget.channelId} is active in global state.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please end the call using the red button.')),
          );
          return false; // Prevent pop
        }
        debugPrint('DEBUG: Allowing pop from CallScreen: Channel ${widget.channelId} is not active in global state.');
        return true; // Allow pop
      },
      child: Scaffold(
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
                  color: Colors.black,
                ),
                clipBehavior: Clip.antiAlias,
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
                        // This button explicitly ends the call and pops the screen.
                        Navigator.pop(context);
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
                        _engine.muteLocalVideoStream(_videoOff);
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
      ),
    );
  }
}