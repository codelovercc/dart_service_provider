import 'package:dart_service_provider/dart_service_provider.dart';

/// Environment interface
abstract interface class IEnvironment {
  /// Get or set environment name
  abstract String name;
}

/// Default [IEnvironment] implementation
class Environment implements IEnvironment {
  @override
  String name;

  Environment({required this.name});
}

/// Defines commonly used environment names.
final class Environments {
  Environments._();

  /// The production environment
  static const String production = "Production";

  /// The development environment
  static const String development = "Development";

  /// the staging environment
  static const String staging = "Staging";

  /// the testing environment
  static const String testing = "Testing";
}

/// Provide environment check methods
extension EnvironmentExtensions on IEnvironment {
  /// Check if the environment is production
  bool isProduction() => name == Environments.production;

  /// Check if the environment is development
  bool isDevelopment() => name == Environments.development;

  /// Check if the environment is staging
  bool isStaging() => name == Environments.staging;

  /// Check if the environment is testing
  bool isTesting() => name == Environments.testing;
}

/// Environment service extension methods
extension EnvironmentServiceCollectionExtensions on IServiceCollection {
  /// Add environment service as singleton
  void addEnvironment<TImplementation extends IEnvironment>(TImplementation environment) {
    addSingletonInstance<IEnvironment, TImplementation>(environment);
  }

  /// Try add environment service as singleton
  void tryAddEnvironment<TImplementation extends IEnvironment>(TImplementation environment) {
    tryAddSingletonInstance<IEnvironment, TImplementation>(environment);
  }
}
