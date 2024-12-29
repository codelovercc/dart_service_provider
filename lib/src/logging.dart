import 'package:dart_logging_abstraction/dart_logging_abstraction.dart';
import 'package:dart_service_provider/src/environment.dart';

import 'service_provider.dart';

/// Options for logger
class LoggerOptions {
  /// the default logger name for the global logger.
  final String defaultLoggerName;

  /// Minimal log level.
  final LogLevel minLevel;

  /// Constructor
  ///
  /// - [minLevel] The minimal log level.
  const LoggerOptions({required this.minLevel, required this.defaultLoggerName});
}

/// The class that help build logging services.
final class LoggingBuilder {
  /// The ServiceCollection
  final IServiceCollection services;

  const LoggingBuilder({required this.services});
}

/// 支持从服务容器中解析日志服务
extension LoggingServiceCollectionExtension on IServiceCollection {
  /// Add default logging services
  ///
  /// - [config] to custom logging services, use this argument to configure [ILoggerFactory] service usually.
  /// [addLogging] method will call this before it try to use console logging.
  /// If there is no logging services configured by [config] action, the console logging will be used as logging services.
  ///
  /// returns [LoggingBuilder] that can config logging after default configuration.
  ///
  /// Default logging:
  /// - [LoggerOptions] singleton service, provide the options for logging. It should only be used to construct other logging services.
  /// - [ILoggerFactory] singleton service, you can use this factory to create your own [ILogger] instance,
  /// notes: You have the responsibility of the life-time control of the [ILogger] instance that created by yourself.
  /// - [ILogger] singleton service, the global logger.
  ///
  /// Custom logging services:
  /// - Implement [ILoggerFactory] interface and configure it in [config].
  /// - Optional implement [ILogger] and [ILogger4] interfaces, implement `ILogger4` is recommended.
  /// - If you implementations does not need [LoggerOptions] service, please call [LoggingBuilderExtensions.removeOptions] to delete it.
  LoggingBuilder addLogging({void Function(LoggingBuilder builder)? config}) {
    final builder = LoggingBuilder(services: this);
    config?.call(builder);
    builder.tryUseConsoleLog();
    return builder;
  }
}

/// Extensions that helps config logging services
extension LoggingBuilderExtensions on LoggingBuilder {
  /// Try use console log as the logging services.
  void tryUseConsoleLog() {
    tryAddOptions<LoggerOptions>(
      (p) {
        final LogLevel logLevel =
            p.getTypedService<IEnvironment>()?.isProduction == true ? LogLevel.info : LogLevel.debug;
        return LoggerOptions(minLevel: logLevel, defaultLoggerName: "Global");
      },
    );
    tryAddLoggerFactory<LoggerFactory>(
      (p) {
        final options = p.getRequiredService<LoggerOptions>();
        return LoggerFactory(minLevel: options.minLevel);
      },
    );
    tryAddGlobalLogger<ILogger>(
      (p) {
        final options = p.getRequiredService<LoggerOptions>();
        final factory = p.getRequiredService<ILoggerFactory>();
        return factory.create(options.defaultLoggerName);
      },
    );
  }

  /// Try to add [LoggerOptions] service as singleton.
  void tryAddOptions<TOptionsImpl extends LoggerOptions>(ServiceFactory<TOptionsImpl> factory) =>
      services.tryAddSingleton<LoggerOptions, TOptionsImpl>(factory);

  /// Try to add [ILoggerFactory] service as singleton.
  void tryAddLoggerFactory<TFactoryImpl extends ILoggerFactory>(ServiceFactory<TFactoryImpl> factory) =>
      services.tryAddSingleton<ILoggerFactory, TFactoryImpl>(factory);

  /// Try to add global [ILogger] service as singleton.
  void tryAddGlobalLogger<TLoggerImpl extends ILogger>(ServiceFactory<TLoggerImpl> factory) =>
      services.tryAddSingleton<ILogger, TLoggerImpl>(factory);

  /// Replace the [LoggerOptions] service.
  void replaceOptions<TOptionsImpl extends LoggerOptions>(ServiceFactory<TOptionsImpl> factory) =>
      services.replaceService<LoggerOptions, TOptionsImpl>(
          ServiceDescriptor<LoggerOptions, TOptionsImpl>.singleton(factory: factory));

  /// Replace the [ILoggerFactory] service.
  void replaceLoggerFactory<TFactoryImpl extends ILoggerFactory>(ServiceFactory<TFactoryImpl> factory) =>
      services.replaceService<ILoggerFactory, TFactoryImpl>(
          ServiceDescriptor<ILoggerFactory, TFactoryImpl>.singleton(factory: factory));

  /// Replace global [ILogger] service.
  void replaceGlobalLogger<TLoggerImpl extends ILogger>(ServiceFactory<TLoggerImpl> factory) => services
      .replaceService<ILogger, TLoggerImpl>(ServiceDescriptor<ILogger, TLoggerImpl>.singleton(factory: factory));

  /// Remove [LoggerOptions] service.
  ///
  /// ***⚠️Only call this while you ensure that [ILoggerFactory] and [ILogger] services do not depend on [LoggerOptions] service.
  /// [LoggerOptions] service is required by the default logging services.⚠️***
  void removeOptions() => services.removeWhere((e) => e.serviceType == LoggerOptions);
}

extension LoggingServiceProviderExtensions on IServiceProvider {
  /// Get the optional [ILoggerFactory]
  ILoggerFactory? getLoggerFactory() => getTypedService<ILoggerFactory>();

  /// Get the required [ILoggerFactory]
  ///
  /// Throws [ServiceNotFoundError] while the logging service is not enabled.
  ILoggerFactory getRequiredLoggerFactory() {
    final f = getLoggerFactory();
    if (f == null) {
      throw ServiceNotFoundError(
          "$ILoggerFactory service does not exists, you have to call `addLogging` extension method on the $ServiceCollection instance for enable logging.",
          ILoggerFactory);
    }
    return f;
  }

  /// Get the optional [ILogger] instance.
  ///
  /// - [T] the type uses to create [ILogger] instance.
  ///
  /// returns the [ILogger] instance if the logging services configured, otherwise returns `null`.
  ///
  /// Note: Do not implement [ILogger] as an [IDisposable] or an [IAsyncDisposable], it should be implement normally,
  /// you can implement [ILoggerFactory] as singleton and disposable service.
  /// If the [ILogger] is a disposable object, you have to dispose it at your own responsibility.
  ILogger4<T>? getLogger<T>() {
    final factory = getTypedService<ILoggerFactory>();
    return factory?.createLogger<T>();
  }

  /// Get the required [ILogger] instance.
  /// If logging is not enabled, [ServiceNotFoundError] is thrown,
  /// call [LoggingServiceCollectionExtension.addLogging] to avoid this error.
  ///
  /// - [T] the type uses to create [ILogger] instance.
  ///
  /// Returns the [ILogger] instance.
  ///
  /// Throws [ServiceNotFoundError] while the logging service is not enabled.
  ///
  /// Note: Do not implement [ILogger] as an [IDisposable] or an [IAsyncDisposable], it should be implement normally,
  /// you can implement [ILoggerFactory] as singleton and disposable service.
  /// If the [ILogger] is a disposable object, you have to dispose it at your own responsibility.
  ILogger4<T> getRequiredLogger<T>() {
    final l = getLogger<T>();
    if (l == null) {
      throw ServiceNotFoundError(
          "$ILoggerFactory service does not exists, you have to call `addLogging` extension method on the $ServiceCollection instance for enable logging.",
          ILoggerFactory);
    }
    return l;
  }
}
