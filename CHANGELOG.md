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
