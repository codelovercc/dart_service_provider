import 'dart:collection';

/// 服务生命周期
enum ServiceLifeTime {
  /// 单例，在相同根服务容器中中只会存在一个实例
  ///
  /// 在添加单例服务时，如果使用了现有实例添加到服务容器，那么该单例由使用者负责释放。
  singleton,

  /// 作用域的，在不同的作用域DI容器中实例不相同
  ///
  /// 作用域服务由服务容器释放。在不同的作用域中将创建不同的实例，在根服务容器中，不允许请求作用域服务，将抛出错误。
  scoped,

  /// 瞬时的，每次请求都会创建一个新的实例
  ///
  /// 每次请求瞬时服务时，都将创建一个新的实例。瞬时服务不由服务容器释放，从服务容器获取后，由其使用者进行释放。
  transient,
}

/// 对象已经被释放无法再被使用的错误。
class ObjectDisposedError extends StateError {
  ObjectDisposedError(super.message);
}

/// 表示在根作用域中获取作用域服务的错误
///
/// 作用域服务不能在根服务容器中获取，需要使用服务提供器创建一个作用域再进行获取。
class InvalidScopeError extends StateError {
  InvalidScopeError(super.message);
}

/// 表示服务未找到的错误
class ServiceNotFoundError extends StateError {
  /// 未注册的服务类型
  final Type serviceType;

  ServiceNotFoundError(super.message, this.serviceType);
}

/// 表示需要释放资源的接口
abstract interface class IDisposable {
  /// 释放需要手动释放的资源
  ///
  /// 注意在释放资源时要确保不抛出任何异常
  void dispose();
}

/// 用于异步释放资源
///
/// 由于在同步的[IDisposable]中，无法等待[disposeAsync]完成，因此慎重使用该接口，在使用时要测试确保[disposeAsync]在应用结束前执行完成清理。
abstract interface class IAsyncDisposable {
  /// 异步释放需要手动释放的资源
  ///
  /// 注意在释放资源时要确保不抛出任何异常
  Future<void> disposeAsync();
}

/// 服务集合接口，用于配置和添加服务
abstract interface class IServiceCollection
    implements List<ServiceDescriptor> {}

/// 服务提供器接口
///
/// 该接口同时为内置的服务，在根服务容器中请求[IServiceProvider]时，将获取到根[ServiceProvider]，在作用域中获取时，为作用域关联的[IServiceProvider]
abstract interface class IServiceProvider {
  /// 使用服务类型来获取服务
  ///
  /// 当[serviceType]没有注册时，返回`null`
  Object? getService(Type serviceType);

  /// 使用服务类型来获取相同服务类型的服务实现实例
  ///
  /// 当[serviceType]没有注册时，返回空的枚举
  Iterable<Object> getServices(Type serviceType);
}

/// 用于检测一个类型是否被注册为服务
///
/// 该服务为内置的单例服务
abstract interface class IServiceProviderIsService {
  /// 检测[serviceType]是否被注册为服务
  ///
  /// 如果[serviceType]被注册为服务则返回`true`，否则返回`false`
  bool isService(Type serviceType);
}

/// 服务作用域
abstract interface class IServiceScope
    implements IDisposable, IAsyncDisposable {
  /// 获取与该作用域关联的服务提供器
  IServiceProvider get serviceProvider;
}

/// 服务作用域工厂
///
/// 该服务为内置的单例服务
abstract interface class IServiceScopeFactory {
  /// 创建一个作用域
  IServiceScope createScope();
}

/// 服务工厂
///
/// [T] 为返回类型，可以是服务类型，也可以是服务实现类型
///
/// 返回[T]类型的实例，该工厂方法接收一个[IServiceProvider]做为参数。
///
/// 如果服务是[ServiceLifeTime.singleton]，那么[IServiceProvider]为根服务提供器，如果单例服务依赖了作用域服务，
// /// 则瞬时服务需要依赖[IServiceProvider]服务，并在内部创建一个新的作用域来获取其它作用域服务；
/// 如果服务是[ServiceLifeTime.scoped]，那么[IServiceProvider]为对应作用域的服务提供器；
/// 如果服务是[ServiceLifeTime.transient]，那么[IServiceProvider]为根服务提供器，如果瞬时服务依赖了作用域服务，
/// 则瞬时服务需要依赖[IServiceProvider]服务，并在内部创建一个新的作用域来获取其它作用域服务。
typedef ServiceFactory<T> = T Function(IServiceProvider provider);

