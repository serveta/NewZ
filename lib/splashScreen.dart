import 'package:flutter/material.dart';
import 'dart:async';
import 'package:newz/widget_tree.dart'; // WidgetTree import edilmeli

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Animasyon denetleyicisini oluşturuyoruz
    _animationController = AnimationController(
      duration: const Duration(seconds: 7), // 2 saniyelik animasyon
      vsync: this,
    );

    // Fade ve Scale Animasyonları tanımlanıyor
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 2.0).animate(_animationController);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Animasyonu başlat
    _animationController.forward();

    // 3 saniye sonra WidgetTree sayfasına geçiş yap
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WidgetTree()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose(); // Bellek yönetimi için controller'ı temizle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          // Fade animasyonu
          opacity: _fadeAnimation,
          child: ScaleTransition(
            // Ölçek animasyonu
            scale: _scaleAnimation,
            child: RichText(
              text: const TextSpan(
                text: 'New',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: 'Z',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
