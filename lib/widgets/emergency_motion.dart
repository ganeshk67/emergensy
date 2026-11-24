import 'package:flutter/material.dart';

/// A prominent, explicitly non-dispatching SOS preparation action.
class EmergencySosButton extends StatefulWidget {
  const EmergencySosButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  State<EmergencySosButton> createState() => _EmergencySosButtonState();
}

class _EmergencySosButtonState extends State<EmergencySosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      label: 'Prepare SOS details. This does not contact emergency services.',
      child: SizedBox(
        width: 148,
        height: 148,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final phase = reduceMotion ? 0.0 : _controller.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                for (var ring = 0; ring < 2; ring++)
                  Container(
                    width: 112 + ring * 16 + phase * 14,
                    height: 112 + ring * 16 + phase * 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.error.withValues(
                          alpha: (1 - phase) * (ring == 0 ? .19 : .11),
                        ),
                        width: 1.3,
                      ),
                    ),
                  ),
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: widget.onPressed,
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(colors.error, Colors.white, .12)!,
                            colors.error,
                            Color.lerp(colors.error, Colors.black, .15)!,
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .26),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.error.withValues(alpha: .26),
                            blurRadius: 24 + phase * 5,
                            spreadRadius: 1 + phase * 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sos_rounded,
                            size: 35,
                            color: colors.onError,
                          ),
                          Text(
                            'SOS',
                            style: TextStyle(
                              color: colors.onError,
                              fontSize: 13,
                              letterSpacing: 1.7,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A map pin with a restrained location pulse. It represents a device fix only.
class AnimatedLocationMarker extends StatefulWidget {
  const AnimatedLocationMarker({super.key});

  @override
  State<AnimatedLocationMarker> createState() => _AnimatedLocationMarkerState();
}

class _AnimatedLocationMarkerState extends State<AnimatedLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final phase = MediaQuery.of(context).disableAnimations
          ? 0.0
          : _controller.value;
      return SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 26 + phase * 18,
              height: 26 + phase * 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF31B9F2)
                    .withValues(alpha: (1 - phase) * .24),
              ),
            ),
            Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF168BE5),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55168BE5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
