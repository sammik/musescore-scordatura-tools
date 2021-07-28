import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"
    
    readonly property var notePitch: ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    readonly property var instrumentsTunings: {
        "strings.violin": ["G3", "D4", "A4", "E5"],
        "strings.viola": ["C3", "G3", "D4", "A4"],
        "strings.cello": ["C2", "G2", "D3", "A3"],
        "strings.viol": ["G3", "D4", "A4", "D5", "G5"]
    }
    
    function findTuning(instrument) {
        var instName = instrument.instrumentId;
        
        if (instrument.stringData.strings.length)
            return getStringData(instrument, true);
        else
            return (instrumentsTunings[instName] || []).toString();
    }
    
    function getStringData(instrument, names){ 
    
        var stringData = instrument.stringData,
            tuning = [];
        
        for (var i = 0; i < stringData.strings.length; ++i) {
            var pitch = stringData.strings[i].pitch;
            var name = notePitch[pitch %12] + (Math.floor(pitch/12)-1);
            tuning.push(names ? name : pitch);
        }
        
        return names ? tuning.toString() : tuning.reverse();
    }
    
    onRun: {
        console.log("hello world")
        var sel = curScore.selection.elements[0];
        var instrument = sel.staff.part.instruments[0];
        console.log(instrument.instrumentId);
        console.log(findTuning(instrument));
        Qt.quit()
    }
}
