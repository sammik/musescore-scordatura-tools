import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.Scordatura Tools.Hide Accidentals Of Selected Notes"
    description: "Hide all accidentals of selected notes"
    version: "0.1"
    requiresScore: true
    onRun: {
        var sel = curScore ? curScore.selection : null;
        if (sel) {
            for (var i = 0; i < sel.elements.length; ++i) {
                var element = sel.elements[i];
                if (element.type == Element.NOTE) {
                    var accidental = element.accidental;
                    if (accidental) {
                        console.log(accidental);
                        accidental.visible = false;
                    }
                }
            }
        }
        Qt.quit();
    }
}
