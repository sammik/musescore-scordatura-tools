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
    
    function removeTies(chord){
        
        function removeTie(note){
            if (note.tieBack){
                removeElement(note.tieBack);
                //note.remove(note.tieBack);
            }
            if (note.tieForward){
                removeElement(note.tieForward);
                //note.remove(note.tieForward);
            }
        }
        
        for (var i = 0; i < chord.notes.length; ++i){
            var note = chord.notes[i];
            removeTie(note);
        }
        for (var i = 0; i < chord.graceNotes.length; ++i){
            var graceChord = chord.graceNotes[i];
            /*
            for (var j = 0; j < graceChord.notes.length; ++j) {
                var graceNote = graceChord.notes[j];
                removeTie(graceNote);
            }
            */
            removeTies(graceChord);
        }
        return chord;
    }
    
    function duplicate(el){
        
        var seg = findSegment(el);
        var tick = seg.tick;
        var chord = el.type == Element.NOTE ? (el.noteType == NoteType.NORMAL ? el.parent : el.parent.parent) : null;
        var duration = el.duration || chord.duration;
        
        cursor.rewindToTick(tick);
        cursor.track = el.track + 4;
        cursor.setDuration(duration.numerator, duration.denominator);
        
        score.startCmd();
        cursor.addRest();
        if (chord) {
            var newChord = removeTies(chord.clone());
            cursor.prev();
            cursor.add(newChord);
        }
        score.endCmd();
    }
    
    function ties(tie, back /*true*/){
        console.log("tie");
        
        var note = back ? tie.startNote : tie.endNote;
        
        duplicate(note);

        var tie = back ? note.tieBack : note.tieForward;
        if (tie){
            ties(tie, back);
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
            if ( el && el.type == Element.REST || el.type == Element.NOTE ) {
                
                duplicate(el);

                var tieBack = el.tieBack;
                var tieForward = el.tieForward;
                
                if (tieBack) {
                    console.log("tie back");
                    ties(tieBack, true);
                }
                if (tieForward){
                    console.log("tie forward");
                    ties(tieForward, false);
                }
            }
        }
    }
}
