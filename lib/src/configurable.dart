part of 'service_provider.dart';

/// Indicates that instances of this service can be configured by [ServiceConfigure] and [ServicePostConfigure].
abstract interface class IConfigurable {}

/// Service configure action
///
/// Configure the instance of [TService] when it's creating from the service container.
///
/// If the service is [ServiceLifeTime.singleton], then [IServiceProvider] is the root service provider;
/// If the service is [ServiceLifeTime.scoped], then [IServiceProvider] is the service provider of the corresponding scope;
/// If the service is [ServiceLifeTime.transient], then [IServiceProvider] is the service provider of the corresponding scope;
typedef ConfigureAction<TService> = void Function(IServiceProvider p, TService service);

/// Configure the service when it's created.
///
/// - [TService] the type of service
class ServiceConfigure<TService> {
  final ConfigureAction<dynamic> _config;

  /// - [config] An action that receive two arguments to configure instance of [TService].
  /// First argument is the [IServiceProvider]; second is the instance of [TService].
  const ServiceConfigure({required ConfigureAction<dynamic> config}) : _config = config;
}

/// Configure the service when it's created, but [ServicePostConfigure] runs after all [ServiceConfigure].
///
/// - [TService] the type of service
class ServicePostConfigure<TService> extends ServiceConfigure<TService> {
  /// - [config] An action that receive two arguments to configure instance of [TService].
  /// First argument is the [IServiceProvider]; second is the instance of [TService].
  const ServicePostConfigure({required super.config});
}
