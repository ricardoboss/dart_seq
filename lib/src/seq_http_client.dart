import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:dart_seq/src/seq_client.dart';
import 'package:dart_seq/src/seq_client_exception.dart';
import 'package:dart_seq/src/seq_event.dart';
import 'package:dart_seq/src/seq_http_client_configuration.dart';
import 'package:dart_seq/src/seq_response.dart';

class SeqHttpClient implements SeqClient {
  final http.Client client;

  final SeqHttpClientConfiguration _configuration;
  final Uri _endpoint;

  String? _minimumLevelAccepted;

  SeqHttpClient(this._configuration)
      : client = http.Client(),
        _endpoint = Uri.parse("${_configuration.host}/api/events/raw");

  @override
  String? get minimumLevelAccepted => _minimumLevelAccepted;

  @override
  Future<void> sendEvents(List<SeqEvent> events) async {
    final body = collapseEvents(events);
    if (body.isEmpty) return;

    final response = await sendRequest(body);
    await handleResponse(response);
  }

  String collapseEvents(List<SeqEvent> events) =>
      events.reversed.map(jsonEncode).join("\n");

  Future<http.Response> sendRequest(String body) async {
    final apiKey = _configuration.apiKey;
    var tries = 0;

    http.Response? response;
    Object? lastException;

    do {
      try {
        response = await http.post(
          _endpoint,
          headers: {
            'Content-Type': 'application/vnd.serilog.clef',
            if (apiKey != null) 'X-Seq-ApiKey': apiKey,
          },
          body: body,
        );
      } catch (e) {
        lastException = e;
      }
    } while (![201, 429].contains(response?.statusCode) &&
        ++tries < _configuration.maxRetries);

    if (lastException != null) {
      throw lastException;
    }

    return response!;
  }

  Future<void> handleResponse(http.Response response) async {
    final json = jsonDecode(response.body);
    final seqResponse = SeqResponse.fromJson(json);

    if (response.statusCode == 201) {
      if (seqResponse.minimumLevelAccepted != _minimumLevelAccepted) {
        _minimumLevelAccepted = seqResponse.minimumLevelAccepted;
      }

      return;
    }

    final problem = seqResponse.error ?? 'no problem details known';

    throw switch (response.statusCode) {
      400 => SeqClientException("The request was malformed: $problem"),
      401 => SeqClientException("Authorization is required: $problem"),
      403 => SeqClientException(
          "The provided credentials don't have ingestion permission: $problem"),
      413 => SeqClientException(
          "The payload itself exceeds the configured maximum size: $problem"),
      429 => SeqClientException("Too many requests"),
      500 => SeqClientException(
          "An internal error prevented the events from being ingested; check Seq's diagnostic log for more information: $problem"),
      503 => SeqClientException(
          "The Seq server is starting up and can't currently service the request, or, free storage space has fallen below the minimum required threshold; this status code may also be returned by HTTP proxies and other network infrastructure when Seq is unreachable: $problem"),
      _ => SeqClientException("Unexpected status code. Error: $problem"),
    };
  }
}
