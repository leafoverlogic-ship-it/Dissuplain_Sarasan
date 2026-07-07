import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_session.dart';
import 'Clients_Summary.dart';
import 'UserNamePwd.dart';

class WelcomeLoadingPage extends StatefulWidget {
  final String userName;
  final String roleId;
  final bool allAccess;
  final List<String> allowedRegionIds;
  final List<String> allowedAreaIds;
  final List<String> allowedSubareaIds;

  const WelcomeLoadingPage({
    super.key,
    required this.userName,
    required this.roleId,
    required this.allAccess,
    required this.allowedRegionIds,
    required this.allowedAreaIds,
    required this.allowedSubareaIds,
  });

  @override
  State<WelcomeLoadingPage> createState() => _WelcomeLoadingPageState();
}

class _WelcomeLoadingPageState extends State<WelcomeLoadingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _goNext();
  }

  Future<void> _goNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ClientsSummaryPage(
          roleId: widget.roleId,
          salesPersonName: widget.userName,
          allAccess: widget.allAccess,
          allowedRegionIds: widget.allowedRegionIds,
          allowedAreaIds: widget.allowedAreaIds,
          allowedSubareaIds: widget.allowedSubareaIds,
          onLogout: () {
            AppSession().clear();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const UserNamePwdPage()),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _circleScale(int index, double t) {
    final phase = (t * 3 - index) % 3;
    if (phase < 0 || phase > 1) return 1;
    final pulse = 1 - (2 * phase - 1).abs();
    return 1 + 0.35 * pulse;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF09111A), Color(0xFF111D2E)]
                : const [Color(0xFFE8F4F0), Color(0xFFF8FBFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -140,
              right: -80,
              child: IgnorePointer(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.28),
                        theme.colorScheme.primary.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -100,
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.tertiary.withOpacity(0.22),
                        theme.colorScheme.tertiary.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: theme.colorScheme.surface.withOpacity(isDark ? 0.28 : 0.42),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Container(
                  width: 560,
                  constraints: const BoxConstraints(maxWidth: 560),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.surface.withOpacity(isDark ? 0.74 : 0.88),
                        theme.colorScheme.surfaceContainerHighest.withOpacity(
                          isDark ? 0.58 : 0.72,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.9),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.32 : 0.11),
                        blurRadius: 36,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Welcome ${widget.userName}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Hope you will have a great time working with us',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Getting things ready for you',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final t = _controller.value;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (i) {
                              final scale = _circleScale(i, t);
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 7),
                                child: Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: theme.colorScheme.primary.withOpacity(
                                        0.65 + (scale - 1) * 0.9,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.colorScheme.primary.withOpacity(
                                            0.35 + (scale - 1) * 0.7,
                                          ),
                                          blurRadius: 16,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
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
