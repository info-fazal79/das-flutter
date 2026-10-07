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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF00695B),
      body: SafeArea(
        // bottom: true (ডিফল্ট) থাকায় নেভিগেশন বারের উপরে থাকবে
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri("https://das.muhammadfazal.com"),
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
          ),
          onWebViewCreated: (controller) {
            webViewController = controller;
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