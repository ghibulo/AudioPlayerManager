import 'package:toml/decoder.dart';
import 'dart:async';
import 'dart:io';
import 'dart:collection'; 
import 'dart:math';

List decodeTrackName(String trackName) {

    List listTrackName = trackName.split('=');

    if (listTrackName.length != 3) {
        print("the file ${trackName} don't have format of AudioPlayerManager");
        return null;
    }

    int order;
    try {
          order = int.parse(listTrackName[0]);
       } 
       on FormatException { 
          print("problem to convert order of the file ${listTrackName[2]} to int");
          return null;
       } 
    
    return [order, listTrackName];
}

String encodeTrackName(List<String> indexAlbumName) {

    if (indexAlbumName.length < 3) {
        throw new Exception("${indexAlbumName} can't be encoded!");
    }
    return "${indexAlbumName[0]}=${indexAlbumName[1]}=${indexAlbumName[2]}"
}


List getContentPlayer (String playerPathName) {

    var dir = new Directory(playerPathName);
    List contents = dir.listSync();
    Map<String,List<int>> result1 = {};
    Map<int,List<String>> result2 = {};
    for (var fileOrDir in contents) {
        if (fileOrDir is File) {
            String trackName = fileOrDir.path.split('/').last;
            print(trackName);
            List listTrack = decodeTrackName(trackName);
            if (listTrack != null) {
                result1[listTrack[1][2]] = (result1[listTrack[1][2]] == null)? [listTrack[0]] : result1[listTrack[1][2]].add(listTrack[0]); 
                result2[listTrack[0]] = listTrack[1];
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
        if ((theAlbum["state"] == "on")&&(theAlbum["order"] == order)) {
            result[albumItem] = allAlbums[albumItem];
        } else {
            //print("$albumItem switched off");
        }
    }
    return result;

}


Map<int,List<String>> createSongsLine(Map parsedConfig) {
    Map<int,List<String>> result = new Map<int,List<String>>();
    //it's useful to save limits in order to randomize tracks suitably
    Map<String,List> orderLimits = {"normal": [],       //[0, last_track_of_normal_interval]
                                    "shuffle": [],      //list of intervals where each of them is assigned to the shuffled album 
                                    "bigshuffle": []};  //[first_bigshuffle_track, last_bigshuffle_track]
    int index = 0;
    String lastOrder = "nothing";
    for (var theOrder in ["normal", "shuffle", "bigshuffle"]) {
        if ((lastOrder == "normal")&&(theOrder == "shuffle")&&(index>0)) {
            orderLimits["normal"] = [0,index-1];
        }

        if ((lastOrder == "shuffle")&&(theOrder == "bigshuffle")&&(index>0)) {
            orderLimits["bigshuffle"] = [index];
        }
        Map albums = getOnAlbums(parsedConfig["album"], theOrder);
        
        for (var albumItem in albums.keys) {
            String mirrorFolder = (albums[albumItem]["mirror_folder"]==null)? parsedConfig["mirror_folder"] : albums[albumItem]["mirror_folder"];
            List tracks = albums[albumItem]["tracks"];
            String folder = albums[albumItem]["folder"];
            int firstTrackIndex = index;
            for (var track in tracks) {
                if (track[0] == "on") {
                    result[index++] = ["${albumItem}${folder}", "${track[1]}", mirrorFolder];
                }
            }
            int lastTrackIndex = index-1;
            if ((theOrder == "shuffle")&&(lastTrackIndex>=firstTrackIndex)) {
               orderLimits["shuffle"].add([firstTrackIndex,lastTrackIndex]); 
            }
        }
        lastOrder = theOrder;
    }
    if (orderLimits["bigshuffle"][0]<index) {
        orderLimits["bigshuffle"].add(index-1);
    } else {
        orderLimits["bigshuffle"] = [];
    }
    print("orderLimits.... $orderLimits");
    //set indexes to the tracks
    if (orderLimits['normal'].length > 1) {
        for (int i=0; i <= orderLimits['normal'][1]; i++) {
            String theIndex = i.toString().padLeft(4, '0');
            result[i] = [theIndex] + result[i];
        }
    }

    if (orderLimits['shuffle'] != []) {
        for (List<int> interval in orderLimits['shuffle']) {
            List<int> permutation = getPermutation(interval[0], interval[1]);
            for (int i=interval[0]; i <= interval[1]; i++) {
                String theIndex = permutation[i-interval[0]].toString().padLeft(4, '0');
                result[i] = [theIndex] + result[i];
            }
        }
    }

    if (orderLimits['bigshuffle'].length > 1) {
        int infimum  = orderLimits['bigshuffle'][0];
        int supremum = orderLimits['bigshuffle'][1];
        for (int i=infimum; i <= supremum; i++) {
            List<int> permutation = getPermutation(infimum, supremum);
            String theIndex = permutation[i-infimum].toString().padLeft(4, '0');
            result[i] = [theIndex] + result[i];
        }
    }
    
    return result;
}

bool placeNumberInList(int number, int index, List theList) {
    int realIndex = index % theList.length;
    for (int i = 0; i<theList.length; i++) {
        if (theList[realIndex] == null) {
            theList[realIndex] = number;
            return true;
        }
        realIndex = (++realIndex < theList.length)? realIndex : 0;
    }
    return false;
}

List<int> getPermutation(int infimum, int supremum) {

    int scope = supremum-infimum+1;
    List<int> result = new List(scope);
    var rng = new Random();
    for (int i=0; i<scope; i++) {
        int rndIndex = rng.nextInt(scope);
        placeNumberInList(i+infimum, rndIndex, result);
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


void renameTrack(String path, String name, List configTrack) {

    File renamedFile = new File("${path}/${name}");
    String newPathName = "${path}/${encodeTrackName(configTrack)}"
    try {

        await renamedFile.rename("${newPathName}");
        print("Track ${name} renamed according ${configTrack}");

    } on FileSystemException catch (e) {
        File sourceFile = new File("${configTrack[3]}/${encodeTrackName(configTrack)}");
        final newFile = await sourceFile.copy(newPathName);
        print("Track ${configTrack} has to be copied to ${path}");
    }

}


void synchronize(Map<int,List<String>> wishLine, String mountFolder) {

    List contentPlayer = getContentPlayer (configData["mount_folder"]);

    Map<String,List<int>> testExistMap = contentPlayer[0];
    Map<int,List<String>> dataMap = contentPlayer[1];

    for (var item in wishLine.keys) {
        List<String> configTrack = wishLine[item];
        if (testExistMap[configTrack[2]] != null) {
            for (index in testExistMap[configTrack[2]) { //the same trackName in different albums
                List<String> playerTrack = dataMap[index];
                if (playerTrack[1] == configTrack[1]) { //albums equal
                   renameTrack("${mountFolder}/${encodeTrackName(playerTrack)}", configTrack); 
                }

            }
        }
        
    }
    

}

void main() {


  new File('sfsconfig.toml').readAsString().then((String contents) {
	var parser = new TomlParser();
    Map configData = new Map.from(parser.parse(contents).value);
    Map<int,List<String>> wishLine = createSongsLine(configData);
    for (var item in wishLine.keys) {
        List<String> name = wishLine[item];
        print("${item} - ${name} \n");
    }
	print("----");
    syncronize(wishLine, configData["mount_folder"]);
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


