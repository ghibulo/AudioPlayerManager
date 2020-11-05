import 'package:toml/decoder.dart';
import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'dart:math';

bool DEBUG = true;

void debugPrint(String what) {
  if (DEBUG) {
    print(what);
  }
}

bool stateOfTrack(String pathName) {
  List<String> listPathName = pathName.split("=");
  if (pathName.split("=").length != 3) {
    //AudioPlayerManager doesn't take care of this file
    return false;
  }
  listPathName = pathName.split(".");
  if (listPathName.last.toUpperCase() == "OFF") {
    return false;
  }
  return true;
}

Map<String, String> switchTrack(bool on, String pathName) {
  List<String> listPathName = pathName.split(".");
  if (listPathName.last.toUpperCase() == "OFF") {
    if (on) {
      listPathName.removeAt(listPathName.length - 1);
      return {"switched": listPathName.join("."), "previous": ".OFF"};
    }
    return {"switched": pathName, "previous": ".OFF"};
  } else {
    if (on) {
      return {"switched": pathName, "previous": ""};
    }
    return {"switched": "${pathName}.OFF", "previous": ""};
  }
}

List decodeTrackName(String trackName) {
  //get the trackname into ON state
  Map<String, String> mapSwitchedTrack = switchTrack(true, trackName);
  List listTrackName = mapSwitchedTrack["switched"].split('=');

  if (listTrackName.length != 3) {
    print("the file ${trackName} don't have format of AudioPlayerManager");
    return null;
  }

  int order;
  try {
    order = int.parse(listTrackName[0]);
  } on FormatException {
    print("problem to convert order of the file ${listTrackName[2]} to int");
    return null;
  }

  listTrackName.add(mapSwitchedTrack["previous"]);

  return [order, listTrackName];
}

String encodeTrackName(List<String> indexAlbumName) {
  if (indexAlbumName.length < 3) {
    throw new Exception("${indexAlbumName} can't be encoded!");
  }
  if (indexAlbumName.length > 3) {
    //indexAlbumName[3] could be ".OFF" or ""
    return "${indexAlbumName[0]}=${indexAlbumName[1]}=${indexAlbumName[2]}${indexAlbumName[3]}";
  }
  return "${indexAlbumName[0]}=${indexAlbumName[1]}=${indexAlbumName[2]}";
}

List getContentPlayer(String playerPathName) {
  debugPrint("getContentPlayer: playerPathName = ${playerPathName}");

  var dir = new Directory(playerPathName);
  List contents = dir.listSync();
  Map<String, List<int>> result1 = {};
  Map<int, List<List<String>>> result2 = {};
  for (var fileOrDir in contents) {
    if (fileOrDir is File) {
      String trackName = fileOrDir.path.split('/').last;
      debugPrint(trackName);
      List listTrack = decodeTrackName(trackName);
      if (listTrack != null) {
        //result1[listTrack[1][2]] = ( (result1[listTrack[1][2]] == null) ? [listTrack[0]] : result1[listTrack[1][2]].add(listTrack[0]) );
        if (result1[listTrack[1][2]] == null) {
          result1[listTrack[1][2]] = [listTrack[0]];
        } else {
          result1[listTrack[1][2]].add(listTrack[0]);
        }
        result2[listTrack[0]] = (result2[listTrack[0]] == null) ? [listTrack[1]] : result2[listTrack[0]] + [listTrack[1]];
      }
    }
  }
  return [result1, result2];
}

Map getOnAlbums(Map allAlbums, String order) {
  Map result = {};
  for (var albumItem in allAlbums.keys) {
    Map theAlbum = allAlbums[albumItem];
    //print("$albumItem -${theAlbum['state']} ");
    if ((theAlbum["state"] == "on") && (theAlbum["order"] == order)) {
      result[albumItem] = allAlbums[albumItem];
    } else {
      //print("$albumItem switched off");
    }
  }
  return result;
}