/// 服务描述器
///
/// - [TService] 服务类型
/// - [TImplementation] 服务的实现类型
///
/// [TImplementation]可以是[TService]的子类或[TService]类型。
class ServiceDescriptor<TService, TImplementation extends TService> {
  /// 服务类型
  final Type serviceType;

  /// 服务实现类型，可能与[serviceType]相同
  final Type implementationType;

  /// 服务的生命周期
  final ServiceLifeTime lifeTime;

  /// 服务的实例，单例服务专用
  final TService? serviceInstance;

  /// 服务的工厂，只有在使用服务实例创建单例服务描述器时，该工厂才会为`null`。
  final ServiceFactory<TImplementation>? factory;

  const ServiceDescriptor._({required this.lifeTime, required this.factory})
      : serviceType = TService,
        implementationType = TImplementation,
        serviceInstance = null,
        assert(TService != Object, "Service type can not be type `Object`.");

  /// 使用一个服务实例来创建单例服务描述器
  ///
  /// 使用现有实例的单例服务不由服务容器释放，调用者需要自动释放
  const ServiceDescriptor.instance({required TService this.serviceInstance})
      : serviceType = TService,
        implementationType = TImplementation,
        lifeTime = ServiceLifeTime.singleton,
        factory = null,
        assert(TService != Object, "Service type can not be type `Object`.");

  /// 使用现有实例创建一个单例的服务描述器
  ///
  /// 使用[factory]服务工厂添加的服务始终由服务容器释放。
  const ServiceDescriptor.singleton(
      {required ServiceFactory<TImplementation> factory})
      : this._(lifeTime: ServiceLifeTime.singleton, factory: factory);

  /// 创建一个作用域服务描述器
  ///
  /// 作用域服务由服务容器释放。在不同的作用域中将创建不同的实例，在根服务容器中，不允许请求作用域服务，将抛出错误。
  ///
  /// 使用[factory]服务工厂添加的服务始终由服务容器释放。
  const ServiceDescriptor.scoped(
      {required ServiceFactory<TImplementation> factory})
      : this._(lifeTime: ServiceLifeTime.scoped, factory: factory);

  /// 创建一个瞬时服务描述器
  ///
  /// 每次请求瞬时服务时，都将创建一个新的实例。瞬时服务不由服务容器释放，从服务容器获取后，由其使用者进行释放。
  const ServiceDescriptor.transient(
      {required ServiceFactory<TImplementation> factory})
      : this._(lifeTime: ServiceLifeTime.transient, factory: factory);

