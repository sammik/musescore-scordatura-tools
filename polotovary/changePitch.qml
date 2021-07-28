import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"

    pluginType: "dock"
    dockArea:   "right"

    width:  226
    height: 120
    
    readonly property var notePitch: ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    readonly property var noteTpc: ["F", "C", "G", "D", "A", "E", "B"]
    
    property var tunings: []
    
    function getTun(stringDef) {
        if (!stringDef) return;
        var strgs = stringDef.toUpperCase().split(/\s*,\s*/).reverse();
        var tun = [];

        for (var i = 0; i < strgs.length; ++i) {
            var name = strgs[i],
                oct = parseInt( name[name.length - 1] ),
                pitch = notePitch.indexOf(name[0]) + (oct + 1) * 12,
                tpc = noteTpc.indexOf(name[0]) + 13;
            if ( name.indexOf("#") !== -1 || name.indexOf("♯") !== -1) {
                pitch = pitch + 1;
                tpc = tpc + 7;
            }
            if (name.indexOf("b") !== -1 || name.indexOf("♭") !== -1) {
                pitch = pitch - 1;
                tpc = tpc - 7;
            }
            
            console.log(i, ", ", name, ", ", pitch, ", ", tpc);
            
            tun.push({"string": i, "name": name, "pitch": pitch, "tpc": tpc});
        }
        return tun;
    }
    
    function guessString(pitch, tuning){
        //sort tuning by pitches, to work with crossed strings too
        var tun = tuning.slice().sort( function(a,b) { return (a.pitch < b.pitch) ? 1 : -1; } );
        for (var i = 0; i < tun.length; ++i){
            var stringPitch = tun[i].pitch;
            if (pitch >= stringPitch) {
                console.log("guessString:", tun[i].string);
                return tun[i].string;
            }
        }
        return false;
    }
    
    function translateNote(note, toScord) {
        var string = note.string > -1 ? note.string : guessString(note.pitch, tunings[toScord ? 1: 0]),
            pitchShift = (tunings[0][string].pitch - tunings[1][string].pitch) * (toScord ? 1: -1),
            tpcShift = (tunings[0][string].tpc - tunings[1][string].tpc) * (toScord ? 1: -1);
        
        note.pitch = note.pitch + pitchShift;
        note.tpc1 = note.tpc1 + tpcShift;
        note.tpc2 = note.tpc2 + tpcShift;
    }
    
    onRun: {
        tunings = [getTun("G3, D4, A4, E5"), getTun("A3, C#4, A4, C#5")];
        var els = curScore.selection.elements;
        if (els) {
            curScore.startCmd();
            for (var i = 0;  i < els.length; ++i) {
                var el = els[i];
                if (el.type == Element.NOTE) {
                    translateNote(el, el.track > 3);
                }
            }
            curScore.endCmd();
        }
    }
}
