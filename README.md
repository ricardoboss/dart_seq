![GitHub License](https://img.shields.io/github/license/ricardoboss/dart_seq)
![Pub Version](https://img.shields.io/pub/v/dart_seq)
![Pub Points](https://img.shields.io/pub/points/dart_seq)
![Pub Likes](https://img.shields.io/pub/likes/dart_seq)
![Pub Popularity](https://img.shields.io/pub/popularity/dart_seq)

`dart_seq` is a powerful and versatile logging solution for Dart, designed to simplify the process of sending log entries to a Seq server. It supports all platforms supported by Dart, including Windows, Android, iOS, macOS, Linux and Web, making it a versatile choice for logging in various Dart applications.

## Features

- **Logging to Seq Server**: `dart_seq` seamlessly integrates with Seq servers, enabling you to send log entries directly to your Seq instance. This allows you to centralize and analyze logs efficiently, aiding in troubleshooting, debugging, and monitoring your Dart applications.
- **Cross-Platform Support**: With `dart_seq`, you can enjoy consistent logging capabilities across all Dart-supported platforms. It leverages the inherent cross-platform capabilities of Dart, making it easy to adopt and utilize in your applications, regardless of the target platform.
- **Customizable Seq Client and Caching Implementations**: `dart_seq` provides an intuitive and flexible interface to customize your Seq client and caching implementations. This enables you to tailor the logging behavior to your specific requirements and preferences, adapting the library to various use cases and scenarios in your Dart applications.
- **Batch Sending of Events**: `dart_seq` optimizes log transmission by sending events to Seq in batches. This helps minimize network overhead and improves overall logging performance, especially in high-traffic scenarios.

With `dart_seq`, logging in your Dart applications becomes a breeze, ensuring that your logs are efficiently delivered to Seq servers across multiple platforms.

## Getting Started

To start using `dart_seq` in your Dart/Flutter application, follow these steps:

1. Install this library and the HTTP client: `dart pub add dart_seq dart_seq_http_client`
2. Instantiate client, cache and logger (see usage below)
3. Enjoy!

## Usage

> **Note**
> This library provides just the interfaces and scaffolding.
> To actually log events, you need to use a client implementation like
> [`dart_seq_http_client`](https://pub.dev/packages/dart_seq_http_client).

After the installation, you can use the library like this:

```dart
import 'package:dart_seq/dart_seq.dart';
import 'package:dart_seq_http_client/dart_seq_http_client.dart';

Future<void> main() async {
  // Use the HTTP client implementation to create a logger
  final logger = SeqHttpLogger.create(
    host: 'http://localhost:5341',
    globalContext: {
      'App': 'Example',
    },
  );

  // Log a message
  await logger.log(
    SeqLogLevel.information,
    'test, logged at: {Timestamp}',
    null,
    {
      'Timestamp': DateTime.now().toUtc().toIso8601String(),
    },
  );

  // Flush the logger to ensure all messages are sent
  await logger.flush();
}
```

which then can be viewed in your Seq instance:

![Seq Screenshot showing the logged message with metadata](https://raw.githubusercontent.com/ricardoboss/dart_seq/be3db3b777db9cf8791cf4d36f61d2b317122fef/doc/example_output.png)

## Additional information

- Feature requests and bug reports should be reported using [GitHub issues](https://github.com/ricardoboss/dart_seq/issues).
- Contributions are welcome! If you'd like to contribute, please follow the guidelines outlined in the [CONTRIBUTING.md](./CONTRIBUTING.md) file.

## License

`dart_seq` is licensed under the MIT License. See the [LICENSE](./LICENSE) file for more information.

This project is not affiliated with [Datalust](https://datalust.co/), the creators of Seq. The
library is an independent open-source project developed by the community for the community.