  @override
  String toString() {
    var buff = StringBuffer("ServiceType: $serviceType LifeTime: $lifeTime ");
    if (serviceInstance != null) {
      buff.write("ImplementationType: ${serviceInstance.runtimeType}");
    } else {
      buff.write("ImplementationType: $implementationType Factory: $factory");
    }

    return buff.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceDescriptor &&
          runtimeType == other.runtimeType &&
          serviceType == other.serviceType &&
          implementationType == other.implementationType &&
          lifeTime == other.lifeTime &&
          serviceInstance == other.serviceInstance &&
          factory == other.factory;

  @override
  int get hashCode =>
      serviceType.hashCode ^
      implementationType.hashCode ^
      lifeTime.hashCode ^
      serviceInstance.hashCode ^
      factory.hashCode;
}

/// 服务作用域默认实现
class _ServiceProviderScope
    implements IServiceScope, IServiceProvider, IServiceScopeFactory {
  bool _disposed = false;
  final List<Object> _disposables = [];

  /// 是否为根作用域
  ///
  /// 根作用域负责管理单例实例的生命周期
  final bool isRoot;

  /// 当前作用域缓存的服务
  ///
  /// 如果[isRoot]为`true`，表示当前作用域为根作用域，根作用域只缓存由它创建的单例服务;
  /// 否则缓存当前作用域的服务；瞬时服务始终不会被缓存，它的生命周期由使用者负责。
  final Map<ServiceDescriptor, Object> _servicesCache = {};

  /// 根服务提供器
  final ServiceProvider _rootProvider;

  _ServiceProviderScope._(
      {required ServiceProvider rootProvider, required this.isRoot})
      : _rootProvider = rootProvider;

  /// 释放由当前作用域缓存的服务
  @override
  void dispose() {
    if (_disposed == true) {
      return;
    }
    _disposed = true;
    for (final d in _disposables) {
      // 在同步的释放方法中，优先调用实现了IDisposable.dispose方法
      if (d is IDisposable) {
        d.dispose();
        continue;
      }
      // 异步释放无法在同步方法中等待，但是（https://dart.dev/libraries/async/async-await#example-introducing-futures）示例说明
      // 在应用结束时，即使没有await，应用只会在event-loop为空时才退出。也就是说dart VM 会等待这些未被用户代码等待的异步任务结束后才退出应用。
      (d as IAsyncDisposable).disposeAsync();
    }
    _disposables.clear();
    if (isRoot && !_rootProvider._disposed) {
      _rootProvider.dispose();
    }
  }

  @override
  Future<void> disposeAsync() async {
    if (_disposed == true) {
      return;
    }
    _disposed = true;
    for (final d in _disposables) {
      // 在异步的释放方法中，优先调用 IAsyncDisposable.disposeAsync方法
      if (d is IAsyncDisposable) {
        await d.disposeAsync();
        continue;
      }
      (d as IDisposable).dispose();
    }
    _disposables.clear();
    if (isRoot && !_rootProvider._disposed) {
      await _rootProvider.disposeAsync();
    }
  }

  @override
  IServiceProvider get serviceProvider {
    _throwIfDisposed();
    return this;
  }

  @override
  Object? getService(Type serviceType) {
    _throwIfDisposed();
    return _rootProvider._getServiceByType(serviceType, this);
  }

  @override
  Iterable<Object> getServices(Type serviceType) {
    _throwIfDisposed();
    return _rootProvider._getServicesByType(serviceType, this);
  }

  void _captureDisables(Object service) {
    _throwIfDisposed();
    if (service is IDisposable || service is IAsyncDisposable) {
      _disposables.add(service);
    }
  }

  /// 查找内置服务
  ///
  /// 返回records类型, [isBuildIn] 指示是否为内置服务，如果为`true`，那么[serviceInstance]有值，否则[isBuildIn]为`false`，[serviceInstance]为`null`
  ///
  /// 注意，如果添加了新的内置服务，那么需要更新这个方法
  (bool isBuildIn, Object? serviceInstance) _fetchBuildInService(
      Type serviceType) {
    _throwIfDisposed();
    if (serviceType == IServiceProvider) {
      return (true, this);
    }
    if (serviceType == IServiceProviderIsService) {
      return (true, _rootProvider);
    }
    if (serviceType == IServiceScopeFactory) {
      return (true, _rootProvider._rootScope);
    }
    return (false, null);
  }

  Object _getOrAdd(ServiceDescriptor descriptor) {
    _throwIfDisposed();
    if (_servicesCache.containsKey(descriptor)) {
      return _servicesCache[descriptor]!;
    }
    switch (descriptor.lifeTime) {
      case ServiceLifeTime.singleton:
        {
          if (isRoot) {
            if (descriptor.serviceInstance != null) {
              return descriptor.serviceInstance;
            }
            // 当前对象是根作用域
            var instance = descriptor.factory!(this);
            // 由服务容器创建的单例服务，需要由容器负责释放
            _captureDisables(instance);
            _servicesCache[descriptor] = instance;
            return instance;
          }
          return _rootProvider._getService(
              descriptor, _rootProvider._rootScope);
        }
      case ServiceLifeTime.scoped:
        {
          if (isRoot) {
            throw InvalidScopeError("Scoped service can not provider by root.");
          }
          var instance = descriptor.factory!(this);
          // 由服务容器创建的作用域服务，需要由容器负责释放
          _captureDisables(instance);
          _servicesCache[descriptor] = instance;
          return instance;
        }
      case ServiceLifeTime.transient:
        return descriptor.factory!(_rootProvider);
    }
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw ObjectDisposedError("Scope has been disposed.");
    }
  }

