import 'dart:collection';

import 'package:dart_logging_abstraction/dart_logging_abstraction.dart';

part 'configurable.dart';
part 'service_collection.dart';
part 'service_descriptor.dart';
part 'service_provider_scope.dart';

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

/// Represents the root service provider
final class ServiceProvider implements IServiceProvider, IServiceProviderIsService, IDisposable, IAsyncDisposable {
  bool _disposed = false;
  List<ServiceDescriptor> _descriptors;
  late final _ServiceProviderScope _rootScope;

  /// Root Service Provider
  ServiceProvider._root(Iterable<ServiceDescriptor> descriptors) : _descriptors = descriptors.toList(growable: false) {
    _rootScope = _ServiceProviderScope._(rootProvider: this, isRoot: true);
  }

  Iterable<ServiceDescriptor> _findDescriptors(Type serviceType) {
    _throwIfDisposed();
    return _descriptors.where((e) => e.serviceType == serviceType);
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

  Object _getService(ServiceDescriptor d, _ServiceProviderScope scope) {
    _throwIfDisposed();
    return scope._getOrAdd(d);
  }

  Iterable<Object> _getServices(Iterable<ServiceDescriptor> ds, _ServiceProviderScope scope) sync* {
    _throwIfDisposed();
    for (final d in ds) {
      yield scope._getOrAdd(d);
    }
  }

  void _applyConfigures(ServiceDescriptor d, Object s, _ServiceProviderScope scope) {
    if (s is! IConfigurable) {
      return;
    }
    _throwIfDisposed();
    _rootScope._logger?.debug("Configuring the instance ${s.hashCode} of ${d.serviceType} service");
    final configures = _getServices(_getConfigureDescriptors(d), scope).cast<ServiceConfigure>();
    final postConfigures = _getServices(_getPostConfigureDescriptors(d), scope).cast<ServicePostConfigure>();
    for (final c in configures) {
      c._config(scope, s);
    }
    for (final c in postConfigures) {
      c._config(scope, s);
    }
  }

  Iterable<ServiceDescriptor> _getConfigureDescriptors(ServiceDescriptor service) {
    final configureType = service._configureType;
    return _descriptors.where((d) => d.serviceType == configureType);
  }

  Iterable<ServiceDescriptor> _getPostConfigureDescriptors(ServiceDescriptor service) {
    final postConfigureType = service._postConfigureType;
    return _descriptors.where((d) => d.serviceType == postConfigureType);
  }

  @override
  void dispose() {
    if (_disposed == true) {
      return;
    }
    _descriptors = const [];
    _rootScope.dispose();
    _disposed = true;
  }

  @override
  Future<void> disposeAsync() async {
    if (_disposed == true) {
      return;
    }
    _descriptors = const [];
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
    // Note that if a new built-in service is added, this method will need to be updated.
    return serviceType == IServiceProvider ||
        serviceType == IServiceProviderIsService ||
        serviceType == IServiceScopeFactory ||
        _descriptors.any((e) => e.serviceType == serviceType);
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
