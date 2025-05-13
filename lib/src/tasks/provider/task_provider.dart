// coverage:ignore-file

import 'package:meta/meta.dart';
import 'package:riverpod/misc.dart';
import 'package:riverpod/riverpod.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart';

import '../../task_base.dart';

// ignore: subtype_of_sealed_class
/// A custom riverpod provider for [TaskBase] classes.
///
/// Besides of the standard create function, this provider also requires to
/// to specify the name of the task as first argument.
@sealed
class TaskProvider<State extends TaskBase> {
  /// The underlying provider
  final Provider<State> _provider;

  /// Default constructor.
  TaskProvider(
    String name,
    // ignore: invalid_use_of_internal_member
    Create<State> createFn, {
    List<ProviderOrFamily>? dependencies,
  }) : _provider = Provider<State>(
         createFn,
         name: name,
         dependencies: dependencies,
       );

  /// Get the name of this provider
  String get name => _provider.name!;

  /// Allow this provider to be used like the original Provider
  Provider<State> get provider => _provider;

  /// A member to create a configurable task provider.
  ///
  /// See [ConfigurableTaskProviderFamily].
  static const configurable = ConfigurableTaskProviderBuilder();
}

/// Typedef for a function that can parse a task configuration.
typedef ArgFromJson<Arg> = Arg Function(Map<String, dynamic> json);

// ignore: subtype_of_sealed_class
/// A custom riverpod provider family for [TaskBase] classes that are
/// configurable.
///
/// Besides of the standard family create functions, this provider also requires
/// to specify the name of the task as first argument and a factory function
/// that can convert a generic JSON/YAML-structure into the typed task
/// configuration as second argument.
@sealed
class ConfigurableTaskProviderFamily<State extends TaskBase, Arg> {
  /// The configuration factory
  final ArgFromJson<Arg> fromJson;

  /// The underlying provider family
  final ProviderFamily<State, Arg> _family;

  /// Default constructor
  ConfigurableTaskProviderFamily(
    String name,
    this.fromJson,
    // ignore: invalid_use_of_internal_member
    FamilyCreate<State, Arg> createFn, {
    List<ProviderOrFamily>? dependencies,
    // ignore: invalid_use_of_internal_member
  }) : _family = ProviderFamily<State, Arg>(
         createFn,
         name: name,
         dependencies: dependencies,
       );

  /// Forward the call to the underlying provider family
  Provider<State> call(Arg arg) => _family.call(arg);

  /// Get the name of this provider family
  String get name => _family.name!;
}

// ignore: subtype_of_sealed_class
/// A helper class to easily create a [ConfigurableTaskProviderFamily].
@sealed
class ConfigurableTaskProviderBuilder {
  /// Default constructor.
  const ConfigurableTaskProviderBuilder();

  /// Creates the provider family.
  ConfigurableTaskProviderFamily<State, Arg> call<State extends TaskBase, Arg>(
    String name,
    ArgFromJson<Arg> fromJson,
    // ignore: invalid_use_of_internal_member
    FamilyCreate<State, Arg> create, {
    List<ProviderOrFamily>? dependencies,
  }) => ConfigurableTaskProviderFamily(
    name,
    fromJson,
    create,
    dependencies: dependencies,
  );
}
