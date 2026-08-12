import 'dart:async';

import 'package:flutter/material.dart';

import '../services/studio_cloud_service.dart';

class StudioRateMeRecipientPickerScreen extends StatefulWidget {
  const StudioRateMeRecipientPickerScreen({
    super.key,
    required this.profileType,
  });

  final String profileType;

  @override
  State<StudioRateMeRecipientPickerScreen> createState() =>
      _StudioRateMeRecipientPickerScreenState();
}

class _StudioRateMeRecipientPickerScreenState
    extends State<StudioRateMeRecipientPickerScreen> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<StudioCloudProfile> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(value),
    );
  }

  Future<void> _search(String value) async {
    final query = value.trim();

    if (query.length < 2) {
      if (!mounted) return;

      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });

      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profiles = await StudioCloudService.instance.searchProfiles(query);

      final filtered = profiles
          .where(
            (profile) =>
                profile.active && profile.profileType == widget.profileType,
          )
          .toList(growable: false);

      if (!mounted) return;

      setState(() {
        _results = filtered;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _results = const [];
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.profileType == 'studio' ? 'Choose Studio' : 'Choose Viewer';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: widget.profileType == 'studio'
                      ? 'Search Studio profiles'
                      : 'Search Viewer profiles',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_searchController.text.trim().length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Type at least 2 characters to search.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_loading && _results.isEmpty) {
      return const Center(
        child: Text('No matching profiles found.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final profile = _results[index];

        return ListTile(
          leading: CircleAvatar(
            child: Icon(
              profile.isStudio ? Icons.business_rounded : Icons.person_rounded,
            ),
          ),
          title: Text(profile.displayName),
          subtitle: Text(
            '@${profile.username} · '
            '${profile.isStudio ? 'Studio' : 'Viewer'}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(
            context,
            profile,
          ),
        );
      },
    );
  }
}