  @override
  IServiceScope createScope() => _rootProvider._createScope();
}

/// 服务标识器
///
/// 该实现目前以服务类型来标识一个服务
class _ServiceIdentifier {
  final Type serviceType;

  const _ServiceIdentifier({required this.serviceType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ServiceIdentifier &&
          runtimeType == other.runtimeType &&
          serviceType == other.serviceType;

  @override
  int get hashCode => serviceType.hashCode;

  /// 从服务描述器来创建一个服务标识
  _ServiceIdentifier.fromDescriptor(ServiceDescriptor descriptor)
      : this(serviceType: descriptor.serviceType);

  /// 从服务类型来创建一个服务标识
  const _ServiceIdentifier.fromType(Type serviceType)
      : this(serviceType: serviceType);
}

/// 表示根服务提供器
final class ServiceProvider
    implements
        IServiceProvider,
        IServiceProviderIsService,
        IDisposable,
        IAsyncDisposable {
  bool _disposed = false;
  final List<ServiceDescriptor> _descriptors;
  late final _ServiceProviderScope _rootScope;

  /// 根服务提供器
  ServiceProvider._root(Iterable<ServiceDescriptor> descriptors)
      : _descriptors = descriptors.toList() {
    _rootScope = _ServiceProviderScope._(rootProvider: this, isRoot: true);
  }

  ServiceDescriptor? _findDescriptor(Type serviceType) {
    _throwIfDisposed();
    final identifier = _ServiceIdentifier.fromType(serviceType);
    for (var i = _descriptors.length - 1; i >= 0; i--) {
      final d = _descriptors[i];
      if (identifier == _ServiceIdentifier.fromDescriptor(d)) {
        return d;
      }
    }
    return null;
  }

  Iterable<ServiceDescriptor> _findDescriptors(Type serviceType) {
    _throwIfDisposed();
    final identifier = _ServiceIdentifier.fromType(serviceType);
    return _descriptors
        .where((e) => identifier == _ServiceIdentifier.fromDescriptor(e));
  }

  @override
  Object? getService(Type serviceType) =>
      _getServiceByType(serviceType, _rootScope);

  @override
  Iterable<Object> getServices(Type serviceType) =>
      _getServicesByType(serviceType, _rootScope);

  Object? _getServiceByType(Type serviceType, _ServiceProviderScope scope) {
    _throwIfDisposed();
    var (isBuildIn, instance) = scope._fetchBuildInService(serviceType);
    if (isBuildIn) {
      assert(instance != null,
          "Build in service instance can not be null when fetch a build in service.");
      return instance;
    }
    final d = _findDescriptor(serviceType);
    if (d == null) {
      return null;
    }
    return _getService(d, scope);
  }

  Iterable<Object> _getServicesByType(
      Type serviceType, _ServiceProviderScope scope) {
    _throwIfDisposed();
    var (isBuildIn, instance) = scope._fetchBuildInService(serviceType);
    if (isBuildIn) {
      assert(instance != null,
          "Build in service instance can not be null when fetch a build in service.");
      return [instance!];
    }
    final ds = _findDescriptors(serviceType);
    if (ds.isEmpty) {
      return Iterable<Object>.empty();
    }
    return _getServices(ds, scope);
  }

  Object _getService(
      ServiceDescriptor descriptor, _ServiceProviderScope scope) {
    _throwIfDisposed();
    return scope._getOrAdd(descriptor);
  }

  Iterable<Object> _getServices(Iterable<ServiceDescriptor> descriptors,
      _ServiceProviderScope scope) sync* {
    _throwIfDisposed();
    for (final d in descriptors) {
      yield scope._getOrAdd(d);
    }
  }

  @override
  void dispose() {
    if (_disposed == true) {
      return;
    }
    _descriptors.clear();
    _rootScope.dispose();
    _disposed = true;
  }

  @override
  Future<void> disposeAsync() async {
    if (_disposed == true) {
      return;
    }
    _descriptors.clear();
    await _rootScope.disposeAsync();
    _disposed = true;
  }

  IServiceScope _createScope() {
    _throwIfDisposed();
    return _ServiceProviderScope._(rootProvider: this, isRoot: false);
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw ObjectDisposedError("Scope has been disposed.");
    }
  }

  @override
  bool isService(Type serviceType) {
    var identifier = _ServiceIdentifier.fromType(serviceType);
    // 注意，如果添加了新的内置服务，那么需要更新这个方法
    return serviceType == IServiceProvider ||
        serviceType == IServiceProviderIsService ||
        serviceType == IServiceScopeFactory ||
        _descriptors
            .any((e) => identifier == _ServiceIdentifier.fromDescriptor(e));
  }
}

/// 服务集合默认实现
class ServiceCollection extends ListBase<ServiceDescriptor>
    implements IServiceCollection {
  final List<ServiceDescriptor> _l = [];

  /// 服务集合默认实现
  ServiceCollection();

  @override
  set length(int newLength) {
    _l.length = newLength;
  }

  @override
  int get length => _l.length;

  @override
  ServiceDescriptor operator [](int index) => _l[index];

  @override
  void operator []=(int index, ServiceDescriptor value) {
    _l[index] = value;
  }

  @override
  void add(ServiceDescriptor element) {
    _l.add(element);
  }

  @override
  void addAll(Iterable<ServiceDescriptor> iterable) {
    _l.addAll(iterable);
  }
}

/// 服务描述器的装饰器
///
/// 接收一个用于装饰的服务描述器[descriptor]，并返回在[descriptor]基础上进行装饰修改过的新的服务描述器
typedef Decorator = ServiceDescriptor Function(ServiceDescriptor descriptor);

/// 定义构建[ServiceProvider]和用于注册服务的扩展方法
extension ServiceCollectionExtensions on IServiceCollection {
  /// 构建服务提供器
  ServiceProvider buildServiceProvider() {
    return ServiceProvider._root(this);
  }

