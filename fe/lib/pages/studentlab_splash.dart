import 'package:flutter/material.dart';

class StudentLabSplash extends StatefulWidget {
  const StudentLabSplash({
    super.key,
  });

  @override
  State<StudentLabSplash> createState() => _StudentLabSplashState();
}

class _StudentLabSplashState extends State<StudentLabSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1800,
      ),
    )..repeat(
        reverse: true,
      );

    _scaleAnimation = Tween<double>(
      begin: 0.98,
      end: 1.02,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _floatAnimation = Tween<double>(
      begin: 0,
      end: -8,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF03081A,
      ),

      body: SafeArea(
        child: Stack(
          children: [

            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(
                        -0.15,
                        0,
                      ),
                      radius: 0.9,
                      colors: [
                        const Color(
                          0xFF00D9FF,
                        ).withValues(
                          alpha: 0.10,
                        ),
                        const Color(
                          0xFF6C3BFF,
                        ).withValues(
                          alpha: 0.06,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Align(
              alignment: const Alignment(
                0,
                -0.08,
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (
                  context,
                  child,
                ) {
                  return Transform.translate(
                    offset: Offset(
                      0,
                      _floatAnimation.value,
                    ),
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  'assets/mascot/studentlab_wolf.png',
                  width: MediaQuery.sizeOf(context).width * 0.78,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 52,

              child: Center(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                    children: [
                      TextSpan(
                        text: 'Student',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),

                      TextSpan(
                        text: 'Lab',
                        style: TextStyle(
                          color: Color(
                            0xFF8A4DFF,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}