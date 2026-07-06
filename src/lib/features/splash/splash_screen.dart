import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// FR-1 — Splash screen chủ đề Cảnh sát biển Việt Nam.
///
/// Hiện tại dùng 3–5 slide placeholder tự dựng (đã chốt C1); sẽ thay bằng
/// bộ ảnh chính thức khi khách cung cấp. Sau [AppConstants.splashDuration]
/// tự chuyển vào màn chính.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  /// Slide placeholder — thay bằng ảnh thật ở assets/images/coast_guard/.
  static const _slides = <(_SlideStyle, String, String)>[
    (_SlideStyle.navy, 'Cảnh Sát Biển\nViệt Nam', 'Vì chủ quyền biển đảo'),
    (_SlideStyle.sea, 'Học Từ Vựng', 'Tiếng Anh — offline'),
    (_SlideStyle.gold, 'Tra cứu · Học · Ôn tập', 'Mọi lúc, không cần mạng'),
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

  Widget _buildSlide((_SlideStyle, String, String) slide) {
    final (style, title, subtitle) = slide;
    final colors = switch (style) {
      _SlideStyle.navy => [AppColors.navy, AppColors.navyDark],
      _SlideStyle.sea => [AppColors.seaBlue, AppColors.navy],
      _SlideStyle.gold => [AppColors.navy, AppColors.gold],
    };
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.anchor, size: 96, color: Colors.white),
          const SizedBox(height: 24),
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
    );
  }
}

enum _SlideStyle { navy, sea, gold }
