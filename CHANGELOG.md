## 3.0.0 ([#16](https://github.com/ricardoboss/dart_seq/pull/16))

* **Breaking:** `SeqLogger.log()` - `exception` and `context` changed from positional to named parameters
* **Breaking:** `SeqLogger` convenience methods (`verbose`, `debug`, `info`, `warning`, `error`, `fatal`) - same positional-to-named migration
* **Breaking:** `SeqEvent` constructor - all parameters except `timestamp` are now named
* **Breaking:** `SeqClient.sendEvents()` - return type changed from `Future<void>` to `Future<List<SeqEventResult>>`
* `SeqEventResult` class - per-event success/failure result with `isPermanent` flag
* `throwOnError` flag ([#14](https://github.com/ricardoboss/dart_seq/issues/14)) - when `false` (default), flush errors are caught and reported via `onDiagnosticLog`; when `true`, they propagate to caller
* `onFlushError` callback - handler invoked when flush fails; receives failed events and error, returns events to re-queue
* `SeqClientException.isRetryable` - allows implementations to signal non-retryable errors (e.g. 413 Payload Too Large)
* OpenTelemetry / distributed tracing fields ([#10](https://github.com/ricardoboss/dart_seq/issues/10)) - 7 new CLEF fields on `SeqEvent`: `traceId` (`@tr`), `spanId` (`@sp`), `parentSpanId` (`@ps`), `spanStart` (`@st`), `scope` (`@sc`), `resourceAttributes` (`@ra`), `spanKind` (`@sk`)
* Known Seq CLEF keys (`@tr`, `@sp`, etc.) are no longer double-escaped in context
* Exception formatting ([#11](https://github.com/ricardoboss/dart_seq/issues/11)) - `@x` field now uses `toString()` with safe fallback instead of `Error.safeToString()`

## 2.0.1

* Prevent multiple flushes while flushing

## 2.0.0

* More documentation
* Moved `SeqHttpClient` to its own package @ https://pub.dev/packages/dart_seq_http_client

## 1.0.0

* First stable release 🎉
* `SeqClientException` now extends `Exception`
* The static methods returning `SeqEvent` instances are now factories
* Lots of documentation and some tests

## 1.0.0-pre.3

* No changes; just a version bump to test the release workflow

## 1.0.0-pre.2

* No changes; just a version bump to test the release workflow

## 1.0.0-pre.1

* First stable release candidate 🎉
* `SeqClientException` now extends `Exception`
* The static methods returning `SeqEvent` instances are now factories
* Lots of documentation and some tests

## 0.1.2

* Expose `backoff` property via `SeqLogger.http` factory

## 0.1.1

* Added `diagnosticLog` and `onDiagnosticLog` to `SeqLogger` to track internal logs

## 0.1.0

* Changed `SeqCache` interface to differentiate between retrieving and removing events
* The `SeqClient.sendEvents` method now takes a `List` instead of a `Stream`
* The `SeqClientException` can now optionally hold a causing exception and stack trace
* The `SeqHttpClient` wraps exceptions from the `http` package in `SeqClientException`s
* Events are now only removed from cache when they have actually been sent

## 0.0.5

* Added ability to turn off auto flushing

## 0.0.4

* Some small optimizations
* Implemented linear backoff for `SeqHttpClient` retries

## 0.0.3

* Downgraded `http` dependency to at most `^0.13.3` for more compatibility

## 0.0.2

* Remove dependency on `flutter` SDK
* The `context` parameter on `SeqEvent.<level>()` methods is now optional
* Added more convenience methods to `SeqLogger`

## 0.0.1

* Initial release 🎉
* Added `SeqLogger` with support for logging to the HTTP ingestion endpoint of an Seq server
