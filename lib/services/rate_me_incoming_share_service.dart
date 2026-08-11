import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../models/rate_me_card.dart';
import '../models/rate_me_response.dart';
import 'rate_me_package_service.dart';
import 'rate_me_response_service.dart';
import 'rate_me_store.dart';

enum StudioRateMeIncomingKind {
  card,
  response,
}

class StudioRateMeIncomingEvent {
  const StudioRateMeIncomingEvent({
    required this.kind,
    required this.sourcePath,
    required this.message,
    this.card,
    this.response,
  });

  final StudioRateMeIncomingKind kind;
  final String sourcePath;
  final String message;
  final StudioRateMeCard? card;
  final StudioRateMeResponse? response;
}

/// Receives Rate Me packages that Android shares or opens with THOT Gallery
/// Studio.
///
/// Supported files:
///   *.tgrate          -> imported into the Studio Rate Me card library
///   *.tgrateresponse  -> imported into the matching card's response inbox
///
/// Call [start] once after Flutter has initialized. Listen to [events] if the
/// UI wants to show a snackbar, refresh an inbox, or navigate to the imported
/// card/response.
class StudioRateMeIncomingShareService {
  StudioRateMeIncomingShareService._();

  static final StudioRateMeIncomingShareService instance =
      StudioRateMeIncomingShareService._();

  final StreamController<StudioRateMeIncomingEvent> _eventController =
      StreamController<StudioRateMeIncomingEvent>.broadcast();

  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  final Set<String> _processing = <String>{};
  final Set<String> _processedLaunchItems = <String>{};

  StreamSubscription<List<SharedMediaFile>>? _mediaSubscription;

  bool _started = false;

  Stream<StudioRateMeIncomingEvent> get events => _eventController.stream;

  Stream<String> get errors => _errorController.stream;

  Future<void> start() async {
    if (_started || kIsWeb) {
      return;
    }

    _started = true;

    _mediaSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        unawaited(_handleFiles(files));
      },
      onError: (Object error, StackTrace stackTrace) {
        _emitError('Could not receive shared Rate Me file: $error');
      },
    );

    try {
      final initialFiles =
          await ReceiveSharingIntent.instance.getInitialMedia();

      if (initialFiles.isNotEmpty) {
        await _handleFiles(
          initialFiles,
          initialLaunch: true,
        );
      }
    } catch (error) {
      _emitError('Could not read the launch share: $error');
    } finally {
      // Prevent Android's launch payload from being returned again when this
      // service is recreated during the same app session.
      ReceiveSharingIntent.instance.reset();
    }
  }

  Future<void> stop() async {
    await _mediaSubscription?.cancel();
    _mediaSubscription = null;
    _started = false;
  }

  Future<void> dispose() async {
    await stop();
    await _eventController.close();
    await _errorController.close();
  }

  Future<void> _handleFiles(
    List<SharedMediaFile> sharedFiles, {
    bool initialLaunch = false,
  }) async {
    for (final shared in sharedFiles) {
      final rawPath = shared.path.trim();

      if (rawPath.isEmpty) {
        continue;
      }

      final normalizedPath = _normalizeIncomingPath(rawPath);
      final extension = p.extension(normalizedPath).toLowerCase();

      if (extension != '.tgrate' && extension != '.tgrateresponse') {
        continue;
      }

      final launchKey = '$extension::$normalizedPath';

      if (initialLaunch && _processedLaunchItems.contains(launchKey)) {
        continue;
      }

      if (_processing.contains(launchKey)) {
        continue;
      }

      _processing.add(launchKey);

      try {
        final file = File(normalizedPath);

        if (!await file.exists()) {
          throw StateError(
            'Android shared the file, but Studio cannot read it: '
            '$normalizedPath',
          );
        }

        if (extension == '.tgrate') {
          await _importCard(file);
        } else {
          await _importResponse(file);
        }

        if (initialLaunch) {
          _processedLaunchItems.add(launchKey);
        }
      } catch (error) {
        _emitError(
          'Could not import ${p.basename(normalizedPath)}: $error',
        );
      } finally {
        _processing.remove(launchKey);
      }
    }
  }

  Future<void> _importCard(File file) async {
    final imported = await StudioRateMePackageService.importPackage(file);

    final saved = await StudioRateMeStore.saveCard(
      imported.card,
    );

    _eventController.add(
      StudioRateMeIncomingEvent(
        kind: StudioRateMeIncomingKind.card,
        sourcePath: file.path,
        card: saved,
        message: 'Imported Rate Me card “${saved.title}”.',
      ),
    );
  }

  Future<void> _importResponse(File file) async {
    final imported = await StudioRateMeResponseService.importPackage(file);

    final response = imported.response;

    // A response is only useful in Studio if its original Rate Me card exists.
    final cards = await StudioRateMeStore.loadAll();

    StudioRateMeCard? matchingCard;

    for (final card in cards) {
      if (card.id == response.cardId) {
        matchingCard = card;
        break;
      }
    }

    if (matchingCard == null) {
      // The response service has already installed this response. Remove that
      // installed copy so an unmatched response does not silently pollute the
      // inbox.
      if (await imported.storageDirectory.exists()) {
        await imported.storageDirectory.delete(recursive: true);
      }

      throw StateError(
        'This response belongs to Rate Me card '
        '“${response.cardId}”, which is not installed in Studio.',
      );
    }

    final responder = response.responderName.trim().isEmpty
        ? 'Anonymous'
        : response.responderName.trim();

    _eventController.add(
      StudioRateMeIncomingEvent(
        kind: StudioRateMeIncomingKind.response,
        sourcePath: file.path,
        card: matchingCard,
        response: response,
        message: 'Imported a Rate Me response from $responder for '
            '“${matchingCard.title}”.',
      ),
    );
  }

  String _normalizeIncomingPath(String value) {
    if (value.startsWith('file://')) {
      return Uri.parse(value).toFilePath();
    }

    return value;
  }

  void _emitError(String message) {
    _errorController.add(message);
  }
}
