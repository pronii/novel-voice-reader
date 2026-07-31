import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/library/data/epub_book_parser.dart';

void main() {
  test('uses EPUB spine order and extracts paragraph text', () async {
    final parsed = await const EpubBookParser().parse(
      _buildEpub(),
      'fixture.epub',
    );

    expect(parsed.title, '测试 EPUB');
    expect(parsed.chapters.map((chapter) => chapter.title), ['第二章', '第一章']);
    expect(parsed.chapters.first.paragraphs, ['第二章', '第二段。']);
    expect(parsed.chapters.last.paragraphs, ['第一章', '第一段。']);
  });

  test('extracts chapters whose EPUB3 body uses div blocks', () async {
    final parsed = await const EpubBookParser().parse(
      _buildEpub(
        chapterOneHtml:
            '<html xmlns="http://www.w3.org/1999/xhtml"><body>'
            '<div>第一章</div><div>第一段。</div></body></html>',
      ),
      'fixture.epub',
    );

    expect(parsed.chapters.map((chapter) => chapter.title), ['第二章', '第一章']);
    expect(parsed.chapters.last.paragraphs, ['第一章', '第一段。']);
  });

  test(
    'ignores missing non-reading resources while parsing the spine',
    () async {
      final parsed = await const EpubBookParser().parse(
        _buildEpub(includeMissingImageManifestItem: true),
        'broken-cover.epub',
      );

      expect(parsed.title, '测试 EPUB');
      expect(parsed.chapters.map((chapter) => chapter.title), ['第二章', '第一章']);
    },
  );

  test('rejects a missing linear spine document', () async {
    expect(
      () => const EpubBookParser().parse(
        _buildEpub(missingSpineDocument: true),
        'missing-chapter.epub',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

Uint8List _buildEpub({
  String? chapterOneHtml,
  bool includeMissingImageManifestItem = false,
  bool missingSpineDocument = false,
}) {
  final archive = Archive();
  _addText(archive, 'mimetype', 'application/epub+zip');
  _addText(archive, 'META-INF/container.xml', '''
<?xml version="1.0"?>
<container version="1.0"
  xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf"
      media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''');
  _addText(archive, 'OEBPS/content.opf', '''
<?xml version="1.0" encoding="UTF-8"?>
<package version="2.0" unique-identifier="book-id"
  xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>测试 EPUB</dc:title>
    <dc:identifier id="book-id">fixture</dc:identifier>
    <dc:language>zh</dc:language>
  </metadata>
  <manifest>
    <item id="toc" href="toc.ncx"
      media-type="application/x-dtbncx+xml"/>
    <item id="one" href="chapter1.xhtml"
      media-type="application/xhtml+xml"/>
    <item id="two" href="chapter2.xhtml"
      media-type="application/xhtml+xml"/>
    ${includeMissingImageManifestItem ? '<item id="missing-cover" href="images/missing-cover.jpg" media-type="image/jpeg"/>' : ''}
  </manifest>
  <spine toc="toc">
    <itemref idref="two"/>
    <itemref idref="one"/>
  </spine>
</package>
''');
  _addText(archive, 'OEBPS/toc.ncx', '''
<?xml version="1.0" encoding="UTF-8"?>
<ncx version="2005-1" xmlns="http://www.daisy.org/z3986/2005/ncx/">
  <head><meta name="dtb:uid" content="fixture"/></head>
  <docTitle><text>测试 EPUB</text></docTitle>
  <navMap>
    <navPoint id="one" playOrder="1">
      <navLabel><text>第一章</text></navLabel>
      <content src="chapter1.xhtml"/>
    </navPoint>
    <navPoint id="two" playOrder="2">
      <navLabel><text>第二章</text></navLabel>
      <content src="chapter2.xhtml"/>
    </navPoint>
  </navMap>
</ncx>
''');
  _addText(
    archive,
    'OEBPS/chapter1.xhtml',
    chapterOneHtml ??
        '<html xmlns="http://www.w3.org/1999/xhtml"><body>'
            '<h1>第一章</h1><p>第一段。</p></body></html>',
  );
  if (!missingSpineDocument) {
    _addText(
      archive,
      'OEBPS/chapter2.xhtml',
      '<html xmlns="http://www.w3.org/1999/xhtml"><body>'
          '<h1>第二章</h1><p>第二段。</p></body></html>',
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void _addText(Archive archive, String path, String content) {
  final bytes = utf8.encode(content);
  archive.addFile(ArchiveFile(path, bytes.length, bytes));
}
