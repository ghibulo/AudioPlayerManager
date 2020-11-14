//import 'dart:html';

import 'package:toml/decoder.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'Track.dart';


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

Track decodeTrackName(String trackName) {
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
  Track result = Track(trackName: listTrackName[2],configAlbum: listTrackName[1]);
  result.setIndex(order);
  result.setPreviousState(mapSwitchedTrack["previous"]);
  return result;
}

String encodeTrackName(Track theTrack) {
  if (theTrack.isEncodable) {
    return theTrack.encodeName;
  } else {
    throw new Exception("${theTrack} can't be encoded!");
  }
}

//return Map trackName -> index, Map index -> List<Track>
List getContentPlayer(String playerPathName) {
  debugPrint("getContentPlayer: playerPathName = ${playerPathName}");

  var dir = new Directory(playerPathName);
  List contents = dir.listSync();
  Map<String, List<int>> result1 = {};
  Map<int, List<Track>> result2 = {};
  for (var fileOrDir in contents) {
    if (fileOrDir is File) {
      String trackName = fileOrDir.path.split('/').last;
      debugPrint(trackName);
      Track theTrack = decodeTrackName(trackName);
      if (theTrack != null) {
        //result1[listTrack[1][2]] = ( (result1[listTrack[1][2]] == null) ? [listTrack[0]] : result1[listTrack[1][2]].add(listTrack[0]) );
        if (result1[theTrack.trackName] == null) {
          result1[theTrack.trackName] = [theTrack.index];
        } else {
          result1[theTrack.trackName].add(theTrack.index);
        }
        result2[theTrack.index] = (result2[theTrack.index] == null) ? [theTrack] : result2[theTrack.index] + [theTrack];
      }
    }
  }
  return [result1, result2];
}

Map getOnAlbums(Map activeConfigMap, String order) {
  Map result = {};
  for (var albumItem in activeConfigMap.keys) {
    if (activeConfigMap[albumItem].runtimeType == String) {
      continue;
    }
    Map theAlbum = activeConfigMap[albumItem];
    if ((theAlbum["tracks"] != null)&&(theAlbum["order"] == order)) {
      //print("$albumItem -${theAlbum['state']} ");
      result[albumItem] = activeConfigMap[albumItem];
    }
  }
  return result;
}


String getMirrorFolder(sourceConfig, albumItem) {
  print("getMirrorFolder: ${sourceConfig}, ${albumItem}");
  if (sourceConfig==null) {
    return null;
  }
  String root = (sourceConfig["root"] == null) ? "" : sourceConfig["root"];
  String result = sourceConfig[albumItem]["mirror_folder"];
  if (result == null) {
    return null;
  } else {
    return (result[0] == ".") ? (root + result.substring(1)) : result;
  }
}

