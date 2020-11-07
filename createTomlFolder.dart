import 'package:toml/decoder.dart';
import 'dart:async';
import 'dart:io';
import 'dart:collection';

bool DEBUG = true;

void debugPrint(String what) {
  if (DEBUG) {
    print("Debug: $what");
  }
}

void writeAlbum (StringBuffer theOutput, String albumPathName) {

    debugPrint("writeAlbum: aplbumPathName = ${albumPathName}");
    String albumName = albumPathName.split('/').last;
    debugPrint("first line... [album.${albumName}]\n");
    theOutput. writeln('[album.${albumName}]');
    String mirrorFolder = albumPathName.replaceAll("/$albumName", '');
    theOutput.writeln('  mirror_folder="$mirrorFolder"');
    debugPrint('second line...   mirror_folder="$mirrorFolder"\n');
    theOutput.writeln('  folder="$albumName"');
    theOutput.writeln('  state="off"');
    theOutput.writeln('  order="normal" #normal/shuffle/bigshuffle');
    theOutput.writeln('  tracks =	[');

    var dir = new Directory(albumPathName);
    List contents = dir.listSync();
    bool first = true;
    for (var fileOrDir in contents) {
      if (fileOrDir is File) {
        String fileName = fileOrDir.path.split('/').last;
        if (first) {
            first = false;
        } else {
            theOutput.writeln(',');
        }
        theOutput.write('    ["on", "$fileName"]');
      } else if (fileOrDir is Directory) {
        print("Skipped folder: $fileOrDir.path");
      }
    }
    theOutput.writeln('\n  ]');
    theOutput.writeln();
}






  /*
    arguments[0]    - pathName for output toml file
    arguments[1]    - path of the song folder or folder of song folders
     */

void main(List <String> arguments)  {

  String generatedConfig = arguments[0];
  String dataFolder = arguments[1];

  var dir = new Directory(dataFolder);
  List contents = dir.listSync();
  StringBuffer output = new StringBuffer();

  if (contents[0] is File) { //only one album
    writeAlbum(output, dataFolder);
  } else { //create albums for all the subfolders
    for (var fileOrDir in contents) {
      if (fileOrDir is Directory) {
        writeAlbum(output, fileOrDir.path);
      }
    }//for

  }

  File fileOutput = new File(generatedConfig);
  var sinkOutput = fileOutput.openWrite(mode:  FileMode.append);
  sinkOutput.write(output.toString());
  sinkOutput.close();
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