  /// 使用[instance]实例来添加一个单例服务
  void addSingletonInstance<TService, TImplementation extends TService>(
          TImplementation instance) =>
      add(ServiceDescriptor<TService, TImplementation>.instance(
          serviceInstance: instance));

  /// 尝试使用[instance]实例来添加一个单例服务，如果[TService]已经注册，则不会添加
  void tryAddSingletonInstance<TService, TImplementation extends TService>(
      TImplementation instance) {
    if (_serviceExists(TService)) {
      return;
    }
    addSingletonInstance<TService, TImplementation>(instance);
  }

  /// 使用[factory]服务工厂来添加一个单例服务
  void addSingleton<TService, TImplementation extends TService>(
          ServiceFactory<TImplementation> factory) =>
      add(ServiceDescriptor<TService, TImplementation>.singleton(
          factory: factory));

  /// 尝试使用[factory]服务工厂来添加一个单例服务，如果[TService]已经注册，则不会添加
  void tryAddSingleton<TService, TImplementation extends TService>(
      ServiceFactory<TImplementation> factory) {
    if (_serviceExists(TService)) {
      return;
    }
    addSingleton<TService, TImplementation>(factory);
  }

  /// 使用[factory]服务工厂来添加一个作用域服务
  void addScoped<TService, TImplementation extends TService>(
          ServiceFactory<TImplementation> factory) =>
      add(ServiceDescriptor<TService, TImplementation>.scoped(
          factory: factory));

  /// 尝试使用[factory]服务工厂来添加一个作用域服务，如果[TService]已经注册，则不会添加
  void tryAddScoped<TService, TImplementation extends TService>(
      ServiceFactory<TImplementation> factory) {
    if (_serviceExists(TService)) {
      return;
    }
    addScoped<TService, TImplementation>(factory);
  }

