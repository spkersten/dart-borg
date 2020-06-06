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

// ignore_for_file: public_member_api_docs

import 'package:borg/src/dart_package/dart_package.dart';
import 'package:borg/src/impact/impact_based_on_pubspec_yaml.dart';
import 'package:path/path.dart';
import 'package:plain_optional/plain_optional.dart';
import 'package:test/test.dart';

void main() {
  group('$impactBasedOnPubspecYaml', () {
    group('given input without dependencies between packages', () {
      final packagesUnderImpact = impactBasedOnPubspecYaml(
        packages: [_packageA],
        allPackages: [_packageA, _packageB],
      );
      test('it returns the list of packages without modification', () {
        expect(packagesUnderImpact, [_packageA]);
      });
    });

    group('given input with packages, one directly depends on another', () {
      final packagesUnderImpact = impactBasedOnPubspecYaml(
        packages: [_packageA],
        allPackages: [_packageA, _packageB, _packageC],
      );
      test('it returns the list containing both packages', () {
        expect(packagesUnderImpact, {_packageA, _packageC});
      });
    });

    group('given input with packages, one indirectly depends on another', () {
      final packagesUnderImpact = impactBasedOnPubspecYaml(
        packages: [_packageA],
        allPackages: [_packageA, _packageB, _packageC, _packageD],
      );
      test('it returns the list containing all dependent packages', () {
        expect(packagesUnderImpact, {_packageA, _packageC, _packageD});
      });
    });

    group('given input with packages, one directly dev depends on another', () {
      final packagesUnderImpact = impactBasedOnPubspecYaml(
        packages: [_packageA],
        allPackages: [_packageA, _packageE],
      );
      test('it returns the list containing both packages', () {
        expect(packagesUnderImpact, {_packageA, _packageE});
      });
    });

    group('given input with packages, first directly dev depends on the second, third depends on the second', () {
      final packagesUnderImpact = impactBasedOnPubspecYaml(
        packages: [_packageA],
        allPackages: [_packageA, _packageE, _packageF],
      );
      test('it returns the list containing only the first and the second packages', () {
        expect(packagesUnderImpact, {_packageA, _packageE});
      });
    });
  });
}

final _packageA = DartPackage(path: canonicalize('a'), tryToReadFileSync: (_) => const Optional('''
name: a
'''));

final _packageB = DartPackage(path: canonicalize('b'), tryToReadFileSync: (_) => const Optional('''
name: b
'''));

final _packageC = DartPackage(path: canonicalize('c'), tryToReadFileSync: (_) => const Optional('''
name: c
dependencies:
  a:
    path: ../a
  b:
    path: ../b
'''));

final _packageD = DartPackage(path: canonicalize('d'), tryToReadFileSync: (_) => const Optional('''
name: d
dependencies:
  c:
    path: ../c
'''));

final _packageE = DartPackage(path: canonicalize('e'), tryToReadFileSync: (_) => const Optional('''
name: e
dev_dependencies:
  a:
    path: ../a
'''));

final _packageF = DartPackage(path: canonicalize('f'), tryToReadFileSync: (_) => const Optional('''
name: f
dev_dependencies:
  e:
    path: ../e
'''));