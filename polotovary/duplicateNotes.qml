import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"
    
    property var score: null
    property var cursor: null
    //property var selection: null
    
    function findSegment(e) {
        while (e && e.type != Element.SEGMENT)
            e = e.parent;
        return e;
    }
    
    function cloneChord(chord){
        for (var i = 0; i < chord.notes.length; ++i){
            var note = chord.notes[i];
            cursor.addNote(note.pitch, i);
        }
    }
    
    onRun: {
        score = curScore;
        cursor = score.newCursor();
    }
    
    onScoreStateChanged: {
        if (state.selectionChanged && !state.undoRedo && state.startLayoutTick > -1){
            console.log("insert");
            var el = score ? score.selection.elements[0] : null;
            if ( el && el.type == Element.NOTE || el.type == Element.REST ) {
                var seg = findSegment(el);
                //var tick = state.startLayoutTick;
                var tick = seg.tick;
                var duration = el.duration || el.parent.duration;
                var tie = el.tieBack;
               
                console.log(duration.numerator, duration.denominator, " track: ", el.track, "tick: ", tick);
                
                cursor.rewindToTick(tick);
                cursor.track = el.track + 4;
                cursor.setDuration(duration.numerator, duration.denominator);
                
                console.log(cursor.track, cursor.tick);
                
                score.startCmd();
                if (el.type == Element.NOTE) {
                    //cursor.addNote(el.pitch);
                    cloneChord(el.parent);
                }
                else {
                    cursor.addRest();
                }
                score.endCmd();
                console.log(seg.prevInMeasure ? seg.prevInMeasure.elementAt(el.track) : seg.prev.elementAt(el.track));
                console.log(el.tieBack);
                if (tie) {
                    console.log("tie");
                    var note = tie.startNote;
                    var seg = findSegment(note);
                    var duration = note.parent.duration;
                    if (seg.elementAt(el.track+4).type == Element.REST) {
                        cursor.rewindToTick(seg.tick);
                        cursor.track = el.track + 4;
                        cursor.setDuration(duration.numerator, duration.denominator);
                        score.startCmd();
                        cursor.addNote(note.pitch);
                        score.endCmd();
                    }
                }
                //tie = newElement(Element.TIE);
            }
        }
    }
}