  /// 使用[factory]服务工厂来添加一个瞬时服务
  void addTransient<TService, TImplementation extends TService>(
          ServiceFactory<TImplementation> factory) =>
      add(ServiceDescriptor<TService, TImplementation>.transient(
          factory: factory));

  /// 尝试使用[factory]服务工厂来添加一个瞬时服务，如果[TService]已经注册，则不会添加
  void tryAddTransient<TService, TImplementation extends TService>(
      ServiceFactory<TImplementation> factory) {
    if (_serviceExists(TService)) {
      return;
    }
    addTransient<TService, TImplementation>(factory);
  }

  /// 检测[serviceType]=服务类型是否已经注册。
  bool _serviceExists(Type serviceType) =>
      any((e) => e.serviceType == serviceType);
}

/// 定义用于添加可枚举服务的扩展方法
extension EnumerableServiceCollectionExtensions on IServiceCollection {
  /// 尝试添加可枚举的服务
  ///
  /// 如果[TService]没有被注册，那么将会添加[descriptor];
  /// 如果[TService]已经注册，但是不存在[TImplementation]的实现，那么将会添加[descriptor]。
  void tryAddEnumerable<TService, TImplementation extends TService>(
      ServiceDescriptor<TService, TImplementation> descriptor) {
    if (_serviceImplementationExists(descriptor)) {
      return;
    }
    add(descriptor);
  }

  /// 检测[descriptor]表示的服务类型和服务实现的描述器是否已经添加
  bool _serviceImplementationExists(ServiceDescriptor descriptor) {
    return any((e) =>
        e.serviceType == descriptor.serviceType &&
        e.implementationType == descriptor.implementationType);
  }
}

/// 定义用于编辑[IServiceCollection]的扩展方法
extension EditableServiceCollectionExtensions on IServiceCollection {
  /// 将所有[serviceType]类型的服务使用[decorator]重新装饰一次。
  ///
  /// 该方法可用于修改现有的服务
  void decorate(Type serviceType, Decorator decorator) {
    for (final d in this) {
      if (d.serviceType != serviceType) {
        continue;
      }
      final index = indexOf(d);
      final d1 = decorator(d);
      assert(d1.serviceType == serviceType,
          "Decorator can not change the origin service type.");
      this[index] = d1;
    }
  }

  /// 替换第一个服务类型为[serviceType]的描述器
  ///
  /// 如果[serviceType]已经注册，那么第一个匹配服务类型的描述器将会被删除，然后添加[descriptor];
  /// 如果[serviceType]没有被注册，将直接添加[descriptor]
  void replace(Type serviceType, ServiceDescriptor descriptor) {
    var index = indexWhere((e) => e.serviceType == serviceType);
    if (index > -1) {
      remove(this[index]);
    }
    add(descriptor);
  }
}

/// [IServiceProvider]扩展，提供服务获取和作用域创建的方法
extension ServiceProviderExtensions on IServiceProvider {
  /// 获取可选的[TService]服务
  TService? getTypedService<TService>() => getService(TService) as TService?;

  /// 获取必须的[TService]服务，如果[TService]服务不存在，则会抛出[ServiceNotFoundError]
  TService getRequiredService<TService>() {
    var instance = getTypedService<TService>();
    if (instance == null) {
      throw ServiceNotFoundError(
          "Service `$TService` can not be found.", TService);
    }
    return instance as TService;
  }

  /// 获取可选的[TService]服务枚举
  Iterable<TService> getTypedServices<TService>() {
    final list = getServices(TService);
    return list.cast<TService>();
  }

  /// 获取可选的[TService]服务枚举，如果不存在任何的[TService]服务，则会抛出[ServiceNotFoundError]
  Iterable<TService> getRequiredServices<TService>() {
    final list = getTypedServices<TService>();
    if (list.isEmpty) {
      throw ServiceNotFoundError(
          "Service `$TService` can not be found.", TService);
    }
    return list;
  }

  /// 创建一个服务作用域
  IServiceScope createScope() {
    return getRequiredService<IServiceScopeFactory>().createScope();
  }
}
