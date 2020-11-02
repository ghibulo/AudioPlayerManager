import 'package:toml/decoder.dart';
import 'dart:async';
import 'dart:io';
import 'dart:collection'; 

void writeAlbum (String outputPathName, String albumPathName) {
    File fileOutput = new File(outputPathName);
    var sinkOutput = fileOutput.openWrite();
    sinkOutput.write('[album.x]\n');
    String albumName = albumPathName.split('/').last;
    String mirrorFolder = albumPathName.replaceAll("/$albumName", '');
    sinkOutput.write('  mirror_folder="$mirrorFolder"\n');
    sinkOutput.write('  folder="$albumName"\n');
    sinkOutput.write('  state="on"\n');
    sinkOutput.write('  order="normal" #normal/shuffle/bigshuffle\n');
    sinkOutput.write('  tracks =	[\n');

    var dir = new Directory(albumPathName);
    List contents = dir.listSync();
    bool first = true;
    for (var fileOrDir in contents) {
      if (fileOrDir is File) {
        String fileName = fileOrDir.path.split('/').last;
        if (first) {
            first = false;
        } else {
            sinkOutput.write(',\n');
        }
        sinkOutput.write('    ["on", "$fileName"]');
      } else if (fileOrDir is Directory) {
        print("Skipped folder: $fileOrDir.path");
      }
    }
    sinkOutput.write('\n  ]\n');
    sinkOutput.close();
}

    
	


 

void main(List <String> arguments)  {

    writeAlbum('./album.toml', arguments[0]);
}

/*
  new File('sfsconfig.toml').readAsString().then((String contents) {
	var parser = new TomlParser();
	var document = parser.parse(contents).value;
	print(document);
	print("----");
  });

  new File('file.txt').readAsString().then((String contents) {
	var parser = new TomlParser();
	var document = parser.parse(contents).value;
	print(document);
	print("----");
	print(document["plugins"]);
	print(document["plugins"]["diff"]);
	print(document["plugins"]["diff"]["default"][1]);
  });
*/



