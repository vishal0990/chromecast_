import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';


class ScreenSharingApp extends StatefulWidget {
  @override
  _ScreenSharingAppState createState() => _ScreenSharingAppState();
}

class _ScreenSharingAppState extends State<ScreenSharingApp> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final _signalingServerUrl = 'wss://your-signaling-server-url'; // Your WebSocket signaling server

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();
  }

  Future<MediaStream> captureScreen() async {
    try {
      final stream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,  // Capture video stream (screen)
        'audio': true,  // Optional: Capture audio along with the screen
      });
      return stream;
    } catch (e) {
      print('Error capturing screen: $e');
      rethrow;
    }
  }

  Future<void> createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    _peerConnection =  createPeerConnection() as RTCPeerConnection?;

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        sendToSignalingServer({
          'type': 'candidate',
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
      }
    };

    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    sendToSignalingServer({
      'type': 'offer',
      'sdp': offer.sdp,
    });
  }

  void sendToSignalingServer(Map<String, dynamic> message) {
    // Implement your signaling server communication (WebSocket example)
    // Example: WebSocket.send(message)
  }

  Future<void> onSignalingMessage(Map<String, dynamic> message) async {
    if (message['type'] == 'offer') {
      RTCSessionDescription offer = RTCSessionDescription(message['sdp'], 'offer');
      await _peerConnection!.setRemoteDescription(offer);

      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      sendToSignalingServer({
        'type': 'answer',
        'sdp': answer.sdp,
      });
    } else if (message['type'] == 'answer') {
      RTCSessionDescription answer = RTCSessionDescription(message['sdp'], 'answer');
      await _peerConnection!.setRemoteDescription(answer);
    } else if (message['type'] == 'candidate') {
      RTCIceCandidate candidate = RTCIceCandidate(
        message['candidate'],
        message['sdpMid'],
        message['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    }
  }

  Future<void> startScreenSharing() async {
    _localStream = await captureScreen();

    await createPeerConnection();

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Screen Sharing')),
      body: Column(
        children: [
          Expanded(child: RTCVideoView(_localRenderer)),
          Expanded(child: RTCVideoView(_remoteRenderer)),
          ElevatedButton(
            onPressed: startScreenSharing,
            child: Text('Start Screen Sharing'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.close();
    super.dispose();
  }
}
