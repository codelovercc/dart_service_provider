part of 'service_provider.dart';

/// The default implementation of [IServiceScope].
class _ServiceProviderScope implements IServiceScope, IServiceProvider, IServiceScopeFactory {
  bool _disposed = false;
  List<Object> _disposables = [];
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
  Map<ServiceDescriptor, Object> _servicesCache = {};

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
    _disposables = const [];
    _servicesCache = const {};
    _logger = null;
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
    _disposables = const [];
    _servicesCache = const {};
    _logger = null;
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
    {
      _logger?.debug("Fetching, $descriptor");
      final instance = _servicesCache[descriptor];
      if (instance != null) {
        return instance;
      }
    }
    switch (descriptor.lifeTime) {
      case ServiceLifeTime.singleton:
        {
          if (isRoot) {
            final dynamic instance;
            if (descriptor.serviceInstance != null) {
              instance = descriptor.serviceInstance;
            } else {
              // The current scope is the root scope
              _logger?.debug("Creating, $descriptor");
              instance = descriptor.factory!(this);
              // A singleton service created by a service container needs to be released by the container
              _captureDisables(instance);
            }
            _servicesCache[descriptor] = instance;
            _rootProvider._applyConfigures(descriptor, instance, this);
            return instance;
          }
          return _rootProvider._getService(descriptor, _rootProvider._rootScope);
        }
      case ServiceLifeTime.scoped:
        {
          if (isRoot) {
            throw InvalidScopeError("Scoped service can not provide by root.");
          }
          _logger?.debug("Creating, $descriptor");
          var instance = descriptor.factory!(this);
          // A scoped service created by a service container needs to be released by the container
          _captureDisables(instance);
          _servicesCache[descriptor] = instance;
          _rootProvider._applyConfigures(descriptor, instance, this);
          return instance;
        }
      case ServiceLifeTime.transient:
        {
          _logger?.debug("Creating, $descriptor");
          final instance = descriptor.factory!(this);
          _rootProvider._applyConfigures(descriptor, instance, this);
          return instance;
        }
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
