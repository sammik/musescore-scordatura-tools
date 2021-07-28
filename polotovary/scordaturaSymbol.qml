/*
for (var seg = curScore.firstSegment(); seg; seg = seg.next) {
    var el = seg.elementAt(0)            
    console.log(i, ", ", el && el.type == Element.CLEF)
    ++i
}
*/


import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"
    requiresScore: false
    
    property var score: null
    property var cursor: null
    
    readonly property var diatonic: ["C", "D", "E", "F", "G", "A", "B"]
    readonly property var notePitch: ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    readonly property var noteTpc: ["F", "C", "G", "D", "A", "E", "B"]
    
    property var tuning: null
    
    // convert array strings string "G3, D4, A4, E5" to array of objects [{"string": 0, "name": "E5", "pitch": 76, "tpc": 18}, ...]
    function getTun(stringDef) {
        if (!stringDef) return;
        var strgs = stringDef.split(/\s*,\s*/).reverse();
        var tun = [];

        for (var i = 0; i < strgs.length; ++i) {
            var name = strgs[i][0].toUpperCase() + strgs[i].substring(1),
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
    
    function createScordaturaSign(){
        
        var posX,
            posY;
        
        cursor.rewind(0);
        cursor.track = 0; //scordatura staff first track
        
        curScore.startCmd();
        cursor.addNote(60);
        curScore.endCmd();
        cursor.prev();
        
        posY = cursor.element.notes[0].posY;
        cmd("undo");
        
        console.log(posY);
        
        
        curScore.startCmd()
        
        var style = curScore.style;
        var longName = style.value("longInstrumentOffset");
        console.log("Long name: ", longName.x);
        longName.x = -4.5;
        style.setValue("longInstrumentOffset", longName );
        //longName = style.value("longInstrumentOffset");
        console.log(longName);
        
        var sym = newElement(Element.STAFF_TEXT);
        sym.text = "<sym>staff5LinesWide</sym>";
        sym.autoplace = false;
        cursor.add(sym);
        sym.fontSize = 25;
        
        // posX = staffLines[0].lines.pagePos.x - sym.pagePos.x - 3
        posX = score.firstSegment().elementAt(0).pagePos.x - sym.pagePos.x - 2;
        
        sym.offsetX = posX;
        sym.offsetY = 4;
        
        sym = newElement(Element.STAFF_TEXT);
        sym.text = "<sym>staff5LinesWide</sym>";
        sym.autoplace = false;
        cursor.add(sym);
        sym.fontSize = 25;
        sym.offsetX = posX - 3;
        sym.offsetY = 4;
        console.log(sym.pagePos.x);
        
        for (var i = tuning.length; i-- > 0; ) { //tuning = scordaturaTuning
            var t = tuning[i],
                y = ( posY + 14 ) - ( diatonic.indexOf(t.name[0]) / 2 ) - ( 3.5 * Number(t.name[t.name.length-1]) );
            
            console.log("offset: ", y);
            console.log("i: ", i)
            console.log(t.name);
            sym = newElement(Element.STAFF_TEXT);
            sym.text = "<sym>noteheadBlack</sym>"
            sym.autplace = false;
            cursor.add(sym);
            sym.fontSize = 20;
            sym.offsetX = posX - 1;
            sym.offsetY = y;
            
            if (t.tpc < 13){
                sym = newElement(Element.STAFF_TEXT);
                sym.text = "<sym>accidentalFlat</sym>"
                sym.autplace = false;
                cursor.add(sym);
                sym.fontSize = 20;
                sym.offsetX = posX - 1.8;
                sym.offsetY = y + 1.6;
            }
            if (t.tpc > 19){
                sym = newElement(Element.STAFF_TEXT);
                sym.text = "<sym>accidentalSharp</sym>"
                sym.autplace = false;
                cursor.add(sym);
                sym.fontSize = 20;
                sym.offsetX = posX - 1.8;
                sym.offsetY = y + 1.6;
            }
            
            var createLedgerLine = function(offsetY){
                console.log("createLedgerLine", offsetY);
                sym = newElement(Element.STAFF_TEXT);
                sym.text = "<sym>legerLine</sym>"
                sym.autplace = false;
                cursor.add(sym);
                sym.fontSize = 25;
                sym.offsetX = posX - 1.4;
                sym.offsetY = offsetY;
            }
            
            if (i === tuning.length - 1){
            
                if (y > 4.6) {
                    createLedgerLine(7);
                }
                if (y > 5.6) {
                    createLedgerLine(8);
                }
                if (y > 6.6) {
                    createLedgerLine(9);
                }
            }
            if (i === 0){
            
                if (y < -0.6) {
                    createLedgerLine(1);
                }
                if (y < -1.6) {
                    createLedgerLine(0);
                }
                if (y < -2.6) {
                    createLedgerLine(-0.999);
                }
            }
        }
        curScore.endCmd();
    }
    
    onRun: {
        score = curScore;
        cursor = score.newCursor();
        console.log(score.firstSegment().elementAt(0).pagePos.x);
        tuning = getTun("F3, Db4, A4, C#5, E6");
        createScordaturaSign();
        Qt.quit();
    }
}
