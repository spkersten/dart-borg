/*
 * MIT License
 *
 * Copyright (c) 2020 Alexei Sintotski
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

import 'package:args/command_runner.dart';
import 'package:borg/src/configuration/configuration.dart';
import 'package:borg/src/configuration/factory.dart';
import 'package:borg/src/context/borg_boot_context.dart';
import 'package:borg/src/context/borg_context_factory.dart';
import 'package:borg/src/dart_package/dart_package.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:plain_optional/plain_optional.dart';

import '../options/boot_mode.dart';
import '../options/verbose.dart';
import '../resolve_dependencies.dart';
import '../scan_for_packages.dart';
import '../utils/borg_exception.dart';
import '../utils/git.dart';

// ignore_for_file: avoid_print

class BootCommand extends Command<void> {
  BootCommand() {
    configurationFactory.populateConfigurationArgs(argParser);
    addBootModeOption(argParser);
    addVerboseFlag(argParser);
  }

  @override
  String get description => 'Executes "pub get" for multiple packages in repository\n\n'
      'Packages to bootstrap can be specified as arguments. '
      'If no arguments are supplied, the command bootstraps all scanned packages.\n'
      'If path to Flutter SDK is defined, "flutter packages get" is used to resolve dependencies.';

  @override
  String get name => 'boot';

  @override
  void run() => exitWithMessageOnBorgException(action: _run, exitCode: 255);

  final BorgConfigurationFactory configurationFactory = BorgConfigurationFactory();

  void _run() {
    final configuration = configurationFactory.createConfiguration(argResults: argResults);
    // ignore: prefer_const_constructors
    final contextFactory = BorgContextFactory();
    final context = contextFactory.createBorgContext();

    final packages = scanForPackages(
      configuration: configuration,
      argResults: argResults,
    );

    switch (getBootModeOption(argResults)) {
      case BootMode.basic:
        _executeBasicBootstrapping(
          packages: packages,
          configuration: configuration,
        );
        break;
      case BootMode.incremental:
        _executeIncrementalBootstrapping(
          packages: packages,
          configuration: configuration,
          context: context.bootContext,
        );
    }

    contextFactory.save(
      context: context.copyWith(bootContext: Optional(BorgBootContext(gitref: gitHead()))),
    );
  }

  void _executeBasicBootstrapping({
    @required Iterable<DartPackage> packages,
    @required BorgConfiguration configuration,
  }) {
    final packagesToBoot =
        argResults.rest.isEmpty ? packages : packages.where((p) => argResults.rest.any((arg) => p.path.endsWith(arg)));

    if (packagesToBoot.isEmpty) {
      throw const BorgException('\nFATAL: Nothing to do, please check command line');
    }

    _bootstrapPackages(
      packages: packagesToBoot,
      configuration: configuration,
    );
  }

  void _executeIncrementalBootstrapping({
    @required Iterable<DartPackage> packages,
    @required BorgConfiguration configuration,
    @required Optional<BorgBootContext> context,
  }) {
    print('WARNING: Incremental bootstrapping selected, this feature is still EXPERIMENTAL!\n');

    final packagesToBoot = context.iif(
      some: (ctx) {
        final packagesChangedSinceLastSuccessfulBoot = gitDiffFiles(gitref: ctx.gitref)
            .where(_isPubspecFile)
            .map(path.dirname)
            .map(path.canonicalize)
            .map(path.relative);
        return packages.where((p) => packagesChangedSinceLastSuccessfulBoot.contains(p.path));
      },
      none: () {
        print('\nNo information on the last successful bootstrapping is found.');
        print('Bootstrapping all found packages...');

        if (packages.isEmpty) {
          throw const BorgException('\nFATAL: Nothing to do, please check command line');
        }

        return packages;
      },
    );

    if (packagesToBoot.isEmpty) {
      print('SUCCESS: Workspace is up-to-date, bootstrapping is not required');
    } else {
      _bootstrapPackages(
        packages: packagesToBoot,
        configuration: configuration,
      );
    }
  }

  void _bootstrapPackages({
    @required Iterable<DartPackage> packages,
    @required BorgConfiguration configuration,
  }) {
    print('Bootstrapping packages:');
    var i = 1;
    for (final package in packages) {
      final counter = '[${i++}/${packages.length}]';
      print('$counter ${package.isFlutterPackage ? 'Flutter' : 'Dart'} package ${package.path}...');

      resolveDependencies(
        package: package,
        configuration: configuration,
        verbosity: getVerboseFlag(argResults) ? VerbosityLevel.verbose : VerbosityLevel.short,
      );
    }

    print('\nSUCCESS: ${packages.length} packages have been bootstrapped');
  }
}

bool _isPubspecFile(String pathToFile) => path.basenameWithoutExtension(pathToFile) == 'pubspec';
