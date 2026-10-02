import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/ad_service.dart';

/// Production-ready, lifecycle-managed AdMob Banner widget.
///
/// Guarantees:
/// - Exact 1:1 ownership of BannerAd.
/// - Never reuses a disposed BannerAd.
/// - Concurrency locked to prevent duplicate in-flight requests.
/// - Authoritative callback logging for impressions, clicks, opens, and closes.
/// - Resilient to app pause/resume and rebuilds.
class AdBanner extends StatefulWidget {
  final String? adUnitId;
  const AdBanner({super.key, this.adUnitId});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> with WidgetsBindingObserver {
  late final String _instanceId;
  BannerAd? _bannerAd;
  bool _isLoading = false;
  bool _isLoaded = false;
  bool _isDisposed = false;
  bool _hasLoggedMounted = false;

  @override
  void initState() {
    super.initState();
    _instanceId = AdService.instance.generateInstanceId();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoading && !_isLoaded && _bannerAd == null && !_isDisposed) {
      _loadAd();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AdService.instance.log('PAUSED (App in background / ad open)', _instanceId);
    } else if (state == AppLifecycleState.resumed) {
      AdService.instance.log('RESUMED (App back to foreground)', _instanceId);
    }
  }

  Future<void> _loadAd() async {
    if (kIsWeb) return;
    if (_isLoading || _isLoaded || _isDisposed) return;
    _isLoading = true;

    try {
      // 1. Ensure AdMob SDK is initialized before requesting an ad
      await AdService.instance.init();
      if (!mounted || _isDisposed) {
        _isLoading = false;
        return;
      }

      // 2. Compute current orientation anchored adaptive size
      final width = MediaQuery.sizeOf(context).width.truncate();
      if (width <= 0) {
        _isLoading = false;
        return;
      }

      final AnchoredAdaptiveBannerAdSize? size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

      if (!mounted || _isDisposed) {
        _isLoading = false;
        return;
      }

      if (size == null) {
        _isLoading = false;
        AdService.instance.log('FAILED', _instanceId, 'Could not get adaptive size for width $width');
        return;
      }

      final targetAdUnitId = widget.adUnitId ?? AdService.instance.bannerAdUnitId;

      // 3. Instantiate BannerAd with full lifecycle listener
      final banner = BannerAd(
        adUnitId: targetAdUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad ad) {
            final loadedBanner = ad as BannerAd;
            AdService.instance.log(
              'LOADED',
              _instanceId,
              'Size: ${loadedBanner.size.width}x${loadedBanner.size.height}',
            );
            if (!mounted || _isDisposed) {
              loadedBanner.dispose();
              return;
            }
            setState(() {
              _bannerAd = loadedBanner;
              _isLoaded = true;
              _isLoading = false;
            });
          },
          onAdImpression: (Ad ad) {
            // Authoritative SDK impression callback
            AdService.instance.log('IMPRESSION', _instanceId);
          },
          onAdClicked: (Ad ad) {
            AdService.instance.log('CLICKED', _instanceId);
          },
          onAdOpened: (Ad ad) {
            AdService.instance.log('OPENED', _instanceId);
          },
          onAdClosed: (Ad ad) {
            AdService.instance.log('CLOSED', _instanceId);
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) {
            AdService.instance.log(
              'FAILED',
              _instanceId,
              'Code: ${error.code}, Message: ${error.message}',
            );
            ad.dispose();
            if (mounted) {
              setState(() {
                _bannerAd = null;
                _isLoaded = false;
                _isLoading = false;
              });
            } else {
              _bannerAd = null;
              _isLoaded = false;
              _isLoading = false;
            }
          },
        ),
      );

      _bannerAd = banner;
      AdService.instance.log('REQUEST', _instanceId, 'Unit: $targetAdUnitId, Width: $width');
      await banner.load();
    } catch (e) {
      AdService.instance.log('FAILED', _instanceId, 'Exception during load: $e');
      _isLoading = false;
      _bannerAd?.dispose();
      _bannerAd = null;
      if (mounted) {
        setState(() => _isLoaded = false);
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    AdService.instance.log('DISPOSED', _instanceId);
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
    _isLoading = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerAd != null && _isLoaded) {
      if (!_hasLoggedMounted) {
        _hasLoggedMounted = true;
        AdService.instance.log('MOUNTED', _instanceId);
      }
      return Container(
        color: Colors.transparent,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink();
  }
}
