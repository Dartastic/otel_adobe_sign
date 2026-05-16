// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_adobe_sign/otel_adobe_sign.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_adobe_sign-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('agreements.create records signature_type + shard', () async {
    await tracedAdobeSign<String>(
      operation: 'agreements.create',
      shard: 'na2',
      invoke: () async => const AdobeSignCallResult(
        value: 'ok',
        result: AdobeSignResult(
          agreementId: 'ag-1',
          state: 'OUT_FOR_SIGNATURE',
          signatureType: 'NOTARIZE',
          participantCount: 4,
          shard: 'na2',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('adobe_sign agreements.create')!);
    expect(a['adobe_sign.agreement.id'], 'ag-1');
    expect(a['adobe_sign.agreement.state'], 'OUT_FOR_SIGNATURE');
    expect(a['adobe_sign.signature.type'], 'NOTARIZE');
    expect(a['adobe_sign.participant_count'], 4);
    expect(a['adobe_sign.shard'], 'na2');
  });

  test('CANCELLED sets span error', () async {
    await tracedAdobeSign<String>(
      operation: 'agreements.get',
      invoke: () async => const AdobeSignCallResult(
        value: 'ok',
        result: AdobeSignResult(state: 'CANCELLED'),
      ),
    );
    expect(
      spans.findSpanByName('adobe_sign agreements.get')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutAdobeSignInstrumentationAsync(() async {
      await tracedAdobeSign<String>(
        operation: 'agreements.list',
        invoke: () async => const AdobeSignCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('adobe_sign '), isEmpty);
  });
}
