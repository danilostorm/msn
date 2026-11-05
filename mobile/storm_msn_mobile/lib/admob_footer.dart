import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Banner nativo AdMob. Sem HTML e sem código AdSense.
/// O ID de teste oficial aparece até que se forneça uma unidade AdMob real.
class StormAdMobBanner extends StatefulWidget {
  const StormAdMobBanner({super.key});
  @override
  State<StormAdMobBanner> createState() => _StormAdMobBannerState();
}

class _StormAdMobBannerState extends State<StormAdMobBanner> {
  static const _adUnitId = String.fromEnvironment(
    'STORM_ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || !Platform.isAndroid) return;
    _load();
  }

  Future<void> _load() async {
    try {
      await MobileAds.instance.initialize();
      if (!mounted) return;
      final banner = BannerAd(
        size: AdSize.banner,
        adUnitId: _adUnitId,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) return;
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (mounted) {
              setState(() {
                _ad = null;
                _loaded = false;
              });
            }
          },
        ),
      );
      _ad = banner;
      await banner.load();
    } catch (_) {
      if (mounted) setState(() => _loaded = false);
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: Text(
            'Publicidade',
            style: TextStyle(color: Color(0xff8bafbf), fontSize: 10),
          ),
        ),
      );
    }
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
