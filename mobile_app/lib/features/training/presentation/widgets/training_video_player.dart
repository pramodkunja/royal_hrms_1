import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/training_models.dart';

/// Web MaterialViewer.tsx HEARTBEAT_MS: playback reports at most every 10 s,
/// plus forced reports on play / pause / end.
const kTrainingHeartbeatInterval = Duration(seconds: 10);

/// Web useHeartbeat. Throttles playback reports; [send] failures are
/// ignored (the next report carries the position anyway). The server does
/// its own checks (real-time rate, 2 s minimum gap, 90% of the HR-set
/// length) — this only avoids flooding it.
class TrainingHeartbeat {
  TrainingHeartbeat({required this.send, DateTime Function()? clock, this.interval = kTrainingHeartbeatInterval})
      : _clock = clock ?? DateTime.now;

  final Future<void> Function(double position, double? duration) send;
  final DateTime Function() _clock;
  final Duration interval;
  DateTime? _last;

  void beat(double position, double? duration, {bool force = false}) {
    final now = _clock();
    if (!force && _last != null && now.difference(_last!) < interval) return;
    _last = now;
    final d = duration != null && duration.isFinite && duration > 0 ? duration : null;
    final p = position.isFinite && position > 0 ? position : 0.0;
    unawaited(send(p, d).catchError((_) {}));
  }
}

/// What the player reports to the screen.
typedef TrainingBeat = void Function(double position, double? duration, {bool force});

/// Builds the player for one material. A provider so widget tests can use a
/// fake player (a real WebView needs the platform).
typedef TrainingVideoPlayerBuilder = Widget Function({
  required TrainingMaterial material,
  required String? sourceUrl,
  required TrainingBeat onBeat,
  required ValueChanged<String> onError,
});

final trainingVideoPlayerBuilderProvider = Provider<TrainingVideoPlayerBuilder>(
  (ref) => ({required material, required sourceUrl, required onBeat, required onError}) => TrainingWebVideoPlayer(
        material: material,
        sourceUrl: sourceUrl,
        onBeat: onBeat,
        onError: onError,
      ),
);

final _ytId = RegExp(r'^[A-Za-z0-9_-]{11}$');
final _vimeoId = RegExp(r'^\d+$');

/// The kind of player a material needs (web MaterialViewer branches).
enum TrainingPlayerKind { youtube, vimeo, html5, none }

TrainingPlayerKind trainingPlayerKind(TrainingMaterial m) {
  if (m.isUploadedVideo) return TrainingPlayerKind.html5;
  if (!m.isExternal) return TrainingPlayerKind.none;
  return switch (m.provider) {
    'youtube' => TrainingPlayerKind.youtube,
    'vimeo' => TrainingPlayerKind.vimeo,
    'direct' => TrainingPlayerKind.html5,
    _ => TrainingPlayerKind.none,
  };
}

