
class Track {
  String trackName;
  String mirrorFolder;
  String albumFolder;
  String configAlbum;
  int index;
  String previousState;

  String get mirrorLocation {
    if ((mirrorFolder == null) || (albumFolder == null)) {
      return null;
    }
    return "${mirrorFolder}/${albumFolder}";
  }

  bool get isEncodable {
    return (trackName != null) && (configAlbum != null) && (index != null);
  }

  String get encodeName {
    String theIndex = index.toString().padLeft(4, '0');
    if (previousState == null) {
      return "${theIndex}=${configAlbum}=${trackName}";
    }
    return "${theIndex}=${configAlbum}=${trackName}${previousState}";
  }

  void setIndex(int theIndex) {
    this.index = theIndex;
  }

  void setPreviousState(String previousState) { //".OFF" or ""
    this.previousState = previousState;
  }

  String getStringIndex() {
    return index.toString().padLeft(4, '0');
  }

  Track({this.trackName, this.mirrorFolder,this.albumFolder,this.configAlbum});

  String toString() {
    return "index: ${index}, trackName: ${trackName}, mirrorFolder: ${mirrorFolder}, albumFolder: ${albumFolder}, configAlbum: ${configAlbum}";
  }

}

