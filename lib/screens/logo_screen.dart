import 'package:flutter/material.dart';

class LogoScreen extends StatefulWidget {
	const LogoScreen({
		super.key,
		required this.nextScreen,
		this.duration = const Duration(seconds: 2),
	});

	final Widget nextScreen;
	final Duration duration;

	@override
	State<LogoScreen> createState() => _LogoScreenState();
}

class _LogoScreenState extends State<LogoScreen> {
	@override
	void initState() {
		super.initState();
		Future.delayed(widget.duration, () {
			if (!mounted) return;
			Navigator.of(context).pushReplacement(
				MaterialPageRoute<void>(builder: (_) => widget.nextScreen),
			);
		});
	}

	@override
	Widget build(BuildContext context) {
		return const Scaffold(
			backgroundColor: Color(0xFFFFFFFF),
			body: _LogoBody(),
		);
	}
}

class _LogoBody extends StatelessWidget {
	const _LogoBody();

	@override
	Widget build(BuildContext context) {
		final screenWidth = MediaQuery.sizeOf(context).width;
		final logoWidth = (screenWidth * 0.80).clamp(260.0, 480.0);

		return SafeArea(
			child: Center(
				child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 32),
					child: Image.asset(
						'assets/logo.png',
						width: logoWidth,
						fit: BoxFit.contain,
						filterQuality: FilterQuality.high,
					),
				),
			),
		);
	}
}