Future<Map<int, Track>> createSongsLine(Map activeConfig) async {
  //attempt to get sourceConfig
  Map sourceConfig = null;
  if (activeConfig["source_config"] != null) {
    sourceConfig = await getMapFromConfig(activeConfig["source_config"]);
  }
  if (sourceConfig == null) {
    print("There is problem to get data from source_config -> only saved track on the mount_folder can be utilized");
  }
  Map<int, Track> result = new Map<int, Track>();
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

    if ((lastOrder == "shuffle") && (theOrder == "bigshuffle")) {
      orderLimits["bigshuffle"] = [index];
    }
    //get all on-albums with order: >theOrder<
    Map albums = getOnAlbums(activeConfig, theOrder);
    print ("albums on: ${albums}");

    for (var albumItem in albums.keys) {

      String mirrorFolder = getMirrorFolder(sourceConfig, albumItem);
      List tracks = albums[albumItem]["tracks"];
      String folder = sourceConfig[albumItem]["folder"];
      int firstTrackIndex = index;
      for (var track in tracks) {
          result[index++] = new Track(trackName: track, mirrorFolder: mirrorFolder, albumFolder: folder, configAlbum: albumItem);
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
      result[i].setIndex(i);
    }
  }

  if (orderLimits['shuffle'] != []) {
    for (List<int> interval in orderLimits['shuffle']) {
      List<int> permutation = getPermutation(interval[0], interval[1]);
      for (int i = interval[0]; i <= interval[1]; i++) {
        result[i].setIndex(permutation[i - interval[0]]);
      }
    }
  }

  if (orderLimits['bigshuffle'].length > 1) {
    int infimum = orderLimits['bigshuffle'][0];
    int supremum = orderLimits['bigshuffle'][1];
    for (int i = infimum; i <= supremum; i++) {
      List<int> permutation = getPermutation(infimum, supremum);
      result[i].setIndex(permutation[i - infimum]);
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
    print("${e} -> must be copied");
    final newFile = await sourceFile.copy(newPath);
    await sourceFile.delete();
    return newFile;
  }
}

void renameTrack(String path, String name,
    {Track objNewName, String stringNewName}) async {
  String newPathName = null;
  String optionalParameter = stringNewName;
  if (objNewName != null) {
    newPathName = "${path}/${encodeTrackName(objNewName)}";
    debugPrint(
        "renameTrack: path=${path}, name=${name}, objNewName=${objNewName}, newPathName=${newPathName}");
    optionalParameter = "${objNewName}";
  }
  if (stringNewName != null) {
    newPathName = "${path}/${stringNewName}";
    debugPrint(
        "renameTrack: path=${path}, name=${name}, stringNewName=${stringNewName}, newPathName=${newPathName}");
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
    String mirrorLocation = objNewName.mirrorLocation;
    if ((objNewName != null) && (mirrorLocation != null)) {
      File sourceFile = new File( "${mirrorLocation}/${objNewName.trackName}");
      final newFile = await sourceFile.copy(newPathName);
      debugPrint("Track ${objNewName} has to be copied to ${path}");
    } else {
      print("There is problem to rename/copy path=${path}, name=${name}, stringNewName=${stringNewName}: ${e}");
    }
  }
}

//syncronize wishLine with the state of mounted folder
void synchronize(Map<int, Track> wishLine, String mountFolder) async {
  List contentPlayer = getContentPlayer(mountFolder);

  Map<String, List<int>> testExistMap = contentPlayer[0];
  Map<int, List<Track>> dataMap = contentPlayer[1];

  debugPrint("testExistMap = ${testExistMap}");
  debugPrint("dataMap = ${dataMap}");

  for (var item in wishLine.keys) {
    int found = -1;
    Track configTrack = wishLine[item];
    debugPrint("synchronize: configTrack = ${configTrack}");
    if (testExistMap[configTrack.trackName] != null) {
      debugPrint("synchronize: testExistMap = ${testExistMap[configTrack.trackName]}");
      for (var index in testExistMap[configTrack.trackName]) {
        //the same trackName in different albums
        Track foundPlayerTrack = null;
        for (Track playerTrack in dataMap[index]) {
          if ((playerTrack.configAlbum == configTrack.configAlbum) &&
              (playerTrack.trackName == configTrack.trackName)) {
            //albums equal
            debugPrint(
                "playerTrack = ${playerTrack} will be renamed -> $configTrack");
            renameTrack("${mountFolder}", "${encodeTrackName(playerTrack)}",
                objNewName: configTrack);
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
          "copying ${configTrack.mirrorLocation}/${configTrack.trackName} -> ${mountFolder}/${configTrackName}");

      String newPathName = "${mountFolder}/${configTrackName}";
      File sourceFile =
          new File("${configTrack.mirrorLocation}/${configTrack.trackName}");
      final newFile = await sourceFile.copy(newPathName);
    }
    if (found > -1) {
      testExistMap[configTrack.trackName]
          .remove(found); //the rest will be renamed by extension 'off'
    }
  }
  debugPrint("the remaining files in the mountFolder must be renamed to off");
  debugPrint("testExistMap = ${testExistMap}");
  debugPrint("dataMap = ${dataMap}");
  for (var item in testExistMap.keys) {
    for (var index in testExistMap[item]) {
      List<Track> switchedOff = [];
      for (Track playerTrack in dataMap[index]) {
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
      for (Track switchedOffTrack in switchedOff) {
        dataMap[index].remove(switchedOffTrack);
      }
    }
  }
}

//get Map from toml config or null in case of problems
Future<Map> getMapFromConfig(String pathName) async {

  if (pathName == null) {
    print("Warning: getMapFromConfig got input parameter = null -> no data");
    return null;
  }
  Map result = null;
  try {
    String contents = await new File(pathName).readAsString();
    var parser = new TomlParser();
    result = new Map.from(parser.parse(contents).value);
  } catch(e) {
    print("Warning: there is problem to read data from config ${pathName}: ${e}");
  }
  return result;
}

void main(List<String> arguments) async {
  if (arguments.length != 1) {
    throw new Exception("Start program with one argument (pathName to the config)! ... e.g. dart tomb.dart config.toml");
  }

  Map configData = await getMapFromConfig(arguments[0]);
  if (configData == null) {
    print("There is problem to get data from activeConfig ${arguments[0]}");
    print("Useless to continue!");
    return;
  }
  Map<int, Track> wishLine = await createSongsLine(configData);
  for (var item in wishLine.keys) {
    Track theTrack = wishLine[item];
    debugPrint("${item} - ${theTrack} \n");
  }
  debugPrint("----");
  synchronize(wishLine, configData["mount_folder"]);
}

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
