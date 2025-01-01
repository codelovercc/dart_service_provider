<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages). 
-->

# dart_service_provider

[![pub package](https://img.shields.io/pub/v/dart_service_provider?logo=dart&logoColor=00b9fc)](https://pub.dev/packages/dart_service_provider)
[![CI](https://img.shields.io/github/actions/workflow/status/codelovercc/dart_service_provider/dart.yml?branch=main&logo=github-actions&logoColor=white)](https://github.com/codelovercc/dart_service_provider/actions)
[![Last Commits](https://img.shields.io/github/last-commit/codelovercc/dart_service_provider?logo=git&logoColor=white)](https://github.com/codelovercc/dart_service_provider/commits/main)
[![Pull Requests](https://img.shields.io/github/issues-pr/codelovercc/dart_service_provider?logo=github&logoColor=white)](https://github.com/codelovercc/dart_service_provider/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/codelovercc/dart_service_provider?logo=github&logoColor=white)](https://github.com/codelovercc/dart_service_provider)
[![License](https://img.shields.io/github/license/codelovercc/dart_service_provider?logo=open-source-initiative&logoColor=green)](https://github.com/codelovercc/dart_service_provider/blob/main/LICENSE)

An services dependency provider, like dependency inject, easy to learn and easy to use.

## Features

Provide services life time control with singleton, scoped, transient.

## Getting started

```dart
void main() {
  final services = ServiceCollection()
  // add the default logging services
    ..addLogging()
    ..addSingleton<IMySingletonService, MySingletonService>((_) => MySingletonService())
    ..addScoped<IMyScopedService, MyScopedService>((_) => MyScopedService())
    ..addTransient<IMyTransientService, MyTransientService>((_) => MyTransientService())
    ..addScoped<MyScopedDependencyService, MyScopedDependencyService>(
          (p) =>
          MyScopedDependencyService(
            singletonService: p.getRequiredService<IMySingletonService>(),
            scopedService: p.getRequiredService<IMyScopedService>(),
            transientService: p.getRequiredService<IMyTransientService>(),
          ),
    );

  final serviceProvider = services.buildServiceProvider();
  final singletonService = serviceProvider.getRequiredService<IMySingletonService>();
  final transientService = serviceProvider.getRequiredService<IMyTransientService>();
  // Scoping
  final scope = serviceProvider.createScope();
  final singletonService2 = scope.serviceProvider.getRequiredService<IMySingletonService>();
  assert(identical(singletonService, singletonService2));
  final scopedService = scope.serviceProvider.getRequiredService<IMyScopedService>();
  final scopedService2 = scope.serviceProvider.getRequiredService<IMyScopedService>();
  assert(identical(scopedService, scopedService2));
  final transientService2 = scope.serviceProvider.getRequiredService<IMyTransientService>();
  assert(!identical(transientService, transientService2));
  // Always dispose the scope when you don't need it anymore.
  // This will cleanup any resources use by this scope and the services in this scope.
  // There is a `disposeAsync()` method for asynchronous calls.
  // Note that: `dispose` method from interface `IDisposable` and `disposeAsync` from interface `IAsyncDisposable`
  // Any services that it implements `IDisposable` or `IAsyncDisposable` and constructed by `IServiceProvider` will be disposed when its life is end automatically.
  scope.dispose();

  // Always dispose the ServiceProvider when you don't need it anymore.
  // There also is a `disposeAsync()` method
  serviceProvider.dispose();
}


abstract interface class IMySingletonService implements IDisposable {}

class MySingletonService implements IMySingletonService {
  MySingletonService() {
    print("MySingletonService $hashCode constructing");
  }

  @override
  void dispose() {
    print("MySingletonService $hashCode disposing");
  }
}

abstract interface class IMyScopedService implements IAsyncDisposable {}

class MyScopedService implements IMyScopedService {
  MyScopedService() {
    print("MyScopedService $hashCode constructing");
  }

  @override
  Future<void> disposeAsync() {
    print("MyScopedService $hashCode disposing asynchronous");
    return Future<void>.value();
  }
}

abstract interface class IMyTransientService implements IDisposable {}

class MyTransientService implements IMyTransientService {
  MyTransientService() {
    print("MyTransientService $hashCode constructing");
  }

  @override
  void dispose() {
    print("MyTransientService $hashCode disposing");
  }
}

class MyScopedDependencyService {
  final IMySingletonService singletonService;
  final IMyScopedService scopedService;
  final IMyTransientService transientService;

  MyScopedDependencyService(
      {required this.singletonService, required this.scopedService, required this.transientService}) {
    print("MyDependencyService $hashCode constructing with "
        "IMySingletonService ${singletonService.hashCode}, "
        "IMyScopedService ${scopedService.hashCode}, "
        "IMyTransientService ${transientService.hashCode}");
  }
}
```

## Usage

```dart
void main() {
  final services = ServiceCollection();
  services.addSingleton<MyService, MyService>((_) => MyService());
  final rootProvider = services.buildServiceProvider();
  final myService = rootProvider.getRequiredService<MyService>();
  // myService.foo()
}

class MyService {}
```

### Logging

#### Enable default logging

```dart

final services = ServiceCollection()
// add the default logging services
  ..addLogging();
```

#### Custom logging:

```dart

final services = ServiceCollection()
// add the default logging services
  ..addLogging((loggingBuilder) {
    // Custom your logging services
  });
```

How to custom logging services:

- Implement `ILoggerFactory` interface, then call `addLogging` extension method on
  `ServiceCollection`, Specify the `config` argument.
- Optional implement `ILogger` and `ILogger4` interfaces, implement `ILogger4` is recommended.
- If you implementations does not need `LoggerOptions` service, please
  call the `LoggingBuilderExtensions.removeOptions` extension method to delete it.

## Environment

Provide environment service.

```dart
void main() {
  final services = ServiceCollection();
  // Add environment service
  services.addEnvironment<Evironment>(Environment(name: Environments.production));
  final provider = services.buildServiceProvider();
  final env = provider.getRequiredService<IEnvironment>();
  print(env.isProduction); // true
}
```

You can detect the environment and change the application behavior at runtime.

## Additional information

If you have any issues or suggests please redirect
to [repo](https://github.com/codelovercc/dart_service_provider)
or [send an email](mailto:codelovercc@gmail.com) to me.

## Todo

Use annotations and code generator to support real Dependency inject.
