import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.Scordatura Tools"
    description: "sort notes"
    version: "0.1"
    requiresScore: true
    
    property var score: null
    property var cursor: null

    property var standardTuning: [76, 69, 62, 55]
    property var scordaturaTuning: [76, 69, 62, 55]
    property var tuning: standardTuning
    
    function guessString(pitch, tuning){
        for (var i = 0; i < tuning.length; ++i){
            var string = tuning[i];
            //TODO Crossed strings?
            if (pitch >= string)
                return i;
        }
        return false;
    }
    
    function getFret(pitch, stringValue){
        
        var fret = pitch - stringValue;
        
        // Check, if can be on that string
        if (fret > -1)
            return fret;
        else
            return false;
    }
    
    // all notes of segment (on specified tracks)
    function notesOnSegment(topTrack, bottomTrack, tuning){
        
        var seg = cursor.segment;
        var notes=[];
        
        for (var track = topTrack; track < bottomTrack + 1; ++track ) {
              var el = seg.elementAt(track);
              if (el && (el.type == Element.CHORD) ) {
                    for (var j = 0; j < el.notes.length; ++j ){
                        var note = el.notes[j],
                            userString = note.string > -1 ? true : false;
                        if (!userString)
                            note.string = guessString(note.pitch, tuning);
                        note.fret = getFret(note.pitch, tuning[note.string]);
                        var n = {
                            note: note,
                            userString: userString,
                            string: note.string,
                            pitch: note.pitch,
                            fret: note.fret
                            track: note.track
                        }
                        notes.push(note)
                    }
              }
        }
        return notes
    }
    
    // check if there are more than one notes with same string
    function hasDuplicateStrings(notes){
        var seen = {};
        var hasDuplicates = notes.some(function (currentObject) { //some doesnt work, need indexOf
            return seen.hasOwnProperty(currentObject.string) || (seen[currentObject.string] = false);
        });
        return hasDuplicates;
    }
    
    // sort given notes 1. strings top to bottom (0 - ...), 2. if same string - user set first, 3. if same string - higher pitch first
    function sortByStrings(notes){
        notes.sort(function(a, b) { 
            return (a.string > b.string) ? 1 : (a.string === b.string) ? ((a.userString < b.userString) ? 1 : (a.userString === b.userString) ? ((a.pitch < b.pitch) ? 1 : -1) : -1) : -1 )
        }
        return notes;
    }
    
    function validateStrings(notes, tuning){
        var tunLength = standardTuning.length;
        
        // if more notes, than strings, return false
        if (notes.length > tunLength)
            return false;
        
        //compare neigbours, second have to be lower; if not possible, return false
        for (var i = 0; i < (notes.length - 1); ++i){
            var a = notes[i],
                b = notes[i+1];
            if (!(a.string < b.string)){
                    //is user-set || no more lower strings
                if ( b.userString || a.string === tunLength - 1)
                    return false;
                notes[i+1].string = a.string + 1;
                notes[i+1].fret = getFret(b.pitch, tuning[b.string])
            }
        }

        // if upper string is not neigbour, lower it; if is too far, return false
        for (var i = (notes.length - 1); i > 0; --i){
            var a = notes[i],
                b = notes[i-1];
            if (b.string < a.string - 1){
                   //is user-set || is too far
                if (b.userstring || b.string < a.string - 2)
                    return false;
                notes[i-1].string = a.string - 1;
                notes[i-1].fret = getFret(b.pitch, tuning[b.string])
            }
        }
    
        return notes
    }


    onRun: {
        if (standardTuning.length !== scordaturaTuning.length){
            console.log("Both tunings needs to have same number of strings! EXIT")
            Qt.quit();
        }
        
        cursor = curScore.newCursor();
        //cursor.rewind(Cursor.SCORE_START);
        
        
        Qt.quit();
    }
}
