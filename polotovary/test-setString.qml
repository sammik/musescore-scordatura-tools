import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"
    
    pluginType: "dock"
    dockArea:   "right"

    width:  300
    height: 300

    property var tuning: [76, 69, 62, 55]

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
    
    onRun: {
        console.log("hello world")
        
        for (var seg = curScore.firstSegment(); seg; seg = seg.next) {
            for (var track = curScore.ntracks; track-- > 0; ) {
                var el = seg.elementAt(track);
                if (el && (el.type == Element.CHORD)) {
                    for (var noteIdx = el.notes.length; noteIdx-- > 0; ) {
                        curScore.startCmd();
                        el.notes[noteIdx].string = guessString(el.notes[noteIdx].pitch, tuning);
                        el.notes[noteIdx].fret = getFret(el.notes[noteIdx].pitch, tuning[el.notes[noteIdx].string]);
                    }
                }
            }
        }
        curScore.endCmd();
    }
    
    onScoreStateChanged: {
        if (state.selectionChanged) {
            var el = curScore.selection.elements[0];
            if (el && el.type == Element.NOTE){
                console.log("string: ", el.string, " , fret: ", el.fret);
            }
        }
    }
}
