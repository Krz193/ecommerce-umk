import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mobile/core/config/supabase_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher/url_launcher.dart';

class InAppCallDialog extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final String remotePartyName;
  final String remotePartyPhone;
  final String callerRole; // 'buyer', 'ojek', 'ekspedisi', 'seller'

  const InAppCallDialog({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.remotePartyName,
    required this.remotePartyPhone,
    this.callerRole = 'buyer',
  });

  @override
  State<InAppCallDialog> createState() => _InAppCallDialogState();
}

class _InAppCallDialogState extends State<InAppCallDialog> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RealtimeChannel? _signalingChannel;
  Timer? _callTimer;

  String _callState =
      'connecting'; // 'connecting', 'ringing', 'connected', 'ended'
  String _statusMessage = 'Menyiapkan saluran suara terenkripsi (WebRTC)...';
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  int _elapsedSeconds = 0;
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  static const Map<String, dynamic> _rtcConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  @override
  void initState() {
    super.initState();
    _initWebRtcCall();
  }

  @override
  void dispose() {
    _cleanupCall(sendHangup: false);
    super.dispose();
  }

  Future<void> _initWebRtcCall() async {
    try {
      // 1. Setup Supabase Realtime Signaling Channel scoped to orderId
      final channelName = 'webrtc:order_${widget.orderId}';
      _signalingChannel = supabase.channel(channelName);

      _signalingChannel!
          .onBroadcast(
            event: 'call-offer',
            callback: (payload) async {
              if (payload['sender_session'] == _sessionId) return;
              await _handleRemoteOffer(payload);
            },
          )
          .onBroadcast(
            event: 'call-answer',
            callback: (payload) async {
              if (payload['sender_session'] == _sessionId) return;
              await _handleRemoteAnswer(payload);
            },
          )
          .onBroadcast(
            event: 'ice-candidate',
            callback: (payload) async {
              if (payload['sender_session'] == _sessionId) return;
              await _handleRemoteCandidate(payload);
            },
          )
          .onBroadcast(
            event: 'call-end',
            callback: (payload) {
              if (payload['sender_session'] == _sessionId) return;
              if (!mounted) return;
              setState(() {
                _callState = 'ended';
                _statusMessage = 'Panggilan diakhiri oleh lawan bicara.';
              });
              _callTimer?.cancel();
            },
          )
          .subscribe();

      // 2. Request audio stream from microphone
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': false,
        });
      } catch (_) {
        // Fallback if running on simulator/desktop without microphone hardware
        _localStream = null;
      }

      // 3. Create PeerConnection
      _peerConnection = await createPeerConnection(_rtcConfiguration);

      if (_localStream != null) {
        for (final track in _localStream!.getAudioTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null) return;
        _signalingChannel?.sendBroadcastMessage(
          event: 'ice-candidate',
          payload: {
            'sender_session': _sessionId,
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        );
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        if (!mounted) return;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _onCallConnected();
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          setState(() {
            _statusMessage =
                'Koneksi VoIP terputus. Gunakan tombol Seluler jika perlu.';
          });
        }
      };

      // 4. Create & broadcast SDP Offer
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await _peerConnection!.setLocalDescription(offer);

      await _signalingChannel!.sendBroadcastMessage(
        event: 'call-offer',
        payload: {
          'sender_session': _sessionId,
          'caller_role': widget.callerRole,
          'sdp': offer.sdp,
          'type': offer.type,
        },
      );

      if (!mounted) return;
      setState(() {
        _callState = 'ringing';
        _statusMessage =
            'Memanggil ${widget.remotePartyName} via In-App VoIP...';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _callState = 'ringing';
        _statusMessage =
            'Saluran In-App siap. Menunggu ${widget.remotePartyName}...';
      });
    }
  }

  Future<void> _handleRemoteOffer(Map<String, dynamic> payload) async {
    final pc = _peerConnection;
    if (pc == null) return;
    final sdp = payload['sdp']?.toString();
    final type = payload['type']?.toString() ?? 'offer';
    if (sdp == null) return;

    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    final answer = await pc.createAnswer({'offerToReceiveAudio': 1});
    await pc.setLocalDescription(answer);

    await _signalingChannel?.sendBroadcastMessage(
      event: 'call-answer',
      payload: {
        'sender_session': _sessionId,
        'sdp': answer.sdp,
        'type': answer.type,
      },
    );
    _onCallConnected();
  }

  Future<void> _handleRemoteAnswer(Map<String, dynamic> payload) async {
    final pc = _peerConnection;
    if (pc == null) return;
    final sdp = payload['sdp']?.toString();
    final type = payload['type']?.toString() ?? 'answer';
    if (sdp == null) return;

    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    _onCallConnected();
  }

  Future<void> _handleRemoteCandidate(Map<String, dynamic> payload) async {
    final pc = _peerConnection;
    if (pc == null) return;
    final candidateStr = payload['candidate']?.toString();
    if (candidateStr == null) return;

    final candidate = RTCIceCandidate(
      candidateStr,
      payload['sdpMid']?.toString(),
      payload['sdpMLineIndex'] is int
          ? payload['sdpMLineIndex'] as int
          : int.tryParse(payload['sdpMLineIndex']?.toString() ?? '0'),
    );
    await pc.addCandidate(candidate);
  }

  void _onCallConnected() {
    if (!mounted) return;
    if (_callState == 'connected') return;
    setState(() {
      _callState = 'connected';
      _statusMessage = 'Terhubung (Suara Terenkripsi DTLS-SRTP)';
    });
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        Helper.setMicrophoneMute(_isMuted, track);
      }
    }
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
    } catch (_) {}
  }

  Future<void> _dialCellularFallback() async {
    final phone = widget.remotePartyPhone.trim().isNotEmpty
        ? widget.remotePartyPhone.trim()
        : '081200001111';
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(uri);
      if (launched) return;
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nomor driver ($phone) disalin ke clipboard.')),
    );
  }

  Future<void> _cleanupCall({bool sendHangup = true}) async {
    _callTimer?.cancel();
    if (sendHangup) {
      try {
        await _signalingChannel?.sendBroadcastMessage(
          event: 'call-end',
          payload: {'sender_session': _sessionId},
        );
      } catch (_) {}
    }
    try {
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await track.stop();
        }
        await _localStream!.dispose();
      }
    } catch (_) {}
    try {
      await _peerConnection?.close();
      await _peerConnection?.dispose();
    } catch (_) {}
    try {
      if (_signalingChannel != null) {
        await supabase.removeChannel(_signalingChannel!);
      }
    } catch (_) {}
  }

  String _formatDuration(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.remotePartyPhone.trim().isNotEmpty
        ? widget.remotePartyPhone.trim()
        : '081200001111';

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Security Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade900.withAlpha(140),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.green.shade600),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 13, color: Colors.greenAccent),
                  SizedBox(width: 5),
                  Text(
                    'In-App VoIP Call • DTLS-SRTP Encrypted',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Avatar Pulse
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.green.shade700,
              child: const Icon(
                Icons.two_wheeler_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 14),

            Text(
              widget.remotePartyName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Order ${widget.orderNumber} • $phone',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),

            Text(
              _callState == 'connected'
                  ? _formatDuration(_elapsedSeconds)
                  : _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _callState == 'connected'
                    ? Colors.greenAccent
                    : Colors.amberAccent,
                fontSize: _callState == 'connected' ? 22 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Call Controls Row (Mute, Speaker, End Call)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallControlButton(
                  icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: _isMuted ? 'Unmute' : 'Mute',
                  active: _isMuted,
                  onTap: _toggleMute,
                ),
                _buildCallControlButton(
                  icon: _isSpeakerOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_down_rounded,
                  label: 'Speaker',
                  active: _isSpeakerOn,
                  onTap: _toggleSpeaker,
                ),
                _buildCallControlButton(
                  icon: Icons.call_end_rounded,
                  label: 'Tutup',
                  active: true,
                  backgroundColor: Colors.red.shade600,
                  onTap: () async {
                    await _cleanupCall(sendHangup: true);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),

            // Fallback Cellular Call for External Biteship Gojek Drivers
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _dialCellularFallback,
                icon: const Icon(
                  Icons.phone_forwarded_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  'Panggil Seluler Reguler ($phone)',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallControlButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    Color? backgroundColor,
  }) {
    final bg =
        backgroundColor ?? (active ? Colors.white : Colors.white.withAlpha(30));
    final fg = backgroundColor != null
        ? Colors.white
        : (active ? Colors.black87 : Colors.white);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: fg, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
