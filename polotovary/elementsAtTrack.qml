import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"
    onRun: {
        console.log("hello world")
        var cursor = curScore.newCursor();
        cursor.track = 1;
        cursor.rewindToTick(958);
        //cursor.next();
        //cursor.next();
        var segment = cursor.segment;
        console.log(cursor.tick);
        for (var i = 0; i < 4; ++i) {
            cursor.track = i;
            console.log("cursor: ", i, ", ", cursor.element);
            console.log("segment: ", i, ", ", segment.elementAt(i));
            var el = segment.elementAt(i);
            if (el && el.type == Element.CHORD) curScore.selection.select(el.notes[0]);
        }
        console.log(cursor.keySignature);
        
        
        Qt.quit()
        }
    }
