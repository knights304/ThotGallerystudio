import 'package:flutter/material.dart';

import '../services/studio_cloud_service.dart';

class StudioAuthGate extends StatefulWidget {
  const StudioAuthGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<StudioAuthGate> createState() => _StudioAuthGateState();
}

class _StudioAuthGateState extends State<StudioAuthGate> {
  bool _checking = true;
  bool _authenticated = false;
  bool _busy = false;
  bool _createMode = true;

  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _recoveryEmailController = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _recoveryEmailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingLogin() async {
    try {
      if (await StudioCloudService.instance.isAuthenticated) {
        final profile = await StudioCloudService.instance.getMe();

        if (profile.profileType == 'studio') {
          _authenticated = true;
        } else {
          await StudioCloudService.instance.clearDeviceToken();
        }
      }
    } catch (_) {
      await StudioCloudService.instance.clearDeviceToken();
    }

    if (!mounted) return;

    setState(() => _checking = false);
  }

  Future<void> _submit() async {
    if (_busy) return;

    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final recoveryEmail = _recoveryEmailController.text.trim().toLowerCase();
    final pin = _pinController.text.trim();

    if (username.length < 3) {
      _message('Choose a username with at least 3 characters.');
      return;
    }

    if (_createMode && displayName.isEmpty) {
      _message('Enter a display name.');
      return;
    }

    if (_createMode &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(recoveryEmail)) {
      _message('Enter a valid recovery email address.');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      _message('PIN must be exactly 6 digits.');
      return;
    }

    setState(() => _busy = true);

    try {
      final profile = _createMode
          ? await StudioCloudService.instance.register(
              username: username,
              displayName: displayName,
              recoveryEmail: recoveryEmail,
              pin: pin,
            )
          : await StudioCloudService.instance.login(
              username: username,
              pin: pin,
            );

      if (profile.profileType != 'studio') {
        await StudioCloudService.instance.clearDeviceToken();

        throw const StudioCloudException(
          'That username belongs to a Viewer account.',
        );
      }

      if (!mounted) return;

      setState(() {
        _authenticated = true;
      });
    } on StudioCloudException catch (error) {
      if (!mounted) return;
      _message(error.message);
    } catch (error) {
      if (!mounted) return;
      _message('Could not connect: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_authenticated) {
      return widget.child;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('THOT Gallery Studio'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.business_center_rounded,
              size: 72,
            ),
            const SizedBox(height: 18),
            Text(
              _createMode ? 'Create your Studio profile' : 'Sign in to Studio',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _createMode
                  ? 'Your username is how Viewer and Studio users will find you and send cards.'
                  : 'Use your username and PIN to reconnect this device.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _usernameController,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixText: '@',
                border: OutlineInputBorder(),
              ),
            ),
            if (_createMode) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _displayNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _recoveryEmailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Recovery email',
                  hintText: 'you@example.com',
                  helperText: 'Used only for account recovery.',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: '6-digit PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      _createMode
                          ? Icons.person_add_rounded
                          : Icons.login_rounded,
                    ),
              label: Text(
                _busy
                    ? 'Connecting...'
                    : _createMode
                        ? 'Create Studio Profile'
                        : 'Sign In',
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _createMode = !_createMode;
                        _pinController.clear();
                      });
                    },
              child: Text(
                _createMode
                    ? 'Already have a username? Sign in'
                    : 'New Studio? Create an account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