Map<int, List<String>> createSongsLine(Map parsedConfig) {
  Map<int, List<String>> result = new Map<int, List<String>>();
  //it's useful to save limits in order to randomize tracks suitably
  Map<String, List> orderLimits = {
    "normal": [],
    //[0, last_track_of_normal_interval]
    "shuffle": [],
    //list of intervals where each of them is assigned to the shuffled album
    "bigshuffle": []
  }; //[first_bigshuffle_track, last_bigshuffle_track]
  int index = 0;
  String lastOrder = "nothing";
  for (var theOrder in ["normal", "shuffle", "bigshuffle"]) {
    if ((lastOrder == "normal") && (theOrder == "shuffle") && (index > 0)) {
      orderLimits["normal"] = [0, index - 1];
    }

    if ((lastOrder == "shuffle") && (theOrder == "bigshuffle") && (index > 0)) {
      orderLimits["bigshuffle"] = [index];
    }
    Map albums = getOnAlbums(parsedConfig["album"], theOrder);

    for (var albumItem in albums.keys) {
      String mirrorFolder = (albums[albumItem]["mirror_folder"] == null)
          ? parsedConfig["mirror_folder"]
          : albums[albumItem]["mirror_folder"];
      List tracks = albums[albumItem]["tracks"];
      String folder = albums[albumItem]["folder"];
      int firstTrackIndex = index;
      for (var track in tracks) {
        if (track[0] == "on") {
          result[index++] = ["${folder}", "${track[1]}", "", mirrorFolder];
        }
      }
      int lastTrackIndex = index - 1;
      if ((theOrder == "shuffle") && (lastTrackIndex >= firstTrackIndex)) {
        orderLimits["shuffle"].add([firstTrackIndex, lastTrackIndex]);
      }
    }
    lastOrder = theOrder;
  }
  if (orderLimits["bigshuffle"][0] < index) {
    orderLimits["bigshuffle"].add(index - 1);
  } else {
    orderLimits["bigshuffle"] = [];
  }
  debugPrint("orderLimits.... $orderLimits");
  //set indexes to the tracks
  if (orderLimits['normal'].length > 1) {
    for (int i = 0; i <= orderLimits['normal'][1]; i++) {
      String theIndex = i.toString().padLeft(4, '0');
      result[i] = [theIndex] + result[i];
    }
  }

  if (orderLimits['shuffle'] != []) {
    for (List<int> interval in orderLimits['shuffle']) {
      List<int> permutation = getPermutation(interval[0], interval[1]);
      for (int i = interval[0]; i <= interval[1]; i++) {
        String theIndex =
            permutation[i - interval[0]].toString().padLeft(4, '0');
        result[i] = [theIndex] + result[i];
      }
    }
  }

  if (orderLimits['bigshuffle'].length > 1) {
    int infimum = orderLimits['bigshuffle'][0];
    int supremum = orderLimits['bigshuffle'][1];
    for (int i = infimum; i <= supremum; i++) {
      List<int> permutation = getPermutation(infimum, supremum);
      String theIndex = permutation[i - infimum].toString().padLeft(4, '0');
      result[i] = [theIndex] + result[i];
    }
  }

  return result;
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

Future<File> moveFile(File sourceFile, String newPath) async {
  try {
    // prefer using rename as it is probably faster
    return await sourceFile.rename(newPath);
  } on FileSystemException catch (e) {
    // if rename fails, copy the source file and then delete it
    final newFile = await sourceFile.copy(newPath);
    await sourceFile.delete();
    return newFile;
  }
}

void renameTrack(String path, String name,
    {List listNewName, String stringNewName}) async {
  String newPathName = null;
  String optionalParameter = stringNewName;
  if (listNewName != null) {
    debugPrint(
        "renameTrack: path=${path}, name=${name}, listNewName=${listNewName}");
    newPathName = "${path}/${encodeTrackName(listNewName)}";
    optionalParameter = "${listNewName}";
  }
  if (stringNewName != null) {
    debugPrint(
        "renameTrack: path=${path}, name=${name}, stringNewName=${stringNewName}");
    newPathName = "${path}/${stringNewName}";
  }
  if (newPathName == null) {
    throw new Exception(
        "Function renameTrack needs either listNewName or stringNewName!");
  }
  String renamedPathName = "${path}/${name}";
  if (renamedPathName == newPathName) {
    print("Useless to rename the same file ${renamedPathName}");
    return;
  }
  File renamedFile = new File(renamedPathName);
  try {
    await renamedFile.rename("${newPathName}");
    debugPrint("Track ${name} renamed according ${optionalParameter}");
  } on FileSystemException catch (e) {
    if (listNewName != null) {
      File sourceFile = new File(
          "${listNewName[3]}/${encodeTrackName(listNewName)}");
      final newFile = await sourceFile.copy(newPathName);
      debugPrint("Track ${listNewName} has to be copied to ${path}");
    } else {
      print("There is problem to rename/copy path=${path}, name=${name}, stringNewName=${stringNewName}: ${e}");
    }
  }
}

void synchronize(Map<int, List<String>> wishLine, String mountFolder) async {
  List contentPlayer = getContentPlayer(mountFolder);

  Map<String, List<int>> testExistMap = contentPlayer[0];
  Map<int, List<List<String>>> dataMap = contentPlayer[1];

  debugPrint("testExistMap = ${testExistMap}");
  debugPrint("dataMap = ${dataMap}");

  for (var item in wishLine.keys) {
    int found = -1;
    List<String> configTrack = wishLine[item];
    debugPrint("synchronize: configTrack = ${configTrack}");
    if (testExistMap[configTrack[2]] != null) {
      debugPrint("synchronize: testExistMap = ${testExistMap[configTrack[2]]}");
      for (var index in testExistMap[configTrack[2]]) {
        //the same trackName in different albums
        List<String> foundPlayerTrack = null;
        for (List<String> playerTrack in dataMap[index]) {
          if ((playerTrack[1] == configTrack[1]) &&
              (playerTrack[2] == configTrack[2])) {
            //albums equal
            debugPrint(
                "playerTrack = ${playerTrack} will be renamed -> $configTrack");
            renameTrack("${mountFolder}", "${encodeTrackName(playerTrack)}",
                listNewName: configTrack);
            foundPlayerTrack = playerTrack;
            if (dataMap[index].length == 1) {
              //more songs with the same index -> the other must be renamed to OFF
              found = index;
            }
            break;
          } else {
            debugPrint(
                "playerTrack = ${playerTrack} isn't equal to  $configTrack");
          }
        }//for (var playerTrack in dataMap...
        if (foundPlayerTrack != null) {
          dataMap[index].remove(foundPlayerTrack);
        }
      }//for (var index...
    } else {
      String configTrackName = "${encodeTrackName(configTrack)}";
      debugPrint(
          "copying ${configTrack[4]}/${configTrack[1]}/${configTrack[2]} -> ${mountFolder}/${configTrackName}");

      String newPathName = "${mountFolder}/${configTrackName}";
      File sourceFile =
          new File("${configTrack[4]}/${configTrack[1]}/${configTrack[2]}");
      final newFile = await sourceFile.copy(newPathName);
    }
    if (found > -1) {
      testExistMap[configTrack[2]]
          .remove(found); //the rest will be renamed by extension 'off'
    }
  }
  debugPrint("the remaining files in the mountFolder must be renamed to off");
  debugPrint("testExistMap = ${testExistMap}");
  debugPrint("dataMap = ${dataMap}");
  for (var item in testExistMap.keys) {
    for (var index in testExistMap[item]) {
      List<List<String>> switchedOff = [];
      for (List<String> playerTrack in dataMap[index]) {
        String trackToOff = encodeTrackName(playerTrack);
        Map<String, String> stateTheTrack = switchTrack(false, trackToOff);
        if (stateTheTrack["previous"] != ".OFF") {
          renameTrack("${mountFolder}", trackToOff,
              stringNewName: stateTheTrack["switched"]);
          switchedOff.add(playerTrack);
        }
      }//for (List<String> playerTrack...
      //what was renamed to OFF must be removed from dataMap[index]
      //to avoid trying to rename it again
      for (List<String> switchedOffTrack in switchedOff) {
        dataMap[index].remove(switchedOffTrack);
      }
    }
  }
}

void main(List<String> arguments) {
  if (arguments.length != 1) {
    throw new Exception("Start program with one argument (pathName to the config)! ... e.g. dart tomb.dart config.toml");
  }
  new File('sfsconfig.toml').readAsString().then((String contents) {
    var parser = new TomlParser();
    Map configData = new Map.from(parser.parse(contents).value);
    Map<int, List<String>> wishLine = createSongsLine(configData);
    for (var item in wishLine.keys) {
      List<String> name = wishLine[item];
      debugPrint("${item} - ${name} \n");
    }
    debugPrint("----");
    synchronize(wishLine, configData["mount_folder"]);
  });

/*
----------------------------------------
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
}
