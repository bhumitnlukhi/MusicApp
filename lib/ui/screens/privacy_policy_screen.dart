import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// In-app Privacy Policy screen matching the legal web policy layout.
/// Features prominent boxed cards, section badges, and clear disclosures
/// compliant with Google Play Store standards.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ThemedScreen(
      dark: p.isDark,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Top Bar with Back Button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      IconBtn(
                        Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: ScreenLabel('LEGAL // TRANSPARENCY'),
                      ),
                    ],
                  ),
                ),
              ),

              // Title Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Entrance(
                    offset: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const DisplayTitle('PRIVACY POLICY', size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'Melofy is designed with privacy at its foundation. Listening to music shouldn\'t require surrendering your personal data.',
                          style: AppText.ui(13.5, color: p.muted, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: p.border),
                          ),
                          child: Text(
                            'Effective: November 2026 • Version 1.0.0',
                            style: AppText.mono(11, color: p.muted),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),

              // 3 Core Pillars (Cards)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _PillarTile(
                        icon: Icons.shield_outlined,
                        title: 'Zero Data Collection',
                        desc:
                            'No user accounts. We never collect or store your name, email, phone, or identity.',
                      ),
                      const SizedBox(height: 10),
                      _PillarTile(
                        icon: Icons.phone_android_rounded,
                        title: '100% On-Device',
                        desc:
                            'Playlists, favorites, and history reside strictly inside your device\'s local sandbox.',
                      ),
                      const SizedBox(height: 10),
                      _PillarTile(
                        icon: Icons.do_not_disturb_on_outlined,
                        title: 'No Tracking SDKs',
                        desc:
                            'Zero behavioral advertising networks, third-party analytics, or background trackers.',
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Sections as Distinct Boxed Cards
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Section 01
                    _SectionCard(
                      index: '01',
                      title: 'Information We Do Not Collect',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Melofy does not operate user accounts, cloud databases, or tracking infrastructure. We do not collect, monetize, or transmit:',
                            style: AppText.ui(
                              13.5,
                              color: p.fg.withValues(alpha: 0.9),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _BulletPoint(
                            title: 'Personal Identifiers',
                            desc:
                                'No names, email addresses, phone numbers, or account IDs.',
                          ),
                          _BulletPoint(
                            title: 'Financial Information',
                            desc:
                                'Melofy is completely free. No payment details or bank accounts.',
                          ),
                          _BulletPoint(
                            title: 'Location Data',
                            desc: 'We never request GPS or network location.',
                          ),
                          _BulletPoint(
                            title: 'Sensory Hardware',
                            desc:
                                'No access to device camera, microphone, or motion sensors.',
                          ),
                          _BulletPoint(
                            title: 'Private Files',
                            desc:
                                'No access to photos, contacts, SMS, or external directories.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 02
                    _SectionCard(
                      index: '02',
                      title: 'Information Handled Locally',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All personalization runs strictly on-device without cloud synchronization:',
                            style: AppText.ui(
                              13.5,
                              color: p.fg.withValues(alpha: 0.9),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _InsetCard(
                            title: 'Playlists & Liked Songs',
                            desc:
                                'Saved locally in SQLite and SharedPreferences. Accessible only inside Melofy and never synced to external servers.',
                          ),
                          const SizedBox(height: 10),
                          _InsetCard(
                            title: 'Cached Artwork & Media',
                            desc:
                                'Temporary cache buffers allow instant playback and reduce data usage. Can be cleared anytime in Android settings.',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Permanent Data Deletion: Because data is stored only on-device, selecting "Clear Storage" in Android settings or uninstalling Melofy immediately and permanently erases 100% of your data.',
                            style: AppText.ui(
                              12.5,
                              color: p.muted,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 03
                    _SectionCard(
                      index: '03',
                      title: 'Network Requests & Content',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Melofy makes secure HTTPS requests to deliver music streaming and synchronized lyrics:',
                            style: AppText.ui(
                              13.5,
                              color: p.fg.withValues(alpha: 0.9),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _BulletPoint(
                            title: 'Media Streaming',
                            desc:
                                'Transmitted over encrypted TLS connections for track metadata and audio streams. No personal identifiers are attached.',
                          ),
                          _BulletPoint(
                            title: 'Lyrics (LRCLIB)',
                            desc:
                                'Synchronized lyrics are retrieved from open community database LRCLIB with track title and artist name only.',
                          ),
                          _BulletPoint(
                            title: 'Zero Ads',
                            desc:
                                'No advertising SDKs, banner networks, or tracking pixels.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 04
                    _SectionCard(
                      index: '04',
                      title: 'Device Permissions',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Melofy adheres strictly to Google Play\'s Least Privilege model and requests only essential playback permissions:',
                            style: AppText.ui(
                              13.5,
                              color: p.fg.withValues(alpha: 0.9),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _PermissionRow(
                            code: 'INTERNET',
                            desc:
                                'Streaming audio, album artwork, and synced lyrics over HTTPS.',
                          ),
                          _PermissionRow(
                            code: 'FOREGROUND_SERVICE_MEDIA_PLAYBACK',
                            desc:
                                'Background audio playback when screen is locked or app is minimized (Android 14+).',
                          ),
                          _PermissionRow(
                            code: 'WAKE_LOCK',
                            desc:
                                'Prevents CPU sleep while decoding active audio streams.',
                          ),
                          _PermissionRow(
                            code: 'POST_NOTIFICATIONS',
                            desc:
                                'Shows lock screen and notification tray media player controls (Android 13+).',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 05
                    _SectionCard(
                      index: '05',
                      title: 'Content Aggregation & DMCA',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Melofy functions strictly as an audio player client and indexing interface. Melofy does not own, host, produce, or upload media files to any remote server.',
                            style: AppText.ui(
                              13.5,
                              color: p.fg.withValues(alpha: 0.9),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _InsetCard(
                            title: 'DMCA Takedown Requests',
                            desc:
                                'We respect intellectual property rights. Copyright owners may submit formal infringement inquiries with track details to our contact address for prompt processing.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 06
                    _SectionCard(
                      index: '06',
                      title: 'Data Security',
                      child: Text(
                        'Because Melofy does not maintain external accounts or cloud user databases, your listening history is immune to remote data breaches. All network communications use standard Transport Layer Security (HTTPS/TLS) encryption.',
                        style: AppText.ui(
                          13.5,
                          color: p.fg.withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 07
                    _SectionCard(
                      index: '07',
                      title: 'Children\'s Privacy',
                      child: Text(
                        'Melofy does not knowingly collect personal information from children under 13 (or under 16 in the EU). Because no personal information is collected from any user, children\'s privacy is preserved by design under COPPA and GDPR.',
                        style: AppText.ui(
                          13.5,
                          color: p.fg.withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 08
                    _SectionCard(
                      index: '08',
                      title: 'Contact Us',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'For questions, feedback, or legal inquiries regarding this Privacy Policy:',
                            style: AppText.ui(
                              13.5,
                              color: p.fg.withValues(alpha: 0.9),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Clipboard.setData(
                                const ClipboardData(
                                  text: 'bestminders@gmail.com',
                                ),
                              );
                              showSnack(
                                context,
                                'Email copied: bestminders@gmail.com',
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: p.isDark
                                    ? AppColors.inkBorder.withValues(alpha: 0.4)
                                    : AppColors.paperBorder.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: p.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    color: p.accentText,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SUPPORT & LEGAL INQUIRIES',
                                          style: AppText.mono(
                                            10,
                                            color: p.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'bestminders@gmail.com',
                                          style: AppText.ui(
                                            14,
                                            weight: FontWeight.w600,
                                            color: p.fg,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                    color: p.muted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Footer Notice
                    Center(
                      child: Text(
                        '© 2026 Melofy. All rights reserved.',
                        style: AppText.mono(11, color: p.muted),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable Section Card matching the web boxed container styling
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.index,
    required this.title,
    required this.child,
  });

  final String index;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.isDark
                      ? AppColors.inkBorder
                      : AppColors.paperBorder.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  index,
                  style: AppText.ui(
                    12,
                    weight: FontWeight.w700,
                    color: p.accentText,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppText.ui(15, weight: FontWeight.w700, color: p.fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Top 3 Pillar Tiles
class _PillarTile extends StatelessWidget {
  const _PillarTile({
    required this.icon,
    required this.title,
    required this.desc,
  });

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: p.isDark
                  ? AppColors.inkBorder
                  : AppColors.paperBorder.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: p.accentText),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.ui(14, weight: FontWeight.w700, color: p.fg),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: AppText.ui(12.5, color: p.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sub-box inside a section
class _InsetCard extends StatelessWidget {
  const _InsetCard({required this.title, required this.desc});

  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.isDark
            ? AppColors.ink.withValues(alpha: 0.5)
            : AppColors.paper.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.ui(13, weight: FontWeight.w600, color: p.fg),
          ),
          const SizedBox(height: 4),
          Text(desc, style: AppText.ui(12, color: p.muted, height: 1.45)),
        ],
      ),
    );
  }
}

/// Bullet Point Row
class _BulletPoint extends StatelessWidget {
  const _BulletPoint({required this.title, required this.desc});

  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: p.accentText,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppText.ui(13, color: p.fg, height: 1.45),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: desc, style: TextStyle(color: p.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Permission Disclosure Row
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.code, required this.desc});

  final String code;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.isDark
              ? AppColors.ink.withValues(alpha: 0.4)
              : AppColors.paper.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: p.isDark ? AppColors.inkSurface : AppColors.paperBorder,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                code,
                style: AppText.mono(
                  10.5,
                  weight: FontWeight.w600,
                  color: p.fg,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(desc, style: AppText.ui(12, color: p.muted, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
