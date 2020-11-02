import 'package:toml/decoder.dart';
import 'dart:async';
import 'dart:io';
import 'dart:collection'; 
import 'dart:math';


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

void main() {


  new File('sfsconfig.toml').readAsString().then((String contents) {
	var parser = new TomlParser();
    Map moje = new Map.from(parser.parse(contents).value);
	//print(moje);
    Map<int,List<String>> theLine = createSongsLine(moje);
    for (var item in theLine.keys) {
        List<String> name = theLine[item];
        print("${item} - ${name} \n");
    }
	print("----");
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


