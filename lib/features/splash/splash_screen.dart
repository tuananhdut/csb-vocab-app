import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// FR-1 — Splash screen chủ đề Cảnh sát biển Việt Nam.
///
/// Dùng ảnh thật Cảnh sát biển ở `assets/images/coast_guard/` (xem
/// `docs/spec_history.md` [IMPL-009]). Sau [AppConstants.splashDuration]
/// tự chuyển vào màn chính.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  static const _slides = <(_SlideStyle, String, String, String)>[
    (
      _SlideStyle.navy,
      'assets/images/coast_guard/csb-slide-01.jpg',
      'Cảnh Sát Biển\nViệt Nam',
      'Vì chủ quyền biển đảo',
    ),
    (
      _SlideStyle.sea,
      'assets/images/coast_guard/csb-slide-02.jpg',
      'Học Từ Vựng',
      'Tiếng Anh — offline',
    ),
    (
      _SlideStyle.gold,
      'assets/images/coast_guard/csb-slide-03.jpg',
      'Tra cứu · Học · Ôn tập',
      'Mọi lúc, không cần mạng',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer(AppConstants.splashDuration, _goHome);
  }

  void _goHome() {
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDark,
      body: Stack(
        children: [
          CarouselSlider(
            options: CarouselOptions(
              height: double.infinity,
              viewportFraction: 1,
              autoPlay: true,
              autoPlayInterval: AppConstants.splashSlideInterval,
              autoPlayAnimationDuration: const Duration(milliseconds: 600),
            ),
            items: _slides.map(_buildSlide).toList(),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: TextButton(
              onPressed: _goHome,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Bỏ qua ➜'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide((_SlideStyle, String, String, String) slide) {
    final (style, imagePath, title, subtitle) = slide;
    final colors = switch (style) {
      _SlideStyle.navy => [AppColors.navy, AppColors.navyDark],
      _SlideStyle.sea => [AppColors.seaBlue, AppColors.navy],
      _SlideStyle.gold => [AppColors.navy, AppColors.gold],
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(Icons.anchor, size: 96, color: Colors.white),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.last.withValues(alpha: 0.75), Colors.transparent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 96, left: 24, right: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _SlideStyle { navy, sea, gold }
