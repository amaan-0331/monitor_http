<div align="center">

# Monitor HTTP

[![pub.dev](https://img.shields.io/pub/v/monitor_http.svg?label=pub.dev)](https://pub.dev/packages/monitor_http)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

</div>

Monitor HTTP is a tiny helper package that wraps the `http` client and logs
requests and responses through the `monitor` package automatically.

## Installation

```yaml
dependencies:
  monitor_http: ^0.1.0
```

```bash
flutter pub add monitor_http
```

## Usage

Initialize Monitor once at app startup:

```dart
import 'package:flutter/material.dart';
import 'package:monitor/monitor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Monitor.init();

  runApp(const MyApp());
}
```

Create a tracked HTTP client:

```dart
import 'package:http/http.dart' as http;
import 'package:monitor_http/monitor_http.dart';

final http.Client client = createMonitorClient();

final response = await client.get(
  Uri.parse('https://api.example.com/users'),
);
```

You can also wrap an existing client:

```dart
final http.Client client = MonitorHttpClient(
  inner: http.Client(),
);
```

All requests made with the client will appear in the Monitor viewer and logs.

## License

Apache-2.0. See `LICENSE` for details.
