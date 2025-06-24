import 'package:flutter/material.dart';

class AnimatedGradientButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;

  const AnimatedGradientButton({
    required this.onPressed,
    this.text = 'Unirme a la sala',
    super.key
  });

  @override
  _AnimatedGradientButtonState createState() => _AnimatedGradientButtonState();
}

class _AnimatedGradientButtonState extends State<AnimatedGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;


  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6), // Slower for smoother transition
      vsync: this,
    )..repeat();

    // Use a smoother curve for the animation
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.linear, // Linear ensures a seamless loop
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.purple, Colors.blue],
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment(-3.0 + _animation.value * 4, 0.0),
                end: Alignment(-1.0 + _animation.value * 4, 0.0),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(3),
            child: ElevatedButton(
              onPressed: widget.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [Colors.blue, Colors.purple, Colors.blue],
                    stops: const [0.0, 0.5, 1.0],
                    begin: Alignment(-3.0 + _animation.value * 4, 0.0),
                    end: Alignment(-1.0 + _animation.value * 4, 0.0),
                  ).createShader(bounds);
                },
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}