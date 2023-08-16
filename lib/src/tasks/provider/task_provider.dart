// coverage:ignore-file

import 'package:meta/meta.dart';
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
class TaskProvider<State extends TaskBase> extends Provider<State> {
  /// Default constructor.
  TaskProvider(
    String name,
    super._createFn, {
    super.dependencies,
    super.from,
    super.argument,
  }) : super(name: name);

  @override
  String get name => super.name!;

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
class ConfigurableTaskProviderFamily<State extends TaskBase, Arg>
    extends ProviderFamily<State, Arg> {
  /// The configuration factory
  final ArgFromJson<Arg> fromJson;

  /// Default constructor
  ConfigurableTaskProviderFamily(
    String name,
    this.fromJson,
    super._createFn, {
    super.dependencies,
  }) : super(name: name);

  @override
  String get name => super.name!;
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
    FamilyCreate<State, ProviderRef<State>, Arg> create, {
    List<ProviderOrFamily>? dependencies,
  }) =>
      ConfigurableTaskProviderFamily(
        name,
        fromJson,
        create,
        dependencies: dependencies,
      );
}
