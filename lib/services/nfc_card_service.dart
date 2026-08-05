import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../models/nfc_entitlement.dart';
import '../models/physical_card_protocol.dart';

enum NfcCardOperationStatus {
  success,
  unavailable,
  unsupportedTag,
  readOnly,
  tooSmall,
  invalidPayload,
  failed,
}

class NfcCardWriteResult {
  const NfcCardWriteResult({
    required this.status,
    required this.message,
    this.writtenUri,
    this.verifiedUri,
  });

  final NfcCardOperationStatus status;
  final String message;
  final Uri? writtenUri;
  final Uri? verifiedUri;

  bool get isSuccess => status == NfcCardOperationStatus.success;
}

class NfcCardReadResult {
  const NfcCardReadResult({
    required this.status,
    required this.message,
    this.uri,
  });

  final NfcCardOperationStatus status;
  final String message;
  final Uri? uri;

  bool get isSuccess => status == NfcCardOperationStatus.success;
}

class NfcCardService {
  const NfcCardService._();

  static Future<NfcAvailability> checkAvailability() {
    return NfcManager.instance.checkAvailability();
  }

  static Future<bool> get isAvailable async {
    return await checkAvailability() == NfcAvailability.enabled;
  }

  /// Builds a versioned physical-card redemption URI.
  static Uri buildEntitlementUri(NfcEntitlement entitlement) {
    return PhysicalCardProtocol.buildUri(entitlement);
  }

  static NfcEntitlement? parseEntitlementUri(Uri uri) {
    final result = PhysicalCardProtocol.parse(uri);
    return result.entitlement;
  }

  static PhysicalCardProtocolParseResult inspectEntitlementUri(Uri uri) {
    return PhysicalCardProtocol.parse(uri);
  }