/// The page the WebView shows, or null when the material can't be played
/// safely (bad id, non-https source). Every value from the API goes into the
/// page only as a JSON string literal inside the script — never as raw HTML.
/// Messages back to the app: {"t":"beat","p":pos,"d":dur,"f":true|false}
/// and {"t":"error","m":text}.
String? trainingPlayerHtml(TrainingMaterial m, {String? sourceUrl}) {
  final kind = trainingPlayerKind(m);
  const head = '<!doctype html><html><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '<style>html,body{margin:0;background:#000;height:100%;overflow:hidden}'
      '#p,video,iframe{position:absolute;inset:0;width:100%;height:100%;border:0}</style></head><body>';
  const post = 'function post(o){try{RoyalTraining.postMessage(JSON.stringify(o));}catch(e){}}';
  switch (kind) {
    case TrainingPlayerKind.youtube:
      if (!_ytId.hasMatch(m.embedId)) return null;
      final id = jsonEncode(m.embedId);
      return '$head<div id="p"></div><script>$post'
          'var player=null,timer=null;'
          'function beat(f){if(!player)return;post({t:"beat",p:player.getCurrentTime(),d:player.getDuration(),f:f});}'
          'window.onYouTubeIframeAPIReady=function(){player=new YT.Player("p",{host:"https://www.youtube-nocookie.com",'
          'videoId:$id,width:"100%",height:"100%",playerVars:{rel:0,modestbranding:1,playsinline:1},'
          'events:{onStateChange:function(ev){if(ev.data===YT.PlayerState.PLAYING){beat(true);'
          'if(!timer)timer=setInterval(function(){beat(false);},2000);}else{if(timer){clearInterval(timer);timer=null;}'
          'if(ev.data===YT.PlayerState.PAUSED||ev.data===YT.PlayerState.ENDED)beat(true);}},'
          'onError:function(){post({t:"error",m:"This video can\'t be played here (it may not allow embedding)."});}}});};'
          'var s=document.createElement("script");s.src="https://www.youtube.com/iframe_api";'
          's.onerror=function(){post({t:"error",m:"The YouTube player could not load."});};'
          'document.head.appendChild(s);</script></body></html>';
    case TrainingPlayerKind.vimeo:
      if (!_vimeoId.hasMatch(m.embedId)) return null;
      // Vimeo playback is not tracked (backend is_tracked false): embed only.
      return '$head<iframe id="v" allow="fullscreen; picture-in-picture" allowfullscreen '
          'referrerpolicy="strict-origin-when-cross-origin"></iframe><script>'
          'document.getElementById("v").src="https://player.vimeo.com/video/"+${jsonEncode(m.embedId)};</script>'
          '</body></html>';
    case TrainingPlayerKind.html5:
      final src = sourceUrl ?? (m.isExternal ? m.externalUrl : null);
      final uri = src == null ? null : Uri.tryParse(src);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
      return '$head<video id="v" controls controlslist="nodownload" preload="metadata" playsinline></video><script>$post'
          'var v=document.getElementById("v");'
          'function beat(f){post({t:"beat",p:v.currentTime,d:v.duration,f:f});}'
          'v.addEventListener("play",function(){beat(true);});'
          'v.addEventListener("timeupdate",function(){beat(false);});'
          'v.addEventListener("pause",function(){beat(true);});'
          'v.addEventListener("ended",function(){beat(true);});'
          'v.addEventListener("error",function(){post({t:"error",m:"This video could not be played."});});'
          'v.addEventListener("contextmenu",function(e){e.preventDefault();});'
          'v.src=${jsonEncode(uri.toString())};</script></body></html>';
    case TrainingPlayerKind.none:
      return null;
  }
}

/// Parses one player message; null when it isn't one we expect.
({String type, double position, double? duration, bool force, String message})? parseTrainingPlayerMessage(String raw) {
  try {
    final o = jsonDecode(raw);
    if (o is! Map) return null;
    if (o['t'] == 'beat') {
      final p = o['p'], d = o['d'];
      return (
        type: 'beat',
        position: p is num ? p.toDouble() : 0,
        duration: d is num ? d.toDouble() : null,
        force: o['f'] == true,
        message: '',
      );
    }
    if (o['t'] == 'error') {
      return (type: 'error', position: 0, duration: null, force: false, message: '${o['m'] ?? ''}');
    }
  } catch (_) {}
  return null;
}

/// The top-level page may only be the player page itself (the origin root
/// it was loaded under, or about:blank) — e.g. tapping the YouTube logo must
/// not turn the player into a browser.
bool trainingPlayerAllowsTopLevel(String url, String origin) {
  if (url == 'about:blank') return true;
  final u = Uri.tryParse(url);
  return u != null && u.hasScheme && u.origin == origin && (u.path.isEmpty || u.path == '/') && !u.hasQuery;
}

/// The page is loaded under the web app's own origin (from ApiConfig), as
/// the web player runs there; YouTube's embed needs a real origin.
String trainingPlayerOrigin() {
  final u = Uri.tryParse(ApiConfig.baseUrl);
  return u == null || u.host.isEmpty ? 'https://royalhrms.com' : u.origin;
}

/// The real player: a WebView running web's own player code. Only the
/// player page and its embedded frames load — any attempt to navigate the
/// page elsewhere is blocked. Nothing is downloaded to device storage.
class TrainingWebVideoPlayer extends StatefulWidget {
  const TrainingWebVideoPlayer({
    super.key,
    required this.material,
    required this.sourceUrl,
    required this.onBeat,
    required this.onError,
  });

  final TrainingMaterial material;
  final String? sourceUrl;
  final TrainingBeat onBeat;
  final ValueChanged<String> onError;

  @override
  State<TrainingWebVideoPlayer> createState() => _TrainingWebVideoPlayerState();
}

class _TrainingWebVideoPlayerState extends State<TrainingWebVideoPlayer> {
  WebViewController? _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final html = trainingPlayerHtml(widget.material, sourceUrl: widget.sourceUrl);
    if (html == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onError('This video could not be played.'));
      return;
    }
    final origin = trainingPlayerOrigin();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('RoyalTraining', onMessageReceived: (msg) {
        final m = parseTrainingPlayerMessage(msg.message);
        if (m == null || !mounted) return;
        if (m.type == 'beat') {
          widget.onBeat(m.position, m.duration, force: m.force);
        } else {
          widget.onError(m.message.isEmpty ? 'This video could not be played.' : m.message);
        }
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onNavigationRequest: (req) {
          // Embedded frames (YouTube / Vimeo players) load normally; the top
          // page itself may only load once (our HTML).
          if (!req.isMainFrame) return NavigationDecision.navigate;
          return trainingPlayerAllowsTopLevel(req.url, origin)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ))
      ..loadHtmlString(html, baseUrl: origin);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: Colors.black,
          child: c == null
              ? const SizedBox.shrink()
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    WebViewWidget(controller: c),
                    if (!_loaded)
                      Center(
                        child: Semantics(
                          label: 'Loading video',
                          child: CircularProgressIndicator(color: AppColors.surface),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
