import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"
    
    property var score: null
    property var cursor: null
    property var translate: true
    //property var selection: null
    
    function findSegment(e) {
        while (e && e.type != Element.SEGMENT)
            e = e.parent;
        return e;
    }
    
    function removeTies(chord){
        for (var i = 0; i < chord.notes.length; ++i){
            var note = chord.notes[i];
            if (note.tieBack){
                //removeElement(note.tieBack);
                note.remove(note.tieBack);
            }
            if (note.tieForward){
                //removeElement(note.tieForward);
                note.remove(note.tieForward);
            }
        }
        return chord;
    }
    
    onRun: {
        score = curScore;
        cursor = score.newCursor();
    }
    
    onScoreStateChanged: {
        if (translate && state.selectionChanged && !state.undoRedo && state.startLayoutTick > -1){
            console.log("insert");
            
            var el = score ? score.selection.elements[0] : null;
            
            if ( el && el.type == Element.NOTE ) {
                translate = false;
                var startTick = el.firstTiedNote.parent.parent.tick;
                var endTick = el.lastTiedNote.parent.parent.next.tick + 1;
                console.log(startTick, endTick);
                cmd("escape");
                score.selection.selectRange(startTick, endTick, el.track, el.track);
                cmd("copy");
                score.selection.selectRange(startTick, endTick, el.track + 4, el.track + 4);
                score.startCmd();
                cmd("delete");
                cmd("paste");
                score.selection.clear();
                score.selection.select(el);
                cmd("note-input");
                score.endCmd();
                translate = true;
            }
            else if ( el && el.type == Element.REST ) {
                var tick = el.parent.tick;
                var duration = el.duration;
                cursor.rewindToTick(tick);
                cursor.track = el.track + 4;
                cursor.setDuration(duration.numerator, duration.denominator);
                
                console.log(cursor.track, cursor.tick);
                
                score.startCmd();
                cursor.addRest();
                score.endCmd();
            }
        }
    }
}
