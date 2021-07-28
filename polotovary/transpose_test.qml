import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"
    onRun: {
        console.log("hello world")
        //Qt.quit()
    }
    onScoreStateChanged: {
        if (state.selectionChanged) {
            var el = curScore.selection.elements[0];
            if (el && el.type == Element.NOTE){
                el.pitch = el.pitch + 3;
            }
        }
    }
}
