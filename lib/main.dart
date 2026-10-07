import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // পোর্ট্রেট মোড লক করা
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // স্ট্যাটাস বার ও নেভিগেশন বার কালার সেট করা
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xFF00695B),
    statusBarColor: Color(0xFF00695B),
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  await _requestLocationPermission();

  runApp(const MyApp());
}

Future<void> _requestLocationPermission() async {
  var status = await Permission.location.status;
  if (!status.isGranted) {
    await Permission.location.request();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dua After Salah',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF00695B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const WebViewApp(),
    );
  }
}

class WebViewApp extends StatefulWidget {
  const WebViewApp({super.key});

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  InAppWebViewController? webViewController;

  static const platform = MethodChannel('com.muhammadfazal.dua_after_salah/volume_buttons');

  Timer? _loadTimeoutTimer;
  bool _isOfflineFallbackDone = false;

  final String _onlineUrl = "https://das.muhammadfazal.com";

  @override
  void initState() {
    super.initState();

    // Listen for volume button events from native MethodChannel
    platform.setMethodCallHandler((call) async {
      if (call.method == "onVolumeUp") {
        _incrementTasbih();
      } else if (call.method == "onVolumeDown") {
        _decrementTasbih();
      }
    });

    // Register Flutter hardware keyboard handler as fallback
    ServicesBinding.instance.keyboard.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    ServicesBinding.instance.keyboard.removeHandler(_onKeyEvent);
    _cancelTimeoutTimer();
    super.dispose();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
        _incrementTasbih();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
        _decrementTasbih();
        return true;
      }
    }
    return false;
  }

  void _incrementTasbih() {
    webViewController?.evaluateJavascript(
      source: """
        if (typeof incrementTasbih === 'function') {
          incrementTasbih();
        } else if (typeof window.incrementTasbih === 'function') {
          window.incrementTasbih();
        }
      """,
    );
  }

  void _decrementTasbih() {
    webViewController?.evaluateJavascript(
      source: """
        if (typeof decrementTasbih === 'function') {
          decrementTasbih();
        } else if (typeof window.decrementTasbih === 'function') {
          window.decrementTasbih();
        }
      """,
    );
  }

  void _startLoadTimeoutTimer() {
    _cancelTimeoutTimer();
    _loadTimeoutTimer = Timer(const Duration(milliseconds: 3500), () {
      _fallbackToOffline();
    });
  }

  void _cancelTimeoutTimer() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = null;
  }

  void _fallbackToOffline() async {
    _cancelTimeoutTimer();
    if (_isOfflineFallbackDone) return;
    _isOfflineFallbackDone = true;

    if (webViewController != null) {
      try {
        await webViewController!.stopLoading();
      } catch (_) {}

      // Fallback directly to cached offline content inside the WebView
      await webViewController!.setSettings(
        settings: InAppWebViewSettings(
          cacheMode: CacheMode.LOAD_CACHE_ONLY,
        ),
      );

      await webViewController!.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(_onlineUrl),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF00695B),
      body: SafeArea(
        // bottom: true (ডিফল্ট) থাকায় নেভিগেশন বারের উপরে থাকবে
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(_onlineUrl),
          ),
          initialUserScripts: UnmodifiableListView<UserScript>([
            // স্ক্রলবার হাইড করার পাশাপাশি জুম বন্ধ করার জন্য মেটা ট্যাগ ইনজেকশন
            UserScript(
                source: """
                  var style = document.createElement('style');
                  style.innerHTML = '::-webkit-scrollbar { display: none !important; } body { overflow: -moz-scrollbars-none; -ms-overflow-style: none; }';
                  document.head.appendChild(style);
                  
                  var meta = document.createElement('meta');
                  meta.name = 'viewport';
                  meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                  document.getElementsByTagName('head')[0].appendChild(meta);
                """,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
          ]),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            transparentBackground: true,
            verticalScrollBarEnabled: false,
            horizontalScrollBarEnabled: false,
            geolocationEnabled: true,
            useShouldOverrideUrlLoading: true,
            mediaPlaybackRequiresUserGesture: false,

            // জুম পুরোপুরি বন্ধ করার সেটিংস
            supportZoom: false,
            builtInZoomControls: false,
            displayZoomControls: false,

            useHybridComposition: true,
            allowsInlineMediaPlayback: true,

            // অফলাইন ও ক্যাশ সেটিংস
            cacheEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            cacheMode: CacheMode.LOAD_DEFAULT,
          ),
          onWebViewCreated: (controller) {
            webViewController = controller;
            _startLoadTimeoutTimer();
          },
          onLoadStart: (controller, url) {
            if (!_isOfflineFallbackDone) {
              _startLoadTimeoutTimer();
            }
          },
          onLoadStop: (controller, url) {
            _cancelTimeoutTimer();
          },
          onReceivedError: (controller, request, error) {
            if (request.isForMainFrame ?? true) {
              _fallbackToOffline();
            }
          },
          onReceivedHttpError: (controller, request, errorResponse) {
            if (request.isForMainFrame ?? true) {
              if ((errorResponse.statusCode ?? 0) >= 400) {
                _fallbackToOffline();
              }
            }
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            var uri = navigationAction.request.url!;
            if (!["http", "https", "file", "chrome", "data", "javascript", "about"].contains(uri.scheme)) {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
                return NavigationActionPolicy.CANCEL;
              }
            }
            return NavigationActionPolicy.ALLOW;
          },
          onGeolocationPermissionsShowPrompt: (controller, origin) async {
            return GeolocationPermissionShowPromptResponse(
              origin: origin,
              allow: true,
              retain: true,
            );
          },
        ),
      ),
    );
  }
}
