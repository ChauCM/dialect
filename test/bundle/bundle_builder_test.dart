import 'package:dialect/arb/arb_file.dart';
import 'package:dialect/bundle/bundle_builder.dart';
import 'package:dialect/config/dialect_config.dart';
import 'package:dialect/project/dialect_project.dart';
import 'package:test/test.dart';

void main() {
  ArbEntry e(String k, String v, {String? ns}) => ArbEntry(
    key: k,
    value: v,
    metadata: ns == null ? null : ArbMetadata(namespace: ns),
  );

  DialectProject project({
    List<String> targets = const ['es'],
    Map<String, ArbFile>? translations,
  }) {
    final source = ArbFile(
      locale: 'en',
      entries: [
        e(
          'checkoutItemCount',
          '{count, plural, =1{1 item} other{{count} items}}',
          ns: 'common',
        ),
        e('commonCancel', 'Cancel', ns: 'common'),
        e('backendError', 'Server error', ns: 'backend'),
      ],
    );
    return DialectProject(
      root: '/tmp/x',
      config: DialectConfig(sourceLocale: 'en', targetLocales: targets),
      source: source,
      translations:
          translations ??
          {
            'es': ArbFile(
              locale: 'es',
              entries: [
                e('checkoutItemCount', '{count, plural, other{{count} art}}'),
                e('commonCancel', 'Cancelar'),
                e('backendError', 'Error del servidor'),
              ],
            ),
          },
    );
  }

  PublishEnvConfig env({
    String format = 'icu-json',
    List<String> ns = const [],
  }) => PublishEnvConfig(
    name: 'staging',
    target: 'local',
    path: 'dist/',
    format: format,
    namespaces: ns,
  );

  test('version is sha256-16 and deterministic for identical content', () {
    final a = BundleBuilder.build(
      project(),
      env(),
      createdAt: 'T1',
      generator: 'g1',
    );
    final b = BundleBuilder.build(
      project(),
      env(),
      createdAt: 'T2',
      generator: 'g2',
    );
    expect(a.version, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(
      a.version,
      b.version,
      reason: 'created_at/generator are excluded from the version hash',
    );
  });

  test('different content yields a different version', () {
    final a = BundleBuilder.build(
      project(),
      env(),
      createdAt: 'T',
      generator: 'g',
    );
    final changed = project(
      translations: {
        'es': ArbFile(
          locale: 'es',
          entries: [
            e('checkoutItemCount', '{count, plural, other{{count} art}}'),
            e('commonCancel', 'CAMBIADO'),
            e('backendError', 'Error del servidor'),
          ],
        ),
      },
    );
    final b = BundleBuilder.build(
      changed,
      env(),
      createdAt: 'T',
      generator: 'g',
    );
    expect(a.version, isNot(b.version));
  });

  test('icu-json preserves plurals; flat-json collapses them', () {
    final icu = BundleBuilder.build(
      project(),
      env(format: 'icu-json'),
      createdAt: 'T',
      generator: 'g',
    );
    final flat = BundleBuilder.build(
      project(),
      env(format: 'flat-json'),
      createdAt: 'T',
      generator: 'g',
    );
    final icuEn = icu.locales.firstWhere((l) => l.locale == 'en').content;
    final flatEn = flat.locales.firstWhere((l) => l.locale == 'en').content;
    expect(icuEn, contains('plural'));
    expect(flatEn, isNot(contains('plural')));
    expect(flatEn, contains('"checkoutItemCount": "{count} items"'));
    // format change → different bundle version.
    expect(icu.version, isNot(flat.version));
  });

  test('namespace filter scopes the bundle', () {
    final b = BundleBuilder.build(
      project(),
      env(ns: ['common']),
      createdAt: 'T',
      generator: 'g',
    );
    final en = b.locales.firstWhere((l) => l.locale == 'en');
    expect(en.content, contains('commonCancel'));
    expect(en.content, isNot(contains('backendError')));
    expect(en.keys, 2);
  });

  test('manifest + channel head carry the expected shape', () {
    final b = BundleBuilder.build(
      project(),
      env(),
      createdAt: 'T',
      generator: 'g',
    );
    expect(b.manifestJson, contains('"schema": "dialect-bundle/1"'));
    expect(b.manifestJson, contains('"bundle_version": "${b.version}"'));
    expect(b.manifestJson, contains('"format": "icu-json"'));
    expect(b.manifestJson, contains('"sha256"'));
    expect(b.channelHeadJson, contains('"current": "${b.version}"'));
    expect(
      b.channelHeadJson,
      contains('"manifest": "b/${b.version}/manifest.json"'),
    );
    // Locales sorted by tag: en before es.
    expect(b.locales.map((l) => l.locale).toList(), ['en', 'es']);
  });
}
