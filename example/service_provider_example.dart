import 'package:dart_service_provider/dart_service_provider.dart';

void main() {
  final services = ServiceCollection()
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
  // Any service that it implements `IDisposable` or `IAsyncDisposable` and construct by `IServiceProvider` will be disposed when its life is end automatically.
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