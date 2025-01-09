import 'dart:collection';

import 'package:dart_logging_abstraction/dart_logging_abstraction.dart';

/// Service life-time
enum ServiceLifeTime {
  /// Singleton, where only one instance exists in the same root service container
  ///
  /// When adding a singleton service, if an existing instance is added to the service container, the user is responsible for releasing the singleton.
  singleton,

  /// Scoped, the instances are not the same in different scoped service containers
  ///
  /// Scoped services are released by service containers.
  /// Different instances will be created in different scopes, and in the root service container,
  /// requests to scoped services are not allowed, and an error will be thrown.
  scoped,

  /// Transient, a new instance is created with each request.
  ///
  /// Each time an transient service is requested, a new instance is created.
  /// Transient services are not released by service containers, but are released by their consumers after they are obtained from service containers.
  transient,
}

/// Error that the object has been released and can no longer be used.
class ObjectDisposedError extends StateError {
  ObjectDisposedError(super.message);
}

/// Indicates an error that gets a scoped service in the root scope.
///
/// Scoped services cannot be obtained in the root service container,
/// and you need to use the service provider to create a scope and then obtain them.
class InvalidScopeError extends StateError {
  InvalidScopeError(super.message);
}

/// Indicates an error that service was not found.
class ServiceNotFoundError extends StateError {
  /// The type of service that is not registered
  final Type serviceType;

  ServiceNotFoundError(super.message, this.serviceType);
}

/// Indicates the interface for which resources need to be released.
abstract interface class IDisposable {
  /// Release resources that need to be released.
  ///
  /// Note: Make sure that no exceptions are thrown when releasing resources
  void dispose();
}

/// Used to release resources asynchronously.
abstract interface class IAsyncDisposable {
  /// Asynchronously release resources that need to be released.
  ///
  /// Note: Make sure that no exceptions are thrown when releasing resources
  Future<void> disposeAsync();
}

/// A service collection interface for configuring and adding services.
abstract interface class IServiceCollection implements List<ServiceDescriptor> {}

/// Service provider interface
///
/// This interface is also a built-in service,
/// and when you request [IServiceProvider] in the root service container,
/// it will be the root [ServiceProvider], and when you get it in the scope,
/// it will be the [IServiceProvider] associated with the scope.
abstract interface class IServiceProvider {
  /// Use the service type to get the service.
  ///
  /// When [serviceType] is not registered, `null` is returned.
  Object? getService(Type serviceType);

  /// Use the service type to get an instance enumeration of service implementations of the same service type.
  ///
  /// When [serviceType] is not registered, an empty enum is returned.
  Iterable<Object> getServices(Type serviceType);
}

/// Used to detect whether a type is registered as a service.
///
/// The service is a built-in singleton service.
abstract interface class IServiceProviderIsService {
  /// Detect if [serviceType] is registered as a service
  ///
  /// Returns 'true' if [serviceType] is registered as a service, 'false' if otherwise
  bool isService(Type serviceType);
}

/// Service scope
abstract interface class IServiceScope implements IDisposable, IAsyncDisposable {
  /// Gets the service provider associated with that scope
  IServiceProvider get serviceProvider;
}

/// Service Scope Factory
///
/// The service is a built-in singleton service
abstract interface class IServiceScopeFactory {
  /// Create a scope
  IServiceScope createScope();
}

/// Service Factory
///
/// [T] is the return type, which can be either a service type or a service implementation type.
///
/// Returns an instance of type [T], and the factory method receives an [IServiceProvider] as a parameter.
///
/// If the service is [ServiceLifeTime.singleton], then [IServiceProvider] is the root service provider;
/// If the service is [ServiceLifeTime.scoped], then [IServiceProvider] is the service provider of the corresponding scope;
/// If the service is [ServiceLifeTime.transient], then [IServiceProvider] is the root service provider.
typedef ServiceFactory<T> = T Function(IServiceProvider provider);

/// Service Descriptor
///
/// - [TService] Type of service
/// - [TImplementation] The type of implementation of the service
///
/// [TImplementation] can be a subclass of [TService] or a type of [TService].
class ServiceDescriptor<TService, TImplementation extends TService> {
  /// Type of service
  final Type serviceType;

  /// The type of service implementation, which may be the same as [serviceType].
  final Type implementationType;

  /// Lifecycle of the service
  final ServiceLifeTime lifeTime;

  /// An instance of the service, dedicated to a singleton service
  final TService? serviceInstance;

  /// The factory of the service, which will only be `null` if a singleton service descriptor is created using a service instance.
  final ServiceFactory<TImplementation>? factory;

