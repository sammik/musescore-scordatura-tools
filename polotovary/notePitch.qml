import QtQuick 2.0
import QtQuick.Window 2.2
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"
    requiresScore: false

    readonly property var notePitch: ["C", "", "D", "", "E", "F", "", "G", "", "A", "", "B"]
    property var standTun: null
    //property var standTun: ["E5", "A4", "D#4", "Gb3"]
    property var test: "E5, A4, D4, L2"

    function nameToPitch(name){
        var nam = name[0].toUpperCase(),
            oct = parseInt( name[name.length - 1] ),
            pitch = notePitch.indexOf(nam) + (oct + 1) * 12;
        if (name.indexOf("#") !== -1)
            pitch = pitch + 1;
        if (name.indexOf("b") !== -1)
            pitch = pitch - 1;
        return pitch;
    }

    onRun: {
        standTun = test.split(/\s*,\s*/);
        console.log(standTun);
        /*for (var i = 0; i < standTun.length; ++i) {
            var st = standTun[i];
            console.log(st, ", ", nameToPitch(st));
        }*/
        Qt.quit()
    }
}
