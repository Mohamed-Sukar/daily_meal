import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    try {
      final controller = VideoPlayerController.asset('assets/splash_video.mp4');
      _controller = controller;
      controller.initialize().then((_) {
        if (mounted) {
          setState(() {});
          controller.play();
        }
      }).catchError((_) {
        if (mounted) {
          context.go('/');
        }
      });

      controller.addListener(() {
        if (controller.value.isInitialized &&
            !controller.value.isPlaying &&
            controller.value.position >= controller.value.duration) {
          if (mounted) {
            context.go('/');
          }
        }
      });
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/');
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInitialized = _controller?.value.isInitialized ?? false;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: isInitialized
            ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