  const ServiceDescriptor._custom(
    this.serviceType,
    this.implementationType,
    this.lifeTime,
    this.factory,
    this._configureType,
    this._postConfigureType,
  ) : serviceInstance = null;

  const ServiceDescriptor._customInstance(
    this.serviceType,
    this.implementationType,
    this.lifeTime,
    this.serviceInstance,
    this._configureType,
    this._postConfigureType,
  ) : factory = null;

  const ServiceDescriptor._({required this.lifeTime, required this.factory})
      : serviceType = TService,
        implementationType = TImplementation,
        serviceInstance = null,
        assert(TService != Object, "Service type can not be type `Object`.");

  /// Use a service instance to create a singleton service descriptor
  ///
  /// A singleton service that uses an existing instance is not released by the service container, and you are responsible for releasing the instance.
  const ServiceDescriptor.instance({required TService this.serviceInstance})
      : serviceType = TService,
        implementationType = TImplementation,
        lifeTime = ServiceLifeTime.singleton,
        factory = null,
        assert(TService != Object, "Service type can not be type `Object`.");

  /// Create a singleton service descriptor using an existing instance
  ///
  /// Singleton services added using a [factory] service factory are always released by the service container.
  const ServiceDescriptor.singleton({required ServiceFactory<TImplementation> factory})
      : this._(lifeTime: ServiceLifeTime.singleton, factory: factory);

  /// Create a scoped service descriptor
  ///
  /// Scoped services are released by service containers.
  /// Different instances will be created in different scopes,
  /// and in the root service container, requests to scoped services are not allowed, and an error will be thrown.
  ///
  /// Scoped services added using a [factory] service factory are always released by the service container.
  const ServiceDescriptor.scoped({required ServiceFactory<TImplementation> factory})
      : this._(lifeTime: ServiceLifeTime.scoped, factory: factory);

  /// Create a transient service descriptor
  ///
  /// Each time an transient service is requested, a new instance is created.
  /// Transient services are not released by service containers, but are released by their consumers after they are obtained from service containers.
  const ServiceDescriptor.transient({required ServiceFactory<TImplementation> factory})
      : this._(lifeTime: ServiceLifeTime.transient, factory: factory);