  static Future<NfcCardWriteResult> writeViewerAccessCard({
    required Uri uri,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (uri.scheme.isEmpty || uri.host.isEmpty) {
      return const NfcCardWriteResult(
        status: NfcCardOperationStatus.invalidPayload,
        message: 'The Viewer access URI is invalid.',
      );
    }

    final availability = await checkAvailability();
    if (availability != NfcAvailability.enabled) {
      return const NfcCardWriteResult(
        status: NfcCardOperationStatus.unavailable,
        message: 'NFC is not available or is currently disabled.',
      );
    }

    final completer = Completer<NfcCardWriteResult>();
    Timer? timeoutTimer;
    var handledTag = false;

    Future<void> finish(
      NfcCardWriteResult result, {
      String? iosMessage,
      String? iosError,
    }) async {
      if (!completer.isCompleted) {
        completer.complete(result);
      }

      timeoutTimer?.cancel();

      try {
        await NfcManager.instance.stopSession(
          alertMessageIos: iosMessage,
          errorMessageIos: iosError,
        );
      } catch (_) {
        // The session may already have been invalidated by the platform.
      }
    }

    try {
      await NfcManager.instance.startSession(
        pollingOptions: const {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        alertMessageIos: 'Hold the NFC card near the top of your iPhone.',
        onDiscovered: (NfcTag tag) async {
          if (handledTag) {
            return;
          }
          handledTag = true;

          try {
            final ndef = Ndef.from(tag);

            if (ndef == null) {
              await finish(
                const NfcCardWriteResult(
                  status: NfcCardOperationStatus.unsupportedTag,
                  message: 'This NFC tag is not NDEF compatible.',
                ),
                iosError: 'This tag is not NDEF compatible.',
              );
              return;
            }

            if (!ndef.isWritable) {
              await finish(
                const NfcCardWriteResult(
                  status: NfcCardOperationStatus.readOnly,
                  message: 'This NFC tag is read-only.',
                ),
                iosError: 'This tag is read-only.',
              );
              return;
            }

            final message = _uriMessage(uri);

            if (ndef.maxSize > 0 && message.byteLength > ndef.maxSize) {
              await finish(
                NfcCardWriteResult(
                  status: NfcCardOperationStatus.tooSmall,
                  message: 'This NFC tag is too small. '
                      'Needs ${message.byteLength} bytes but only '
                      '${ndef.maxSize} bytes are available.',
                ),
                iosError: 'This tag does not have enough storage.',
              );
              return;
            }

            await ndef.write(message: message);

            final readBack = await ndef.read();
            final verifiedUri = _firstUri(readBack);

            if (verifiedUri == null ||
                verifiedUri.toString() != uri.toString()) {
              await finish(
                NfcCardWriteResult(
                  status: NfcCardOperationStatus.failed,
                  message: 'The tag was written, but read-back verification '
                      'did not match the expected Viewer link.',
                  writtenUri: uri,
                  verifiedUri: verifiedUri,
                ),
                iosError: 'Write verification failed.',
              );
              return;
            }

            await finish(
              NfcCardWriteResult(
                status: NfcCardOperationStatus.success,
                message: 'NFC card written and verified successfully.',
                writtenUri: uri,
                verifiedUri: verifiedUri,
              ),
              iosMessage: 'NFC card written and verified.',
            );
          } catch (error) {
            await finish(
              NfcCardWriteResult(
                status: NfcCardOperationStatus.failed,
                message: 'Could not write the NFC card: $error',
                writtenUri: uri,
              ),
              iosError: 'Could not write the NFC card.',
            );
          }
        },
      );

      timeoutTimer = Timer(timeout, () {
        finish(
          const NfcCardWriteResult(
            status: NfcCardOperationStatus.failed,
            message: 'NFC write timed out before a tag was detected.',
          ),
          iosError: 'NFC write timed out.',
        );
      });
    } catch (error) {
      timeoutTimer?.cancel();
      return NfcCardWriteResult(
        status: NfcCardOperationStatus.failed,
        message: 'Could not start the NFC session: $error',
      );
    }

    return completer.future;
  }

  /// Reads the first NFC Forum URI record from a physical tag.
  static Future<NfcCardReadResult> readViewerAccessCard({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final availability = await checkAvailability();
    if (availability != NfcAvailability.enabled) {
      return const NfcCardReadResult(
        status: NfcCardOperationStatus.unavailable,
        message: 'NFC is not available or is currently disabled.',
      );
    }

    final completer = Completer<NfcCardReadResult>();
    Timer? timeoutTimer;
    var handledTag = false;

    Future<void> finish(
      NfcCardReadResult result, {
      String? iosMessage,
      String? iosError,
    }) async {
      if (!completer.isCompleted) {
        completer.complete(result);
      }

      timeoutTimer?.cancel();

      try {
        await NfcManager.instance.stopSession(
          alertMessageIos: iosMessage,
          errorMessageIos: iosError,
        );
      } catch (_) {
        // The platform may already have invalidated the session.
      }
    }

    try {
      await NfcManager.instance.startSession(
        pollingOptions: const {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        alertMessageIos: 'Hold the NFC card near the top of your iPhone.',
        onDiscovered: (NfcTag tag) async {
          if (handledTag) {
            return;
          }
          handledTag = true;

          try {
            final ndef = Ndef.from(tag);

            if (ndef == null) {
              await finish(
                const NfcCardReadResult(
                  status: NfcCardOperationStatus.unsupportedTag,
                  message: 'This NFC tag is not NDEF compatible.',
                ),
                iosError: 'This tag is not NDEF compatible.',
              );
              return;
            }

            final message = await ndef.read();
            final uri = _firstUri(message);

            if (uri == null) {
              await finish(
                const NfcCardReadResult(
                  status: NfcCardOperationStatus.invalidPayload,
                  message: 'No Viewer access URI was found on this tag.',
                ),
                iosError: 'No Viewer access link was found.',
              );
              return;
            }

            await finish(
              NfcCardReadResult(
                status: NfcCardOperationStatus.success,
                message: 'NFC Viewer access link read successfully.',
                uri: uri,
              ),
              iosMessage: 'NFC card verified.',
            );
          } catch (error) {
            await finish(
              NfcCardReadResult(
                status: NfcCardOperationStatus.failed,
                message: 'Could not read the NFC card: $error',
              ),
              iosError: 'Could not read the NFC card.',
            );
          }
        },
      );

      timeoutTimer = Timer(timeout, () {
        finish(
          const NfcCardReadResult(
            status: NfcCardOperationStatus.failed,
            message: 'NFC read timed out before a tag was detected.',
          ),
          iosError: 'NFC read timed out.',
        );
      });
    } catch (error) {
      timeoutTimer?.cancel();
      return NfcCardReadResult(
        status: NfcCardOperationStatus.failed,
        message: 'Could not start the NFC session: $error',
      );
    }

    return completer.future;
  }

  static NdefMessage _uriMessage(Uri uri) {
    final uriBytes = utf8.encode(uri.toString());

    // NFC Forum URI RTD. Prefix byte 0x00 means no URI prefix compression,
    // so the remainder of the payload contains the full URI.
    final record = NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList(const [0x55]), // "U"
      identifier: Uint8List(0),
      payload: Uint8List.fromList([
        0x00,
        ...uriBytes,
      ]),
    );

    return NdefMessage(records: [record]);
  }

  static Uri? _firstUri(NdefMessage? message) {
    if (message == null) {
      return null;
    }

    for (final record in message.records) {
      if (record.typeNameFormat != TypeNameFormat.wellKnown) {
        continue;
      }

      if (record.type.length != 1 || record.type.first != 0x55) {
        continue;
      }

      final payload = record.payload;
      if (payload.isEmpty) {
        continue;
      }

      final prefix = _uriPrefix(payload.first);
      final remainder = utf8.decode(
        payload.sublist(1),
        allowMalformed: false,
      );

      final parsed = Uri.tryParse('$prefix$remainder');
      if (parsed != null && parsed.scheme.isNotEmpty) {
        return parsed;
      }
    }

    return null;
  }

  static String _uriPrefix(int code) {
    return switch (code) {
      0x01 => 'http://www.',
      0x02 => 'https://www.',
      0x03 => 'http://',
      0x04 => 'https://',
      0x05 => 'tel:',
      0x06 => 'mailto:',
      0x07 => 'ftp://anonymous:anonymous@',
      0x08 => 'ftp://ftp.',
      0x09 => 'ftps://',
      0x0A => 'sftp://',
      0x0B => 'smb://',
      0x0C => 'nfs://',
      0x0D => 'ftp://',
      0x0E => 'dav://',
      0x0F => 'news:',
      0x10 => 'telnet://',
      0x11 => 'imap:',
      0x12 => 'rtsp://',
      0x13 => 'urn:',
      0x14 => 'pop:',
      0x15 => 'sip:',
      0x16 => 'sips:',
      0x17 => 'tftp:',
      0x18 => 'btspp://',
      0x19 => 'btl2cap://',
      0x1A => 'btgoep://',
      0x1B => 'tcpobex://',
      0x1C => 'irdaobex://',
      0x1D => 'file://',
      0x1E => 'urn:epc:id:',
      0x1F => 'urn:epc:tag:',
      0x20 => 'urn:epc:pat:',
      0x21 => 'urn:epc:raw:',
      0x22 => 'urn:epc:',
      0x23 => 'urn:nfc:',
      _ => '',
    };
  }
}
