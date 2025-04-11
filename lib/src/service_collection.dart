part of 'service_provider.dart';

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

/// Provides extension methods for configuration of service instances.
extension ConfigureServiceCollectionExtensions on IServiceCollection {
  /// Configure [TService] when it's created.
  ///
  /// - [config] An action that receive two arguments to configure instance of [TService].
  /// First argument is the [IServiceProvider]; second is the instance of [TService].
  void configure<TService extends IConfigurable>(ConfigureAction<TService> config) {
    addTransient<ServiceConfigure<TService>, ServiceConfigure<TService>>(
      (p) => ServiceConfigure(
        config: (p, s) => config(p, s),
      ),
    );
  }

  /// Post configure [TService] when it's created. These configures run after all [ServiceConfigure].
  ///
  /// - [config] An action that receive two arguments to configure instance of [TService].
  /// First argument is the [IServiceProvider]; second is the instance of [TService].
  void postConfigure<TService extends IConfigurable>(ConfigureAction<TService> config) {
    addTransient<ServicePostConfigure<TService>, ServicePostConfigure<TService>>(
      (p) => ServicePostConfigure(
        config: (p, s) => config(p, s),
      ),
    );
  }
}