  @override
  String toString() {
    var buff = StringBuffer("ServiceType: $serviceType LifeTime: ${lifeTime.name}");
    if (serviceInstance != null) {
      buff.write(" ImplementationType: ${serviceInstance.runtimeType}");
    } else {
      buff.write(" ImplementationType: $implementationType");
    }
    if (lifeTime == ServiceLifeTime.singleton) {
      buff.write(" Factory: ${factory != null}");
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

/// Provides [ServiceDescriptor] copy method.
extension CopyServiceDescriptorExtensions on ServiceDescriptor {
  /// Copy a [ServiceDescriptor] and change the [ServiceDescriptor.factory] to [factory].
  ServiceDescriptor copyWith({required ServiceFactory factory}) {
    return ServiceDescriptor._custom(
      serviceType,
      implementationType,
      lifeTime,
      factory,
      _configureType,
      _postConfigureType,
    );
  }

  /// Copy a singleton [ServiceDescriptor] and change the [serviceInstance] to [instance].
  ServiceDescriptor copyWithInstance({required dynamic instance}) {
    if (lifeTime != ServiceLifeTime.singleton) {
      throw StateError("The life-time of the Service must be singleton.");
    }
    return ServiceDescriptor._customInstance(
      serviceType,
      implementationType,
      lifeTime,
      instance,
      _configureType,
      _postConfigureType,
    );
  }
}

/// The default implementation of [IServiceScope].
class _ServiceProviderScope implements IServiceScope, IServiceProvider, IServiceScopeFactory {
  bool _disposed = false;
  final List<Object> _disposables = [];
  ILogger4<IServiceProvider>? _logger;

  /// Whether it is root scoped
  ///
  /// The root scope is responsible for managing the lifecycle of a singleton instance
  final bool isRoot;

  /// The service of the currently scoped cache
  ///
  /// If [isRoot] is `true`, the current scope is the root scope,
  /// and the root scope caches only the singleton services created by it;
  /// Otherwise, cache the currently scoped service;
  /// Transient services are never cached, and their lifecycle is the responsibility of the consumer.
  final Map<ServiceDescriptor, Object> _servicesCache = {};

  /// Root Service Provider
  final ServiceProvider _rootProvider;

  _ServiceProviderScope._({required ServiceProvider rootProvider, required this.isRoot})
      : _rootProvider = rootProvider {
    _logger = getTypedService<ILoggerFactory>()?.createLogger<ServiceProvider>();
    // If the logger is disposable, it is captured, and it is released with the scope release
    if (_logger != null) {
      _captureDisables(_logger!);
    }
    _logger?.debug("Service scope $hashCode constructing, root: $isRoot");
  }

  /// Release the service cached by the current scope
  @override
  void dispose() {
    if (_disposed == true) {
      return;
    }
    _disposed = true;
    // If the logger is disposable, then it exists in the _disposables and will be disposed of by this method before it is disposed.
    _logger?.debug("Services scope $hashCode is disposing, root: $isRoot");
    for (final d in _disposables) {
      // In the synchronous release method, the IDisposable.dispose method is implemented in a priority call
      if (d is IDisposable) {
        d.dispose();
        continue;
      }
      // Asynchronous release cannot wait in the synchronous method,
      // but (https://dart.dev/libraries/async/async-await#example-introducing-futures) example illustrates that
      // at the end of the application, even without await, the application will only exit when the event-loop is empty.
      // That is, the dart VM waits for the end of these asynchronous tasks that are not waited for by the user code before exiting the application.
      (d as IAsyncDisposable).disposeAsync();
    }
    _disposables.clear();
    _servicesCache.clear();
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
    // In the synchronous release method, the IDisposable.dispose method is implemented in a priority call
    _logger?.debug("Services scope $hashCode is disposing asynchronous, root: $isRoot");
    for (final d in _disposables) {
      // In an asynchronous release method, the IAsyncDisposable.disposeAsync method is called preferentially
      if (d is IAsyncDisposable) {
        await d.disposeAsync();
        continue;
      }
      (d as IDisposable).dispose();
    }
    _disposables.clear();
    _servicesCache.clear();
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

  Object _getOrAdd(ServiceDescriptor descriptor) {
    _throwIfDisposed();
    if (_servicesCache.containsKey(descriptor)) {
      return _servicesCache[descriptor]!;
    }
    _logger?.debug("Creating, $descriptor");
    switch (descriptor.lifeTime) {
      case ServiceLifeTime.singleton:
        {
          if (isRoot) {
            final dynamic instance;
            if (descriptor.serviceInstance != null) {
              instance = descriptor.serviceInstance;
            } else {
              // The current scope is the root scope
              instance = descriptor.factory!(this);
              // A singleton service created by a service container needs to be released by the container
              _captureDisables(instance);
            }
            _servicesCache[descriptor] = instance;
            return instance;
          }
          return _rootProvider._getService(descriptor, _rootProvider._rootScope);
        }
      case ServiceLifeTime.scoped:
        {
          if (isRoot) {
            throw InvalidScopeError("Scoped service can not provide by root.");
          }
          var instance = descriptor.factory!(this);
          // A scoped service created by a service container needs to be released by the container
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

/// Service Identifier
///
/// The implementation currently identifies a service by its service type
class _ServiceIdentifier {
  final Type serviceType;

  const _ServiceIdentifier({required this.serviceType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ServiceIdentifier && runtimeType == other.runtimeType && serviceType == other.serviceType;

  @override
  int get hashCode => serviceType.hashCode;

  /// Create a service identity from the service descriptor
  _ServiceIdentifier.fromDescriptor(ServiceDescriptor descriptor) : this(serviceType: descriptor.serviceType);

  /// Create a service identity from the service type
  const _ServiceIdentifier.fromType(Type serviceType) : this(serviceType: serviceType);
}

/// Represents the root service provider
final class ServiceProvider implements IServiceProvider, IServiceProviderIsService, IDisposable, IAsyncDisposable {
  bool _disposed = false;
  final List<ServiceDescriptor> _descriptors;
  late final _ServiceProviderScope _rootScope;

  /// Root Service Provider
  ServiceProvider._root(Iterable<ServiceDescriptor> descriptors) : _descriptors = descriptors.toList(growable: false) {
    _rootScope = _ServiceProviderScope._(rootProvider: this, isRoot: true);
  }

  Iterable<ServiceDescriptor> _findDescriptors(Type serviceType) {
    _throwIfDisposed();
    final identifier = _ServiceIdentifier.fromType(serviceType);
    return _descriptors.where((e) => identifier == _ServiceIdentifier.fromDescriptor(e));
  }

  @override
  Object? getService(Type serviceType) => _getServiceByType(serviceType, _rootScope);

  @override
  Iterable<Object> getServices(Type serviceType) => _getServicesByType(serviceType, _rootScope);

  Object? _getServiceByType(Type serviceType, _ServiceProviderScope scope) {
    _throwIfDisposed();
    var (isBuildIn, instance) = _fetchBuildInService(serviceType, scope);
    if (isBuildIn) {
      assert(instance != null, "Build in service instance can not be null when fetch a build in service.");
      return instance;
    }
    final d = _findDescriptors(serviceType).lastOrNull;
    if (d == null) {
      return null;
    }
    return _getService(d, scope);
  }

  Iterable<Object> _getServicesByType(Type serviceType, _ServiceProviderScope scope) {
    _throwIfDisposed();
    var (isBuildIn, instance) = _fetchBuildInService(serviceType, scope);
    if (isBuildIn) {
      assert(instance != null, "Build in service instance can not be null when fetch a build in service.");
      return [instance!];
    }
    final ds = _findDescriptors(serviceType);
    if (ds.isEmpty) {
      return Iterable<Object>.empty();
    }
    return _getServices(ds, scope);
  }

  Object _getService(ServiceDescriptor descriptor, _ServiceProviderScope scope) {
    _throwIfDisposed();
    return scope._getOrAdd(descriptor);
  }

  Iterable<Object> _getServices(Iterable<ServiceDescriptor> descriptors, _ServiceProviderScope scope) sync* {
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
    _rootScope.dispose();
    _disposed = true;
  }

  @override
  Future<void> disposeAsync() async {
    if (_disposed == true) {
      return;
    }
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

  /// Look for built-in services
  ///
  /// Returns the records type, [isBuildIn] indicates whether it is a built-in service,
  /// if it is `true` then [serviceInstance] has a value, otherwise [isBuildIn] is 'false' and [serviceInstance] is 'null'.
  ///
  /// Note that if a new built-in service is added, this method will need to be updated.
  (bool isBuildIn, Object? serviceInstance) _fetchBuildInService(Type serviceType, _ServiceProviderScope scope) {
    _throwIfDisposed();
    if (serviceType == IServiceProvider) {
      return (true, scope);
    }
    if (serviceType == IServiceProviderIsService) {
      return (true, this);
    }
    if (serviceType == IServiceScopeFactory) {
      return (true, _rootScope);
    }
    return (false, null);
  }

  @override
  bool isService(Type serviceType) {
    var identifier = _ServiceIdentifier.fromType(serviceType);
    // Note that if a new built-in service is added, this method will need to be updated.
    return serviceType == IServiceProvider ||
        serviceType == IServiceProviderIsService ||
        serviceType == IServiceScopeFactory ||
        _descriptors.any((e) => identifier == _ServiceIdentifier.fromDescriptor(e));
  }
}

/// The default implementation of a collection of services.
class ServiceCollection extends ListBase<ServiceDescriptor> implements IServiceCollection {
  final List<ServiceDescriptor> _l = [];

  /// The default implementation of a collection of services.
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

/// Decorator for the service descriptor
///
/// Receives a service [descriptor] for decoration and returns a new service [descriptor] modified for decoration.
typedef Decorator = ServiceDescriptor Function(ServiceDescriptor descriptor);

/// Define the build [ServiceProvider] and the extension method used to register the service
extension ServiceCollectionExtensions on IServiceCollection {
  /// Build a service provider
  ServiceProvider buildServiceProvider() {
    return ServiceProvider._root(this);
  }

  /// Use the [instance] instance to add a singleton service.
  void addSingletonInstance<TService, TImplementation extends TService>(TImplementation instance) =>
      add(ServiceDescriptor<TService, TImplementation>.instance(serviceInstance: instance));

  /// Try to add a singleton service using an instance of [instance], if [TService] is already registered, it won't be added.
  void tryAddSingletonInstance<TService, TImplementation extends TService>(TImplementation instance) {
    if (_serviceExists(TService)) {
      return;
    }
    addSingletonInstance<TService, TImplementation>(instance);
  }

  /// Use the [factory] service factory to add a singleton service.
  void addSingleton<TService, TImplementation extends TService>(ServiceFactory<TImplementation> factory) =>
      add(ServiceDescriptor<TService, TImplementation>.singleton(factory: factory));

  /// Try to add a singleton service using the [factory] service factory, if [TService] is already registered, it won't be added.
  void tryAddSingleton<TService, TImplementation extends TService>(ServiceFactory<TImplementation> factory) {
    if (_serviceExists(TService)) {
      return;
    }
    addSingleton<TService, TImplementation>(factory);
  }

  /// Use [factory] to add a scoped service.
  void addScoped<TService, TImplementation extends TService>(ServiceFactory<TImplementation> factory) =>
      add(ServiceDescriptor<TService, TImplementation>.scoped(factory: factory));

  /// Try to add a scoped service using the [factory] service factory, if [TService] is already registered, it won't be added.
  void tryAddScoped<TService, TImplementation extends TService>(ServiceFactory<TImplementation> factory) {
    if (_serviceExists(TService)) {
      return;
    }
    addScoped<TService, TImplementation>(factory);
  }

  /// Use [factory] to add a transient service.
  void addTransient<TService, TImplementation extends TService>(ServiceFactory<TImplementation> factory) =>
      add(ServiceDescriptor<TService, TImplementation>.transient(factory: factory));

  /// Try to add a transient service using the [factory] service factory, which won't be added if [TService] is already registered.
  void tryAddTransient<TService, TImplementation extends TService>(ServiceFactory<TImplementation> factory) {
    if (_serviceExists(TService)) {
      return;
    }
    addTransient<TService, TImplementation>(factory);
  }

  /// Check whether the [serviceType] service type has been registered.
  bool _serviceExists(Type serviceType) => any((e) => e.serviceType == serviceType);
}

/// Define an extension method for adding enumerable services
extension EnumerableServiceCollectionExtensions on IServiceCollection {
  /// Try adding enumerable services
  ///
  /// If [TService] is not registered, [descriptor] will be added;
  /// If [TService] is already registered, but no implementation of [TImplementation] exists, then a [descriptor] will be added.
  void tryAddEnumerable<TService, TImplementation extends TService>(
      ServiceDescriptor<TService, TImplementation> descriptor) {
    if (_serviceImplementationExists(descriptor)) {
      return;
    }
    add(descriptor);
  }

  /// Checks whether the [descriptor] for the service type and service implementation has been added.
  bool _serviceImplementationExists(ServiceDescriptor descriptor) {
    return any((e) => e.serviceType == descriptor.serviceType && e.implementationType == descriptor.implementationType);
  }
}

/// Define the extension method for editing [IServiceCollection].
extension EditableServiceCollectionExtensions on IServiceCollection {
  /// Redecorate all services of type [serviceType] once with [decorator].
  ///
  /// This method can be used to modify an existing service.
  /// If [decorator] changes the service type of the descriptor, a [UnsupportedError] error is thrown.
  void decorate(Type serviceType, Decorator decorator) {
    for (final d in this) {
      if (d.serviceType != serviceType) {
        continue;
      }
      final index = indexOf(d);
      final d1 = decorator(d);
      if (d1.serviceType != serviceType) {
        throw UnsupportedError("Decorator can not change the origin service type.");
      }
      this[index] = d1;
    }
  }

  /// Replace the first descriptor with the service type [serviceType].
  ///
  /// If [serviceType] is already registered, then the first descriptor
  /// that matches the service type will be removed and [descriptor] will be added;
  /// If [serviceType] is not registered, [descriptor] will be added directly.
  ///
  /// If the service type of [descriptor] is different from the [serviceType] type, a [UnsupportedError] error is thrown.
  void replace(Type serviceType, ServiceDescriptor descriptor) {
    if (descriptor.serviceType != serviceType) {
      throw UnsupportedError("The service type can not be changed.");
    }
    final index = indexWhere((e) => e.serviceType == serviceType);
    if (index > -1) {
      remove(this[index]);
    }
    add(descriptor);
  }

  /// Replace the descriptor with the first service type [serviceType], this method is type safe.
  void replaceService<TService, TImplementation extends TService>(
      ServiceDescriptor<TService, TImplementation> descriptor) {
    replace(TService, descriptor);
  }
}

/// [IServiceProvider] extension to provide methods for service acquisition and scope creation
extension ServiceProviderExtensions on IServiceProvider {
  /// Get the optional [TService] service.
  TService? getTypedService<TService>() => getService(TService) as TService?;

  /// Get the required [TService] service, if the [TService] service does not exist, [ServiceNotFoundError] will be thrown.
  TService getRequiredService<TService>() {
    var instance = getTypedService<TService>();
    if (instance == null) {
      throw ServiceNotFoundError("Service `$TService` can not be found.", TService);
    }
    return instance as TService;
  }

  /// Get the optional [TService] service enumeration
  Iterable<TService> getTypedServices<TService>() {
    final list = getServices(TService);
    return list.cast<TService>();
  }

  /// Get an optional [TService] service enumeration, if no [TService] services exist, a [ServiceNotFoundError] will be thrown.
  Iterable<TService> getRequiredServices<TService>() {
    final list = getTypedServices<TService>();
    if (list.isEmpty) {
      throw ServiceNotFoundError("Service `$TService` can not be found.", TService);
    }
    return list;
  }

  /// Create a service scope.
  IServiceScope createScope() {
    return getRequiredService<IServiceScopeFactory>().createScope();
  }
}
