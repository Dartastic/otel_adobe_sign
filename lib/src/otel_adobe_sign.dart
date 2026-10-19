// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_adobe_sign_suppression.dart';

const _tracerName = 'dartastic_otel_libs_adobe_sign';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class AdobeSignResult {
  const AdobeSignResult({
    this.itemCount,
    this.agreementId,
    this.state,
    this.signatureType,
    this.megaSign,
    this.shard,
    this.participantCount,
    this.workflowId,
    this.requestId,
    this.statusCode,
  });

  /// Items returned.
  final int? itemCount;

  /// `agreementId`.
  final String? agreementId;

  /// `IN_PROCESS` / `OUT_FOR_SIGNATURE` / `SIGNED` / `APPROVED` /
  /// `EXPIRED` / `CANCELLED` / `DECLINED` / `ARCHIVED` / `FORM` /
  /// `WAITING_FOR_AUTHORING` / `AUTHORING`.
  final String? state;

  /// `ESIGN` / `WRITTEN` / `DIGITAL` / `NOTARIZE`. NOTARIZE is the
  /// remote-online-notarization SKU (much pricier).
  final String? signatureType;

  /// True when this is a Mega Sign / bulk send (separate billing).
  final bool? megaSign;

  /// Adobe data shard (`na1`, `na2`, `na3`, `eu1`, `eu2`, `jp1`,
  /// `au1`, `ind1`...) — drives latency.
  final String? shard;

  /// Total participants on the agreement (signers + approvers +
  /// CCs etc.).
  final int? participantCount;

  /// `workflowId` when the agreement was created from a custom
  /// workflow.
  final String? workflowId;

  /// `X-Echosign-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class AdobeSignCallResult<T> {
  const AdobeSignCallResult({required this.value, this.result});
  final T value;
  final AdobeSignResult? result;
}

/// Wraps an Adobe Acrobat Sign API call in a CLIENT span. [operation]
/// is one of `agreements.list`, `agreements.get`, `agreements.create`,
/// `agreements.cancel`, `agreements.update_state`,
/// `agreements.members`, `agreements.documents`, `library_documents.list`,
/// `library_documents.create`, `mega_sign.list`, `mega_sign.create`,
/// `workflows.list`, `workflows.run`, `webhooks.create`, `users.list`,
/// `groups.list`, `transient_documents.create`.
Future<T> tracedAdobeSign<T>({
  required String operation,
  required Future<AdobeSignCallResult<T>> Function() invoke,
  String? shard,
}) async {
  if (adobeSignInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'adobe_sign',
    'rpc.method': operation,
    'adobe_sign.operation': operation,
  };
  if (shard != null) m['adobe_sign.shard'] = shard;

  final span = _tracer().startSpan(
    'adobe_sign $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTelAPI.attributeInt(
          'adobe_sign.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.agreementId != null) {
        extras.add(OTelAPI.attributeString(
          'adobe_sign.agreement.id',
          r.result!.agreementId!,
        ));
      }
      if (r.result!.state != null) {
        extras.add(OTelAPI.attributeString(
          'adobe_sign.agreement.state',
          r.result!.state!,
        ));
        if (r.result!.state == 'DECLINED' ||
            r.result!.state == 'CANCELLED' ||
            r.result!.state == 'EXPIRED') {
          span.setStatus(
            SpanStatusCode.Error,
            'Adobe Sign agreement ${r.result!.state}',
          );
        }
      }
      if (r.result!.signatureType != null) {
        extras.add(OTelAPI.attributeString(
          'adobe_sign.signature.type',
          r.result!.signatureType!,
        ));
      }
      if (r.result!.megaSign != null) {
        extras.add(OTelAPI.attributeBool(
          'adobe_sign.mega_sign',
          r.result!.megaSign!,
        ));
      }
      if (r.result!.shard != null) {
        extras.add(OTelAPI.attributeString(
          'adobe_sign.shard',
          r.result!.shard!,
        ));
      }
      if (r.result!.participantCount != null) {
        extras.add(OTelAPI.attributeInt(
          'adobe_sign.participant_count',
          r.result!.participantCount!,
        ));
      }
      if (r.result!.workflowId != null) {
        extras.add(OTelAPI.attributeString(
          'adobe_sign.workflow.id',
          r.result!.workflowId!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'adobe_sign.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Adobe Sign HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
