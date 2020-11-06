import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'dart:math';


bool DEBUG = true;

void debugPrint(String what) {
  if (DEBUG) {
    print("Debug: $what");
  }
}

bool placeNumberInList(int number, int index, List theList) {
  int realIndex = index % theList.length;
  for (int i = 0; i < theList.length; i++) {
    if (theList[realIndex] == null) {
      theList[realIndex] = number;
      return true;
    }
    realIndex = (++realIndex < theList.length) ? realIndex : 0;
  }
  return false;
}

List<int> getPermutation(int infimum, int supremum) {
  int scope = supremum - infimum + 1;
  List<int> result = new List(scope);
  var rng = new Random();
  for (int i = 0; i < scope; i++) {
    int rndIndex = rng.nextInt(scope);
    placeNumberInList(i + infimum, rndIndex, result);
  }
  return result;
}



Map<int, String> getContentFolder(String pathName) {
  debugPrint("getContentFolder: playerPathName = ${pathName}");

  var dir = new Directory(pathName);
  List contents = dir.listSync();
  Map<int, String> indexFileLine = {};
  int index = 0;
  for (var fileOrDir in contents) {
    if (fileOrDir is File) {
      String trackName = fileOrDir.path.split('/').last;
      debugPrint(trackName);
      indexFileLine[index++] = trackName;
    }
  }
  return indexFileLine;
}


void moveFile(File sourceFile, String newPath) async {
  try {
    // prefer using rename as it is probably faster
    await sourceFile.rename(newPath);
  } on FileSystemException catch (e) {
    // if rename fails, copy the source file and then delete it
    final newFile = await sourceFile.copy(newPath);
    await sourceFile.delete();
  }
}

Future<void> splitFiles(Map<int,String> fileLines, String pathName, String rootName, int maxFiles, bool isShuffle) async {


  List<int>  shufflePermutation = null;
  if (isShuffle) {
    shufflePermutation = getPermutation(0, fileLines.length-1);
  }

  int indexFolder = 0;
  int firstIndex = 0;
  while (fileLines[firstIndex] != null) {

    String subfolderIndex = (indexFolder++).toString().padLeft(3, '0');
    String subfolderPathName = '${pathName}/${rootName}_${subfolderIndex}';
    await new Directory(subfolderPathName).create(recursive: true);
      debugPrint("Directory.path = ${subfolderPathName}");

      int index = firstIndex;
      while (index < (firstIndex + maxFiles)) {
        int indexOfFile = (isShuffle) ? shufflePermutation[index++] : index++;
        String srcPathName = "${pathName}/${fileLines[indexOfFile]}";
        debugPrint("${srcPathName} -> ${subfolderPathName}/${fileLines[indexOfFile]}");
        File fileForMoving = new File(srcPathName);
        moveFile(fileForMoving, "${subfolderPathName}/${fileLines[indexOfFile]}");
        if (fileLines[index] == null) {
          break;
        }
      }
      firstIndex = (firstIndex + maxFiles);


  }//while (fileLines[fir

}//split


/*
  arguments[0]    - pathName folder for splitting
  arguments[1]    - rootName for subfolders
  arguments[2]    - number songs per subfolder
  arguments[3]    - s -> shuffle
                    n -> alphabetically
   */
void main(List <String> arguments)  {

  int maxSongsPerSubfolder = int.parse(arguments[2]);
  Map<int, String> trackLine =  getContentFolder(arguments[0]);
  splitFiles(trackLine, arguments[0], arguments[1], maxSongsPerSubfolder, (arguments[3].toUpperCase() == "S") );

}
