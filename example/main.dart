// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_adobe_sign/otel_adobe_sign.dart';

/// Traces an Adobe Acrobat Sign API call as a CLIENT span.
///
/// The application initializes the OpenTelemetry SDK; this package uses
/// only the OpenTelemetry API.
Future<void> main() async {
  await OTel.initialize(serviceName: 'adobe-sign-example');

  final agreementId = await tracedAdobeSign<String>(
    operation: 'agreements.create',
    invoke: () async {
      // Call the Acrobat Sign REST API here (POST /agreements) and report
      // what it returned.
      const id = 'CBJCHBCAABAA-example';
      return const AdobeSignCallResult(
        value: id,
        result: AdobeSignResult(agreementId: id, statusCode: 201),
      );
    },
  );

  OTelLog.info('Created agreement $agreementId');
  await OTel.shutdown();
}
