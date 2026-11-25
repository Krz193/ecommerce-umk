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
  String _verifiedCallerRole = '';
  String _verifiedCallerName = '';
  bool _makingOffer = false;
  bool _remoteDescriptionSet = false;
  bool _isCleanedUp = false;
  final List<RTCIceCandidate> _pendingCandidates = [];

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
      // 1. Verify order participation & obtain HMAC-protected channel topic + authoritative role from server
      final authResponse = await supabase.rpc(
        'authorize_order_webrtc_call',
        params: {'p_order_id': widget.orderId},
      );

      if (!mounted || _isCleanedUp) {
        await _cleanupCall(sendHangup: false);
        return;
      }

      if (authResponse is! Map || authResponse['authorized'] != true) {
        throw Exception('Akses panggilan tidak diizinkan untuk akun ini.');
      }

      final channelName = authResponse['channel_topic']?.toString() ?? '';
      final serverRole = authResponse['caller_role']?.toString() ?? '';
      final serverName = authResponse['caller_name']?.toString() ?? '';

      if (channelName.isEmpty || serverRole.isEmpty) {
        throw Exception('Token saluran panggilan tidak valid.');
      }

      _verifiedCallerRole = serverRole;
      _verifiedCallerName = serverName;

      // 2. Setup authorized Supabase Realtime Signaling Channel
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

      // 3. Request audio stream from microphone
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

      if (!mounted || _isCleanedUp) {
        await _cleanupCall(sendHangup: false);
        return;
      }

      // 4. Create PeerConnection (include server-provided TURN/ICE servers if any)
      final serverIceServers = authResponse['ice_servers'];
      final rtcConfig = serverIceServers is List && serverIceServers.isNotEmpty
          ? <String, dynamic>{
              'iceServers': serverIceServers,
              'sdpSemantics': 'unified-plan',
            }
          : _rtcConfiguration;

      _peerConnection = await createPeerConnection(rtcConfig);
      if (!mounted || _isCleanedUp) {
        await _cleanupCall(sendHangup: false);
        return;
      }

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'audio') {
          event.track.enabled = true;
          Helper.setSpeakerphoneOn(_isSpeakerOn).catchError((_) {});
        }
      };

      if (_localStream != null) {
        for (final track in _localStream!.getAudioTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
          if (!mounted || _isCleanedUp) {
            await _cleanupCall(sendHangup: false);
            return;
          }
        }
      }

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null) return;
        _signalingChannel?.sendBroadcastMessage(
          event: 'ice-candidate',
          payload: {
            'sender_session': _sessionId,
            'caller_role': _verifiedCallerRole,
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

      // 5. Create & broadcast SDP Offer using server-verified role
      _makingOffer = true;
      try {
        final offer = await _peerConnection!.createOffer({
          'offerToReceiveAudio': 1,
          'offerToReceiveVideo': 0,
        });
        if (!mounted || _isCleanedUp) {
          await _cleanupCall(sendHangup: false);
          return;
        }
        await _peerConnection!.setLocalDescription(offer);
        if (!mounted || _isCleanedUp) {
          await _cleanupCall(sendHangup: false);
          return;
        }

        await _signalingChannel!.sendBroadcastMessage(
          event: 'call-offer',
          payload: {
            'sender_session': _sessionId,
            'caller_role': _verifiedCallerRole,
            'caller_name': _verifiedCallerName,
            'sdp': offer.sdp,
            'type': offer.type,
          },
        );
      } finally {
        _makingOffer = false;
      }

      if (!mounted) return;
      setState(() {
        _callState = 'ringing';
        _statusMessage =
            'Memanggil ${widget.remotePartyName} via In-App VoIP...';
      });
    } catch (e) {
      await _cleanupCall(sendHangup: false);
      if (!mounted) return;
      final cleanMsg = e.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _callState = 'ended';
        _statusMessage = cleanMsg.isNotEmpty
            ? cleanMsg
            : 'Gagal mengotorisasi saluran panggilan pesanan ini.';
      });
    }
  }

  Future<void> _flushPendingCandidates(RTCPeerConnection pc) async {
    if (_pendingCandidates.isEmpty) return;
    final candidates = List<RTCIceCandidate>.from(_pendingCandidates);
    _pendingCandidates.clear();
    for (final candidate in candidates) {
      try {
        await pc.addCandidate(candidate);
      } catch (_) {}
    }
  }

  Future<void> _handleRemoteOffer(Map<String, dynamic> payload) async {
    final pc = _peerConnection;
    if (pc == null || _isCleanedUp) return;
    final sdp = payload['sdp']?.toString();
    final type = payload['type']?.toString() ?? 'offer';
    if (sdp == null) return;

    final remoteSession = payload['sender_session']?.toString() ?? '';
    final isPolite = _sessionId.compareTo(remoteSession) < 0;
    final signalingState = await pc.getSignalingState();
    final offerCollision =
        _makingOffer ||
        (signalingState != null &&
            signalingState != RTCSignalingState.RTCSignalingStateStable);

    if (offerCollision && !isPolite) {
      return;
    }

    if (offerCollision && isPolite) {
      try {
        await pc.setLocalDescription(RTCSessionDescription('', 'rollback'));
      } catch (_) {}
    }

    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteDescriptionSet = true;
    await _flushPendingCandidates(pc);

    if (_isCleanedUp || !mounted) return;
    final answer = await pc.createAnswer({'offerToReceiveAudio': 1});
    await pc.setLocalDescription(answer);

    await _signalingChannel?.sendBroadcastMessage(
      event: 'call-answer',
      payload: {
        'sender_session': _sessionId,
        'caller_role': _verifiedCallerRole,
        'caller_name': _verifiedCallerName,
        'sdp': answer.sdp,
        'type': answer.type,
      },
    );
    _onCallConnected();
  }

  Future<void> _handleRemoteAnswer(Map<String, dynamic> payload) async {
    final pc = _peerConnection;
    if (pc == null || _isCleanedUp) return;
    final sdp = payload['sdp']?.toString();
    final type = payload['type']?.toString() ?? 'answer';
    if (sdp == null) return;

    final signalingState = await pc.getSignalingState();
    if (signalingState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
      return;
    }

    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteDescriptionSet = true;
    await _flushPendingCandidates(pc);
    _onCallConnected();
  }

  Future<void> _handleRemoteCandidate(Map<String, dynamic> payload) async {
    final pc = _peerConnection;
    if (pc == null || _isCleanedUp) return;
    final candidateStr = payload['candidate']?.toString();
    if (candidateStr == null) return;

    final candidate = RTCIceCandidate(
      candidateStr,
      payload['sdpMid']?.toString(),
      payload['sdpMLineIndex'] is int
          ? payload['sdpMLineIndex'] as int
          : int.tryParse(payload['sdpMLineIndex']?.toString() ?? '0'),
    );

    if (!_remoteDescriptionSet) {
      _pendingCandidates.add(candidate);
      return;
    }
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
    final phone = widget.remotePartyPhone.trim();
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon seluler pihak terkait belum tersedia.'),
        ),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(uri);
      if (launched) return;
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nomor telepon ($phone) disalin ke clipboard.')),
    );
  }

  Future<void> _cleanupCall({bool sendHangup = true}) async {
    if (_isCleanedUp) return;
    _isCleanedUp = true;
    _callTimer?.cancel();
    _pendingCandidates.clear();

    final channel = _signalingChannel;
    _signalingChannel = null;
    if (sendHangup && channel != null) {
      try {
        await channel.sendBroadcastMessage(
          event: 'call-end',
          payload: {'sender_session': _sessionId},
        );
      } catch (_) {}
    }

    final stream = _localStream;
    _localStream = null;
    try {
      if (stream != null) {
        for (final track in stream.getTracks()) {
          await track.stop();
        }
        await stream.dispose();
      }
    } catch (_) {}

    final pc = _peerConnection;
    _peerConnection = null;
    try {
      await pc?.close();
      await pc?.dispose();
    } catch (_) {}

    try {
      if (channel != null) {
        await supabase.removeChannel(channel);
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
    final phone = widget.remotePartyPhone.trim();
    final hasPhone = phone.isNotEmpty;

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
              hasPhone
                  ? 'Order ${widget.orderNumber} • $phone'
                  : 'Order ${widget.orderNumber}',
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

            if (hasPhone) ...[
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),

              // Fallback Cellular Call when real phone number is available
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
