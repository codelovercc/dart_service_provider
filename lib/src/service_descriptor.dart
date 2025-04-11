part of 'service_provider.dart';

/// Service Factory
///
/// [T] is the return type, which can be either a service type or a service implementation type.
///
/// Returns an instance of type [T], and the factory method receives an [IServiceProvider] as a parameter.
///
/// If the service is [ServiceLifeTime.singleton], then [IServiceProvider] is the root service provider;
/// If the service is [ServiceLifeTime.scoped], then [IServiceProvider] is the service provider of the corresponding scope;
/// If the service is [ServiceLifeTime.transient], then [IServiceProvider] is the service provider of the corresponding scope;
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

  final Type _configureType;

  final Type _postConfigureType;

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
        _configureType = ServiceConfigure<TService>,
        _postConfigureType = ServicePostConfigure<TService>,
        serviceInstance = null,
        assert(TService != Object, "Service type can not be type `Object`.");

  /// Use a service instance to create a singleton service descriptor
  ///
  /// A singleton service that uses an existing instance is not released by the service container, and you are responsible for releasing the instance.
  const ServiceDescriptor.instance({required TService this.serviceInstance})
      : serviceType = TService,
        implementationType = TImplementation,
        _configureType = ServiceConfigure<TService>,
        _postConfigureType = ServicePostConfigure<TService>,
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
