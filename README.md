`dart_seq` is a powerful and versatile logging solution for Dart, designed to simplify the process of sending log entries to a Seq server.
It supports all platforms supported by Dart, including Windows, Android, iOS, macOS, and Web, making it a versatile choice for logging in various Dart applications.

## Features

- **Logging to Seq Server**: `dart_seq` seamlessly integrates with Seq servers, enabling you to send log entries directly to your Seq instance. This allows you to centralize and analyze logs efficiently, aiding in troubleshooting, debugging, and monitoring your Dart applications.
- **Cross-Platform Support**: With `dart_seq`, you can enjoy consistent logging capabilities across all Dart-supported platforms. It leverages the inherent cross-platform capabilities of Dart, making it easy to adopt and utilize in your applications, regardless of the target platform.
- **Customizable Seq Client and Caching Implementations**: `dart_seq` provides an intuitive and flexible interface to customize your Seq client and caching implementations. This enables you to tailor the logging behavior to your specific requirements and preferences, adapting the library to various use cases and scenarios in your Dart applications.
- **Batch Sending of Events**: `dart_seq` optimizes log transmission by sending events to Seq in batches. This helps minimize network overhead and improves overall logging performance, especially in high-traffic scenarios.
- **Automatic Retry Mechanism**: The library automatically retries failed requests to the Seq server, except in the case of 429 (Too Many Requests) responses. This built-in resilience ensures that log entries are reliably delivered, even in the face of intermittent network connectivity or temporary server unavailability.
- **Minimum Log Level Enforcement**: `dart_seq` keeps track of the server-side configured minimum log level and discards events that fall below this threshold. This feature helps reduce unnecessary log entries and ensures that only relevant and significant events are forwarded to the Seq server.

With `dart_seq`, logging in your Dart applications becomes a breeze, ensuring that your logs are efficiently delivered to Seq servers across multiple platforms.
The library's batch sending, automatic retry, and minimum log level enforcement features enhance the logging experience and provide robustness and flexibility to your logging infrastructure.

## Getting started

To start using dart_seq in your Dart application, follow these steps:

1. Install the library using `dart pub add dart_seq`
2. Import the package: `import 'package:dart_seq/dart_seq.dart';`
3. Instantiate the `SeqLogger` class
4. Start logging

## Usage

```dart
// configure your logger
final logger = SeqLogger.http(
  host: "http://localhost:5341",
  globalContext: {
    "Environment": Platform.environment,
  }
);

// add log events
logger.log(SeqLogLevel.information, "test, dart: {Dart}", {
"Dart": Platform.version,
});

// don't forget to flush your logs at the end!
logger.flush();
```

## Additional information

Feature requests and bug reports should be reported using [GitHub issues](https://github.com/ricardoboss/dart_seq/issues).
