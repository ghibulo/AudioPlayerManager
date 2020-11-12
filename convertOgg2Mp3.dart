import 'dart:io';

bool DEBUG = true;

List<String> getContentFolder (String pathName, String fileExtension) {

    var dir = new Directory(pathName);
    List contents = dir.listSync();
    Set<String> result = {};
    for (var fileOrDir in contents) {
        if (fileOrDir is File) {
            if (fileOrDir.path.toLowerCase().endsWith(fileExtension)) {
                result.add(fileOrDir.path.split('/').last);
            }
        }
    }
    return result.toList(growable: false);
}

void main(List<String> arguments) async {

    if (arguments.length < 1) {
        throw new Exception("Start program with one argument (pathName to ogg-folder)!");
    }
    
    String oggPathNameFolder    = arguments[0];    
    String oggNameFolder        = oggPathNameFolder.split('/').last;
    String oggPathFolder        = oggPathNameFolder.replaceAll("/$oggNameFolder", '');
    List<String> oggContent     = getContentFolder (oggPathNameFolder, ".ogg");
    String mp3PathNameFolder    = "${oggPathFolder}/${oggNameFolder}_mp3";
    if (arguments.length >1) {
        mp3PathNameFolder    = arguments[1];
    }

    if (oggContent.isNotEmpty) {
        new Directory(mp3PathNameFolder).create(recursive: true)
            .then((Directory directory) async {
                print("OGG files converted to -> ${directory.path}");
                int i = 0;
                for (var oggFileName in oggContent) {
                    String mp3FileName = oggFileName.replaceRange(oggFileName.length-4, oggFileName.length, ".mp3");
                    String oggPathNameFile = "${oggPathNameFolder}/${oggFileName}";
                    String mp3PathNameFile = "${mp3PathNameFolder}/${mp3FileName}";
                    ProcessResult pr = await Process.run('ffmpeg', ['-i', oggPathNameFile, mp3PathNameFile]);

                    if (DEBUG) {
                      print("${i++}: ${oggPathNameFile} -> ${mp3PathNameFile}");
                    }
                }
            });
    } else {
        print("There is no ogg file in the ${oggPathNameFolder}");
    }



/*
  Process.run('ls', ['-l']).then((ProcessResult pr){
    //print(pr.exitCode);
    
    List lines = pr.stdout.split('\n');
    for (var line in lines) {
        print("-> $line");
    }
    //print(pr.stderr);
  });
    ProcessResult pr = await Process.run('ls', ['-l']);

    List lines = pr.stdout.split('\n');
    for (var line in lines) {
        print("-> $line");
    }
*/
}
