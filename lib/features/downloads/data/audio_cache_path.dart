import 'dart:io';

Directory audioCacheDirectoryForBook(Directory supportDirectory, int bookId) {
  return Directory(
    '${supportDirectory.path}${Platform.pathSeparator}speech_audio'
    '${Platform.pathSeparator}book-$bookId',
  );
}
