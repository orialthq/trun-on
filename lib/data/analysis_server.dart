import 'dart:io';

/// Where the analysis server lives, for every service that talks to it.
///
/// A build can name the server with `--dart-define=ORI_ANALYSIS_BASE_URL=...`,
/// and a build headed for a phone has to: nothing on the device can guess which
/// machine on the Wi-Fi is running the server. `docs/IOS_TEAMMATE_GUIDE.md`
/// gives the `.local` form to use, which survives the router reassigning an IP.
///
/// Without one, fall back to whatever "this developer's own machine" means on
/// the platform in hand. The Android emulator reserves 10.0.2.2 for its host;
/// the iOS simulator and a desktop run reach the host over loopback. The single
/// 10.0.2.2 default this replaces was right only on the emulator and resolved
/// nowhere else — and because an unreachable server falls back to on-device
/// analysis rather than raising, every other target failed quietly.
String defaultAnalysisBaseUrl() {
  if (_configured.isNotEmpty) return _configured;
  return Platform.isAndroid ? 'http://10.0.2.2:8787' : 'http://127.0.0.1:8787';
}

const _configured = String.fromEnvironment('ORI_ANALYSIS_BASE_URL');
