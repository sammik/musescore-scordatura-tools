import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"
    function getNoteIndex(note){
        
        if (note.type !== Element.NOTE) return -1
        
        var chord = note.parent;
        for ( var i = 0; i < chord.notes.length; ++i){
            if (chord.notes[i].is(note)) return i;
        }
        //return false
    }
    
    onRun: {
        console.log("hello world")
        var note = curScore.selection.elements[0];
        console.log(getNoteIndex(note));
        Qt.quit()
    }
}
