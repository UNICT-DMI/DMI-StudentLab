import 'package:flutter/material.dart';
import 'package:fe/theme/nightTheme.dart';

import '../theme/studentlab_brand.dart';

class StudentLabWolfSplash extends StatelessWidget {
  final double size;

  const StudentLabWolfSplash({
    super.key,
    this.size = 320,
  });

  @override
  Widget build(BuildContext context) {
    final double titleSize =
        (size * 0.105).clamp(
      26.0,
      38.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            StudentLabBrand.wolf,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(
          height: 14,
        ),
        _StudentLabTitle(
          fontSize: titleSize,
        ),
      ],
    );
  }
}

class _StudentLabTitle extends StatefulWidget {
  final double fontSize;

  const _StudentLabTitle({
    required this.fontSize,
  });

  @override
  State<_StudentLabTitle> createState() =>
      _StudentLabTitleState();
}

class _StudentLabTitleState
    extends State<_StudentLabTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _glowBlur;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _glowSpread;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1800,
      ),
    );

    final CurvedAnimation curved =
        CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _glowBlur = Tween<double>(
      begin: 5,
      end: 18,
    ).animate(curved);

    _glowOpacity = Tween<double>(
      begin: 0.18,
      end: 0.55,
    ).animate(curved);

    _glowSpread = Tween<double>(
      begin: 0,
      end: 2,
    ).animate(curved);

    _controller.repeat(
      reverse: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (
        context,
        child,
      ) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              18,
            ),
            boxShadow: [
              BoxShadow(
                color: StudentLabBrand.glow[0].withValues(
                  alpha: _glowOpacity.value * 0.65,
                ),
                blurRadius: _glowBlur.value,
                spreadRadius: _glowSpread.value,
              ),
              BoxShadow(
                color: StudentLabBrand.glow[1].withValues(
                  alpha: _glowOpacity.value * 0.45,
                ),
                blurRadius: _glowBlur.value * 1.35,
                spreadRadius: _glowSpread.value * 0.6,
              ),
            ],
          ),
          child: _buildTitle(),
        );
      },
    );
  }

  Widget _buildTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (
            bounds,
          ) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: StudentLabBrand.studentGradient,
            ).createShader(
              bounds,
            );
          },
          child: Text(
            'Student',
            style: TextStyle(
              color: AppColors.white,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              height: 1,
            ),
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (
            bounds,
          ) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: StudentLabBrand.labGradient,
              stops: const [
                0.0,
                0.35,
                0.68,
                1.0,
              ],
            ).createShader(
              bounds,
            );
          },
          child: Text(
            'Lab',
            style: TextStyle(
              color: AppColors.white,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}