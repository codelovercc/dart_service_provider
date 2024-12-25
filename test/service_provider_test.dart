import 'package:dart_service_provider/dart_service_provider.dart';
import 'package:test/test.dart';

void main() {
  group('Service Provider', () {
    // 后期新增测试时，不要改动这里的代码，请通过新的测试组来测试新的功能
    late ServiceCollection services;
    late ServiceProvider serviceProvider;
    setUp(() {
      services = ServiceCollection()
        // 普通添加
        ..addSingleton<IMySingletonService, MySingletonService>((_) => MySingletonService())
        ..addSingletonInstance<IMySingletonService, MySingletonServiceInstanced>(MySingletonServiceInstanced())
        ..addSingleton<IMySingletonService1, MySingletonService1>((_) => MySingletonService1())
        ..addScoped<IMyScopedService, MyScopedService>((_) => MyScopedService())
        ..addScoped<IMyScopedService, MyScopedService1>((_) => MyScopedService1())
        ..addTransient<IMyTransientService, MyTransientService>((_) => MyTransientService())

        // 尝试添加单例服务
        ..tryAddSingleton<MySingletonServiceForTryAdd, MySingletonServiceForTryAdd>(
            (_) => MySingletonServiceForTryAdd())
        ..tryAddSingleton<MySingletonServiceForTryAdd, MySingletonServiceForTryAdd>(
            (_) => MySingletonServiceForTryAdd())
        ..tryAddSingletonInstance<MySingletonServiceInstancedForTryAdd, MySingletonServiceInstancedForTryAdd>(
            MySingletonServiceInstancedForTryAdd())
        ..tryAddSingletonInstance<MySingletonServiceInstancedForTryAdd, MySingletonServiceInstancedForTryAdd>(
            MySingletonServiceInstancedForTryAdd())

        // 尝试添加作用域服务
        ..tryAddScoped<MyScopedServiceForTryAdd, MyScopedServiceForTryAdd>((_) => MyScopedServiceForTryAdd())
        ..tryAddScoped<MyScopedServiceForTryAdd, MyScopedServiceForTryAdd>((_) => MyScopedServiceForTryAdd())

        // 尝试添加瞬时服务
        ..tryAddTransient<MyTransientServiceForTryAdd, MyTransientServiceForTryAdd>(
            (_) => MyTransientServiceForTryAdd())
        ..tryAddTransient<MyTransientServiceForTryAdd, MyTransientServiceForTryAdd>(
            (_) => MyTransientServiceForTryAdd())

        // 添加非重复实现类型的可枚举服务
        ..tryAddEnumerable<IMyEnumerableService, MyEnumerableService1>(
            ServiceDescriptor.scoped(factory: (_) => MyEnumerableService1()))
        ..tryAddEnumerable<IMyEnumerableService, MyEnumerableService2>(
            ServiceDescriptor.scoped(factory: (_) => MyEnumerableService2()))
        ..tryAddEnumerable<IMyEnumerableService, MyEnumerableService2>(
            ServiceDescriptor.scoped(factory: (_) => MyEnumerableService2()))
        ..tryAddEnumerable<IMyEnumerableService, MyEnumerableService3>(
            ServiceDescriptor.scoped(factory: (_) => MyEnumerableService3()))

        // 添加依赖于其它服务的服务
        ..addScoped<MyScopedDependencyService, MyScopedDependencyService>(
          (p) => MyScopedDependencyService(
            singletonService: p.getRequiredService<IMySingletonService>(),
            scopedService: p.getRequiredService<IMyScopedService>(),
            transientService: p.getRequiredService<IMyTransientService>(),
          ),
        )
        ..addSingleton<MyInvalidScopedDependencySingletonService, MyInvalidScopedDependencySingletonService>(
          (p) => MyInvalidScopedDependencySingletonService(
            scopedService: p.getRequiredService<IMyScopedService>(),
          ),
        )
        // 添加一个作用域的MyServiceForDecorate服务
        ..addScoped<MyServiceForDecorate, MyServiceForDecorate>((_) => MyServiceForDecorate())
        // 将MyServiceForDecorate服务改变为单例实例服务
        ..decorate(
          MyServiceForDecorate,
          (oldDescriptor) => ServiceDescriptor<MyServiceForDecorate, MyServiceForDecorate>.instance(
            serviceInstance: MyServiceForDecorate(),
          ),
        )
        ..addScoped<MyScopedDisposableService, MyScopedDisposableService>((_) => MyScopedDisposableService())
        ..addScoped<MyScopedAsyncDisposableService, MyScopedAsyncDisposableService>(
            (_) => MyScopedAsyncDisposableService());
      print("ServiceCollection ${services.hashCode} configured");
      serviceProvider = services.buildServiceProvider();
    });
    test("ServiceCollection should contains two IMySingletonService descriptor according configure", () {
      expect(services.where((e) => e.serviceType == IMySingletonService).length, equals(2));
    });
    test("IMySingletonService should be MySingletonServiceInstanced according configure order", () {
      final singleton = serviceProvider.getRequiredService<IMySingletonService>();
      expect(singleton, isA<MySingletonServiceInstanced>());
    });
    test("Singleton service should be the same in different scope", () {
      final singleton = serviceProvider.getRequiredService<IMySingletonService>();
      final scope = serviceProvider.createScope();
      final singletonInScope = scope.serviceProvider.getRequiredService<IMySingletonService>();
      expect(singletonInScope, same(singleton));
      scope.dispose();
    });
    test("Scoped service should error when provide it from root", () {
      expect(() => serviceProvider.getService(IMyScopedService), throwsA(isA<InvalidScopeError>()));
    });
    test("Transient service should not be the same", () {
      final scope = serviceProvider.createScope();
      final scope1 = scope.serviceProvider.createScope();
      final list = [
        serviceProvider.getRequiredService<IMyTransientService>(),
        serviceProvider.getRequiredService<IMyTransientService>(),
        serviceProvider.getRequiredService<IMyTransientService>(),
        scope.serviceProvider.getRequiredService<IMyTransientService>(),
        scope.serviceProvider.getRequiredService<IMyTransientService>(),
        scope.serviceProvider.getRequiredService<IMyTransientService>(),
        scope1.serviceProvider.getRequiredService<IMyTransientService>(),
        scope1.serviceProvider.getRequiredService<IMyTransientService>(),
        scope1.serviceProvider.getRequiredService<IMyTransientService>(),
      ];
      final set = list.toSet();
      expect(set.length, equals(list.length));
      for (final s in set) {
        s.dispose();
      }
    });
    test("Try add service should add only first one descriptor to service collection per service type", () {
      expect(services.singleWhere((e) => e.serviceType == MySingletonServiceForTryAdd),
          isA<ServiceDescriptor<MySingletonServiceForTryAdd, MySingletonServiceForTryAdd>>());
      expect(services.singleWhere((e) => e.serviceType == MySingletonServiceInstancedForTryAdd),
          isA<ServiceDescriptor<MySingletonServiceInstancedForTryAdd, MySingletonServiceInstancedForTryAdd>>());
      expect(services.singleWhere((e) => e.serviceType == MyScopedServiceForTryAdd),
          isA<ServiceDescriptor<MyScopedServiceForTryAdd, MyScopedServiceForTryAdd>>());
      expect(services.singleWhere((e) => e.serviceType == MyTransientServiceForTryAdd),
          isA<ServiceDescriptor<MyTransientServiceForTryAdd, MyTransientServiceForTryAdd>>());
    });

    test("Try add enumerable service should not add duplicate implementation type", () {
      final list = services.where((e) => e.serviceType == IMyEnumerableService).map((e) => e.implementationType);

      /// 去除重复的实现类型
      final set = list.toSet();
      expect(set.length, equals(list.length));
    });
    test("Service that depend other service should provide correctly", () {
      final scope = serviceProvider.createScope();
      final s = scope.serviceProvider.getRequiredService<MyScopedDependencyService>();
      expect(s.scopedService, isA<IMyScopedService>());
      scope.dispose();
    });
    test("Singleton service that depend scoped service should cause error", () {
      final scope = serviceProvider.createScope();
      expect(() => scope.serviceProvider.getRequiredService<MyInvalidScopedDependencySingletonService>(),
          throwsA(isA<InvalidScopeError>()));
      scope.dispose();
    });
    test("Decorate a service should work", () {
      var ds = services.singleWhere((e) => e.serviceType == MyServiceForDecorate);
      expect(ds.lifeTime, equals(ServiceLifeTime.singleton));
      expect(ds.serviceInstance, isNotNull);
    });
    test("Singleton service should be disposed when root provider is disposed", () async {
      final p = services.buildServiceProvider();
      final s = p.getRequiredService<IMySingletonService1>();
      await p.disposeAsync();
      expect(s.disposed, isTrue);
    });
    test("Scoped service should dispose correctly", () {
      final scope = serviceProvider.createScope();
      final s = scope.serviceProvider.getRequiredService<MyScopedDisposableService>();
      scope.dispose();
      expect(s.disposed, isTrue);
    });
    test("AsyncDisposable service should work in synchronous method", () {
      final scope = serviceProvider.createScope();
      scope.serviceProvider.getRequiredService<MyScopedAsyncDisposableService>();
      scope.dispose();
    });
    test("Scoped service should dispose asynchronously correctly", () async {
      final scope = serviceProvider.createScope();
      final s = scope.serviceProvider.getRequiredService<MyScopedDisposableService>();
      await scope.disposeAsync();
      expect(s.disposed, isTrue);
    });
    test("Provider a optional service that does not exists should return null", () {
      final s = serviceProvider.getTypedService<NotAService>();
      expect(s, isNull);
    });
    test("Provider a required service that does not exists should throw error", () {
      expect(() => serviceProvider.getRequiredService<NotAService>(), throwsA(isA<ServiceNotFoundError>()));
    });
    test("Provide iterable services should work", () {
      final list = serviceProvider.getRequiredServices<IMySingletonService>().toList();
      expect(list.length, equals(2));
      final scope = serviceProvider.createScope();
      final list1 = scope.serviceProvider.getRequiredServices<IMyEnumerableService>().toList();
      expect(list1.length, equals(3));
      scope.dispose();
    });
    test("Provide iterable service should contains one if there is only one", () async {
      final scope = serviceProvider.createScope();
      final list = scope.serviceProvider.getRequiredServices<MyScopedAsyncDisposableService>().toList();
      expect(list.length, equals(1));
      await scope.disposeAsync();
    });
    test("Provide iterable service should be empty if the service does not exists", () {
      final list = serviceProvider.getTypedServices<NotAService>().toList();
      expect(list.isEmpty, isTrue);
    });
    test("Provider required iterable service should throw error when the service does not exists", () {
      expect(() => serviceProvider.getRequiredServices<NotAService>(), throwsA(isA<ServiceNotFoundError>()));
    });
    test("Build in IServiceProvider services should follow its scope", () {
      final p = serviceProvider.getRequiredService<IServiceProvider>();
      // 从根容器中解析作用域服务会抛出错误，以此来证实根容器中解析的IServiceProvider也是根容器
      expect(() => p.getRequiredService<IMyScopedService>(), throwsA(isA<InvalidScopeError>()));
      final scope = serviceProvider.createScope();
      final p1 = scope.serviceProvider.getRequiredService<IServiceProvider>();
      expect(p1, same(scope.serviceProvider));
      scope.dispose();
    });
    test("Build in IServiceProvider services should work well for provide service", () {
      final p = serviceProvider.getRequiredService<IServiceProvider>();
      p.getRequiredService<IMySingletonService>();
      p.getRequiredService<IMyTransientService>();

      final scope = p.createScope();
      scope.serviceProvider.getRequiredService<IMyScopedService>();
      scope.dispose();
    });
    test("Build in IServiceProviderIsService should be the same in different scope as it's a singleton", () {
      final s = serviceProvider.getRequiredService<IServiceProviderIsService>();
      final scope = serviceProvider.createScope();
      final s1 = scope.serviceProvider.getRequiredService<IServiceProviderIsService>();
      expect(s1, same(s));
      scope.dispose();
    });
    test("Build in IServiceProviderIsService should work", () {
      final s = serviceProvider.getRequiredService<IServiceProviderIsService>();
      final r = s.isService(IMyScopedService);
      expect(r, isTrue);
    });
    test("Build in IServiceScopeFactory should be the same in different scope as it's a singleton", () {
      final s = serviceProvider.getRequiredService<IServiceScopeFactory>();
      final scope = serviceProvider.createScope();
      final s1 = scope.serviceProvider.getRequiredService<IServiceScopeFactory>();
      expect(s1, same(s));
      scope.dispose();
    });
    test("Build in IServiceScopeFactory should work", () {
      final s = serviceProvider.getRequiredService<IServiceScopeFactory>();
      final scope = s.createScope();
      scope.serviceProvider.getRequiredService<IMyScopedService>();
      scope.dispose();
    });
    test("Should throw error when scope has been disposed", () {
      final scope = serviceProvider.createScope();
      final p = scope.serviceProvider;
      scope.dispose();
      expect(() => scope.serviceProvider, throwsA(isA<ObjectDisposedError>()));
      expect(() => scope.serviceProvider.createScope(), throwsA(isA<ObjectDisposedError>()));
      expect(() => p.createScope(), throwsA(isA<ObjectDisposedError>()));
      expect(() => p.getService(NotAService), throwsA(isA<ObjectDisposedError>()));
      expect(() => p.getServices(NotAService), throwsA(isA<ObjectDisposedError>()));
    });
    tearDown(() => serviceProvider.dispose());
  });
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

class MySingletonServiceInstanced implements IMySingletonService {
  MySingletonServiceInstanced() {
    print("MySingletonServiceInstanced $hashCode constructing");
  }

  @override
  void dispose() {
    print("MySingletonServiceInstanced $hashCode disposing");
  }
}

abstract interface class IMySingletonService1 implements IAsyncDisposable {
  bool disposed = false;
}

class MySingletonService1 implements IMySingletonService1 {
  MySingletonService1() {
    print("MySingletonService1 $hashCode constructing");
  }

  @override
  Future<void> disposeAsync() {
    disposed = true;
    print("MySingletonService1 $hashCode disposing asynchronous");
    return Future<void>.value();
  }

  @override
  bool disposed = false;
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

class MyScopedService1 implements IMyScopedService {
  MyScopedService1() {
    print("MyScopedService1 $hashCode constructing");
  }

  @override
  Future<void> disposeAsync() {
    print("MyScopedService1 $hashCode disposing asynchronous");
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

class MySingletonServiceForTryAdd {}

class MySingletonServiceInstancedForTryAdd {}

class MyScopedServiceForTryAdd {}

class MyTransientServiceForTryAdd {}

abstract interface class IMyEnumerableService implements IAsyncDisposable {}

class MyEnumerableService1 implements IMyEnumerableService {
  MyEnumerableService1() {
    print("MyEnumerableService1 $hashCode constructing");
  }

  @override
  Future<void> disposeAsync() {
    print("MyEnumerableService1 $hashCode disposing asynchronous");
    return Future<void>.value();
  }
}

class MyEnumerableService2 implements IMyEnumerableService {
  MyEnumerableService2() {
    print("MyEnumerableService2 $hashCode constructing");
  }

  @override
  Future<void> disposeAsync() {
    print("MyEnumerableService2 $hashCode disposing asynchronous");
    return Future<void>.value();
  }
}

class MyEnumerableService3 implements IMyEnumerableService {
  MyEnumerableService3() {
    print("MyEnumerableService3 $hashCode constructing");
  }

  @override
  Future<void> disposeAsync() {
    print("MyEnumerableService3 $hashCode disposing asynchronous");
    return Future<void>.value();
  }
}

/// 用于测试作用域服务依赖了单例服务、其它作用域服务和瞬时服务
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

/// 用于测试单例服务依赖了作用域服务，在从服务容器中获取时，这会抛出非法作用域异常
class MyInvalidScopedDependencySingletonService {
  final IMyScopedService scopedService;

  MyInvalidScopedDependencySingletonService({required this.scopedService}) {
    print("MyInvalidScopedDependencyService should never instanced by IServiceProvider");
  }
}

/// 用于测试[EditableServiceCollectionExtensions.decorate]方法来修改已经添加的服务
class MyServiceForDecorate {}

class MyScopedAsyncDisposableService implements IAsyncDisposable {
  MyScopedAsyncDisposableService() {
    print("MyScopedAsyncDisposableService $hashCode constructing");
  }

  @override
  Future<void> disposeAsync() {
    print("MyScopedAsyncDisposableService $hashCode disposing asynchronous");
    return Future<void>.value();
  }
}

/// 用于测试同时实现了[IDisposable]和[IAsyncDisposable]的服务释放
class MyScopedDisposableService implements IDisposable, IAsyncDisposable {
  bool disposed = false;

  MyScopedDisposableService() {
    print("MyScopedDisposableService $hashCode constructing");
  }

  @override
  void dispose() {
    if (disposed) {
      return;
    }
    disposed = true;
    print("MyScopedDisposableService $hashCode disposing");
  }

  @override
  Future<void> disposeAsync() {
    if (disposed) {
      return Future<void>.value();
    }
    disposed = true;
    print("MyScopedDisposableService $hashCode disposing asynchronous");
    return Future<void>.value();
  }
}

class NotAService {}
