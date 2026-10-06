import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/player_controller.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/track_tile.dart';

/// Play queue (dark): now playing + drag-to-reorder / swipe-to-remove list.
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final current = player.current;
    final currentIndex = player.currentIndex ?? 0;
    final upNext = player.upNext;

    return ThemedScreen(
      dark: true,
      child: Builder(
        builder: (context) {
          final p = context.palette;
          Widget label(String text) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Text(
              text,
              style: AppText.ui(12, weight: FontWeight.w600, color: p.fg),
            ),
          );

          return Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                MoodBackdrop(
                  imageUrl: current?.imageUrl,
                  animate: player.isPlaying,
                  intensity: 0.8,
                ),
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            IconBtn(
                              Icons.keyboard_arrow_down_rounded,
                              size: 28,
                              tooltip: 'Close',
                              onTap: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                'QUEUE',
                                textAlign: TextAlign.center,
                                style: AppText.ui(
                                  11,
                                  weight: FontWeight.w600,
                                  color: p.fg,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 40),
                          ],
                        ),
                      ),
                      Divider(color: p.border),
                      if (current == null)
                        const Expanded(
                          child: Center(
                            child: MessageView(
                              icon: Icons.queue_music_rounded,
                              title: 'Queue is empty',
                            ),
                          ),
                        )
                      else ...[
                        label('Now Playing'),
                        TrackTile(
                          track: current,
                          onTap: () => Navigator.pop(context),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Divider(color: p.border),
                        ),
                        label('Next in Queue'),
                        Expanded(
                          child: upNext.isEmpty
                              ? MessageView(
                                  icon: Icons.playlist_add_rounded,
                                  title: 'Nothing up next',
                                  subtitle:
                                      'Use "Add to queue" from any song\'s menu.',
                                )
                              : ReorderableListView.builder(
                                  buildDefaultDragHandles: false,
                                  padding: const EdgeInsets.only(bottom: 16),
                                  itemCount: upNext.length,
                                  onReorder: (from, to) => player.move(
                                    currentIndex + 1 + from,
                                    currentIndex + 1 + to,
                                  ),
                                  // Picked-up rows lift toward you in 3D.
                                  proxyDecorator: (child, _, animation) =>
                                      AnimatedBuilder(
                                        animation: animation,
                                        child: child,
                                        builder: (context, child) {
                                          final t = Curves.easeOutCubic
                                              .transform(animation.value);
                                          return Transform(
                                            alignment: Alignment.center,
                                            transform: Motion.perspective()
                                              ..scaleByDouble(
                                                1 + 0.04 * t,
                                                1 + 0.04 * t,
                                                1,
                                                1,
                                              )
                                              ..rotateX(-0.12 * t),
                                            child: Material(
                                              color: Color.lerp(
                                                p.surface,
                                                p.accentDeep,
                                                0.6,
                                              ),
                                              elevation: 12 * t,
                                              shadowColor: p.accent.withValues(
                                                alpha: 0.4,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: child,
                                            ),
                                          );
                                        },
                                      ),
                                  itemBuilder: (context, i) {
                                    final track = upNext[i];
                                    final queueIndex = currentIndex + 1 + i;
                                    return Dismissible(
                                      key: ObjectKey(track),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0x003A1414),
                                              Color(0xFF3A1414),
                                            ],
                                          ),
                                        ),
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                          right: 24,
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFFE5484D),
                                        ),
                                      ),
                                      onDismissed: (_) =>
                                          player.removeAt(queueIndex),
                                      child: TrackTile(
                                        track: track,
                                        onTap: () => player.jumpTo(queueIndex),
                                        trailing: ReorderableDragStartListener(
                                          index: i,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.drag_handle_rounded,
                                              color: p.muted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: p.border)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              _BarAction(
                                icon: Icons.clear_all_rounded,
                                label: 'Clear',
                                onTap: upNext.isEmpty
                                    ? null
                                    : player.clearUpNext,
                              ),
                              _BarAction(
                                icon: Icons.shuffle_rounded,
                                label: 'Shuffle',
                                active: player.shuffleEnabled,
                                onTap: player.toggleShuffle,
                              ),
                              _BarAction(
                                icon: player.loopMode == LoopMode.one
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded,
                                label: 'Repeat',
                                active: player.loopMode != LoopMode.off,
                                onTap: player.cycleRepeat,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = onTap == null ? p.border : (active ? p.accent : p.fg);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: AppText.ui(10.5, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
