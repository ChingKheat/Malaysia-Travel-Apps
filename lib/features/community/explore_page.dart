import 'package:flutter/material.dart';
import '../places/screens/api_demo_page.dart';
import 'community_page.dart';

/// Opens community from one card, without introducing another tab row.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, required this.isVisible});
  final bool isVisible;
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  bool _communityOpen = false;

  Future<void> _openCommunity() async {
    if (_communityOpen) return;
    setState(() => _communityOpen = true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CommunityPage(showAppBar: true),
      ),
    );
    if (mounted) setState(() => _communityOpen = false);
  }

  @override
  Widget build(BuildContext context) => ApiDemoPage(
    isVisible: widget.isVisible && !_communityOpen,
    discoveryHeader: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: InkWell(
          onTap: _openCommunity,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/recognition/petronas.jpg',
                    width: 52,
                    height: 60,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        communityText(
                          context,
                          'Traveler stories',
                          '旅人分享',
                          'Kisah pengembara',
                        ),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        communityText(
                          context,
                          'Places, food & tips from travelers',
                          '看看大家去哪里、吃什么',
                          'Tempat, makanan dan petua perjalanan',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
