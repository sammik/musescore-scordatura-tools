// Scordatura Plugin for MuseScore
// https://github.com/sammik/musescore-scordatura-tools
// sammik 2021

import QtQuick 2.6
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import MuseScore 3.0

MuseScore {
    id: scordaturaPlugin
    menuPath: "Plugins.Scordatura Plugin"
    description: "Plugin for scordatura score writing"
    version: "1.2.1"
    
    requiresScore: false
    
    pluginType: "dock"
    dockArea:   "right"
    
    width:  246
    height: 500
    
    property var score: null
    property var cursor: null
    property var corrections: []
    
    readonly property var diatonic: ["C", "D", "E", "F", "G", "A", "B"]
    readonly property var notePitch: ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    readonly property var noteTpc: ["F", "C", "G", "D", "A", "E", "B"]
    
    readonly property var instrumentsTunings: {
        "strings.violin": ["G3", "D4", "A4", "E5"],
        "strings.viola": ["C3", "G3", "D4", "A4"],
        "strings.cello": ["C2", "G2", "D3", "A3"],
        "strings.viol": ["G3", "D4", "A4", "D5", "G5"]
    }
    
    property var tunings: [] // [standardTuning, scordaturaTuning] // tuning = [{"string": 0, "name": "E5", "pitch": 76, "tpc": 18}, ...]
    
    property var staffLines: [null, null] // [scordaturaStaffLine, translatedStaffLine] // line = [{"name": instrumentLongName, "lines": staffLine}]
    
    property bool liveMode: false
    
    function findSegment(e) {
        while (e && e.type != Element.SEGMENT)
            e = e.parent;
        return e;
    }
    
    function noNotesOnStaff(element){ 
        var tr = element.track;
        console.log("FN noNotesOnStaff: ", tr);
        for (var seg = score.firstSegment(); seg; seg = seg.next) {
            for (var track = tr + 4; track-- > tr; ) {
                var el = seg.elementAt(track);
                if (el && (el.type == Element.CHORD)) {
                    console.log("there are notes");
                    return false
                }
            }
        }
        console.log("no notes");
        return true
    }
    
    // find tuning of given instrument and return string "C2,G2,..."
    function findTuning(instrument) {
        var instName = instrument.instrumentId;
        
        if (instrument.stringData.strings.length)
            return getStringData(instrument, true);
        else
            return (instrumentsTunings[instName] || []).toString();
    }
    
    // get string data of given instrument and return array of names, or pitches
    function getStringData(instrument, names /*boolean*/ ){ 
    
        var stringData = instrument.stringData,
            tuning = [];
        
        for (var i = 0; i < stringData.strings.length; ++i) {
            var pitch = stringData.strings[i].pitch;
            var name = notePitch[pitch %12] + (Math.floor(pitch/12)-1);
            tuning.push(names ? name : pitch);
        }
        
        return names ? tuning.toString() : tuning.reverse();
    }
    
    // convert strings string "G3, D4, A4, E5" to array of objects [{"string": 0, "name": "E5", "pitch": 76, "tpc": 18}, ...]
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
            
            console.log("FN getTun, ", i, ", ", name, ", ", pitch, ", ", tpc);
            
            tun.push({"string": i, "name": name, "pitch": pitch, "tpc": tpc});
        }
        return tun;
    }
    
    function validateTuns() {
        var valid = true,
            instruments = [];
        for (var i = 0; i < tunings.length; ++i) {
            var tuning = tunings[i],
                inst = staffLines[i].lines.staff.part.instruments[0],
                strData = getStringData(inst);
                console.log("FN validateTuns - string data: ", strData);
            if (strData.length) {
                if (strData.length !== tuning.length) {
                    console.log("validate tunings - length doesn't fit: ", strData.length, ", ", tuning.length);
                    valid = false;
                    instruments.push(inst.longName);
                }
                else {
                    for (var j = 0; j < tuning.length; ++j) {
                        if (strData[j] !== tuning[j].pitch) {
                            console.log("validate tunings - pitch doesn't fit: ", strData[j], ", ", tuning[j].pitch);
                            valid = false;
                            instruments.push(inst.longName);
                            break;
                        }
                    }
                }
            }
        }
        return {"valid": valid, "instruments": instruments}
    } 
    
    // get selected string
    function getSelectedString() {
        var els = score ? score.selection.elements : null;
        return (els && els.length === 1 && els[0].type == Element.NOTE) ? els[0].string : false;
    }
    
    function guessString(pitch, tuning){
        //sort tuning by pitches, to work with crossed strings too
        var tun = tuning.slice().sort( function(a,b) { return (a.pitch < b.pitch) ? 1 : -1; } );
        for (var i = 0; i < tun.length; ++i){
            var stringPitch = tun[i].pitch;
            if (pitch >= stringPitch) {
                console.log("guessString: ", tun[i].string);
                return tun[i].string;
            }
        }
        return -1;
    }
    
    function setFret(pitch, stringValue){
        var fret = pitch - stringValue;
        // Check, if can be on that string
        if (fret > -1) {
            console.log("setFret: ", fret);
            return fret;
        }
        else
            return -1;
    }
    
    //check index of note; if note is graceNote, set index of graceChord too
    function getNoteIndex(note){ 
        console.log("FN getNoteIndex");
        var index = [-1, -1];
        
        if (note.type !== Element.NOTE) return index;
        
        var chord = note.parent;
            
        for ( var i = 0; i < chord.notes.length; ++i ) {
            if (chord.notes[i].is(note)) index[1] = i;
        }
        console.log(note.noteType);
        console.log(note.noteType != NoteType.NORMAL);
        if (note.noteType != NoteType.NORMAL) {
            var mainChord = chord.parent;
            for ( var j = 0; j < mainChord.graceNotes.length; ++j ) {
                if (mainChord.graceNotes[j].is(chord)) index[0] = j;
            }
        }
        console.log(index);
        return index;
    }
    
    function translateNote(note, toScord) {
        var string = note.string > -1 ? note.string : guessString(note.pitch, tunings[toScord ? 1: 0]),
            pitchShift = (tunings[0][string].pitch - tunings[1][string].pitch) * (toScord ? 1: -1),
            tpcShift = (tunings[0][string].tpc - tunings[1][string].tpc) * (toScord ? 1: -1);
        
        note.pitch = note.pitch + pitchShift;
        note.tpc1 = note.tpc1 + tpcShift;
        note.tpc2 = note.tpc2 + tpcShift;
    }
    
    function translateChord(chord, toScord) {
        for (var i = 0; i < chord.notes.length; ++i){
            translateNote(chord.notes[i], toScord);
        }
        for (var j = 0; j < chord.graceNotes.length; ++j) {
            translateChord(chord.graceNotes[j], toScord);
        }            
    }
    
    function setSelectedString(str) { 
        //var els = score.selection.elements;
        var sel = score.selection.elements,
            els = [];
            
        for (var i = 0; i < sel.length; ++i){
            var el = sel[i];
            if (el && el.type == Element.NOTE){
                if ( el.firstTiedNote.is(el.lastTiedNote) ){ //no ties
                    els.push(el);
                } 
                else { //add all tied notes to selection
                    var n = el.firstTiedNote;
                    els.push(n);
                    while (n.tieForward){
                        n = n.tieForward.endNote;
                        els.push(n);
                    }
                }
            }
        }
        
        score.startCmd();
        for ( var i = 0; i < els.length; ++i) {
            var el = els[i],
                tr = el.track,
                tun = false,
                scord = false;
                
            if (tr > staffLines[0].lines.track - 1 && tr < staffLines[0].lines.track + 4){
                tun = tunings[0];
                scord = true;
            }
            else if  (tr > staffLines[1].lines.track - 1 && tr < staffLines[1].lines.track + 4) 
                tun = tunings[1];
            
            console.log("FN setSelectedStrings - el.track: ", el.track, ", el.pitch: ", el.pitch);
            
            if (el && el.type == Element.NOTE && tun && !(tun[str].pitch > el.pitch)) { //if element is note, is on working staff, and note can be on string
                el.string = str;
                el.fret = setFret(el.pitch, tun[str].pitch);
                
                // check, if note exists in paralel staff and translate it and set string to it too
                // TODO crossed strings
                var index = getNoteIndex(el);
                var gi = index[0];
                var ni = index[1];
                var seg = findSegment(el);
                var tr = el.track - (staffLines[0].lines.track - staffLines[1].lines.track) * (scord ? 1 : -1);
                var chordNew = seg.elementAt(tr);
                if (chordNew && chordNew.type == Element.CHORD && chordNew.graceNotes.length > gi) {
                    
                    var chordNotes = gi < 0 ? chordNew.notes : chordNew.graceNotes[gi].notes;
                    
                    if (chordNotes.length > ni) {
                        var oldNote = chordNotes[ni];
                        var newNote = el.clone();
                        translateNote(newNote, !scord);
                        oldNote.pitch = newNote.pitch;
                        oldNote.tpc1 = newNote.tpc1;
                        oldNote.tpc2 = newNote.tpc2;
                        oldNote.string = newNote.string;
                        oldNote.fret = newNote.fret;
                    }
                }
            }
        }
        score.endCmd();
    }
    
    function transcribe(){
        var source = transSelect.currentIndex,
            target = transSelect.currentIndex ^ 1,
            si = parseInt(staffLines[source].lines.track / 4),
            ti = parseInt(staffLines[target].lines.track / 4);

        console.log("FN transcribe: ", source, target, si, ti, staffLines[source].lines.track);


        if ( !noNotesOnStaff(staffLines[source].lines) ) { // if there are notes to translate, do it
            
            score.selection.selectRange(0, score.lastSegment.tick+1, si, si+1);
            cmd("copy");
            score.selection.selectRange(0, score.lastSegment.tick+1, ti, ti+1);
            score.startCmd();
            cmd("delete");
            cmd("paste");
            
            //TODO remove scordatura symbol from transcription staff, if already was in scordatura staff 
            
            var els = score.selection.elements;
            if (els) {
                for (var i = 0;  i < els.length; ++i) {
                    var el = els[i];
                    if (el.type == Element.NOTE) {
                        translateNote(el, target === 0);
                    }
                }
            }
            score.endCmd();
        }
        
        // if mode switched to live, after transcription set liveMode
        if (modeSwitch.checked)
            liveMode = true;
    }
    
    function removeTies(chord){
        
        function removeTie(note){
            if (note.tieBack)
                removeElement(note.tieBack);
                //note.remove(note.tieBack);
            if (note.tieForward)
                removeElement(note.tieForward);
        }
        
        for (var i = 0; i < chord.notes.length; ++i){
            var note = chord.notes[i];
            removeTie(note);
        }
        for (var i = 0; i < chord.graceNotes.length; ++i){
            var graceChord = chord.graceNotes[i];
            removeTies(graceChord);
        }
        return chord;
    }
    
    function duplicate(el){ //for live mode - duplicate element: note (chord), or rest
        
        var seg = findSegment(el);
        var tick = seg.tick;
        var chord = el.type == Element.NOTE ? (el.noteType == NoteType.NORMAL ? el.parent : el.parent.parent) : null;
        var duration = el.duration || chord.duration;
        var tr = el.track;
        var scord = (tr > staffLines[0].lines.track - 1 && tr < staffLines[0].lines.track + 4);
        
        if ( !(scord || (tr > staffLines[1].lines.track - 1 && tr < staffLines[1].lines.track + 4) ) ) {
            console.log("FN duplicate - no working track");
            return;
        }
        
        cursor.rewindToTick(tick);
        cursor.track = tr - (staffLines[0].lines.track - staffLines[1].lines.track) * (scord ? 1 : -1);
        cursor.setDuration(duration.numerator, duration.denominator);
        
        
        score.startCmd();
        cursor.addRest();
        if (chord) {
            var newChord = removeTies(chord.clone());
            
            translateChord(newChord, !scord);
            
            cursor.prev();
            cursor.add(newChord);
        }
        score.endCmd();
    }
    
    // if changed tied note, apply change to whole tied group
    function ties(tie, back /*true*/){
        console.log("FN ties");
        
        var note = back ? tie.startNote : tie.endNote;
        
        duplicate(note);

        var tie = back ? note.tieBack : note.tieForward;
        if (tie){
            ties(tie, back);
        }
    }
    
    function hideAccidentals(){    
        var sel = score ? score.selection : null;
        if (sel) {
            score.startCmd();
            for (var i = 0; i < sel.elements.length; ++i) {
                var element = sel.elements[i];
                if (element.type == Element.NOTE) {
                    var accidental = element.accidental;
                    if (accidental) {
                        accidental.visible = false;
                    }
                }
            }
            score.endCmd();
        }
    }
    
    function muteSwitch(part, on){
        var instrs = part.instruments || [];
        for (var i = 0; i < instrs.length; ++i) {
            var instr = instrs[i];
            var channels = instr.channels;
            for (var j = 0; j < channels.length; ++j) {
                var channel = channels[j];
                channel.mute = on ? false : true;
            }
        }
    }

    function createScordaturaSymbol() {
        console.log("FN createScordaturaSymbol");
        var posX,
            posY,
            sym,
            //font = (Qt.fontFamilies().indexOf("Leland") !== -1 ? "Leland" : "Bravura"),
            alternative = (symAlternative.checkState == Qt.Checked),
            track = staffLines[0].lines.track; //scordatura staff first track
        
        cursor.rewind(Cursor.SCORE_START);
        cursor.track = track;
        
        // to find out, which clef is at the begining, create temporary middle C note
        score.startCmd();
        cursor.addNote(60);
        score.endCmd();
        cursor.prev();
        posY = cursor.element.notes[0].posY;
        
        // calculate x offset from begining of staves 
        // TODO - check for brackets        
        posX = staffLines[0].lines.pagePos.x - cursor.element.notes[0].pagePos.x + (alternative ? 1 : 0);
        
        cmd("undo");
        
        // create lines, notes, accidentals, ledger lines
        score.startCmd()
        
        if (alternative) {
            // move clefs right
            var seg = score.firstSegment();
            while (seg && seg.elementAt(track).type != Element.CLEF)
                seg = seg.next;
            seg.leadingSpace = 4.5;
        } else {
            //move longName left
            var style = score.style,
                longName = style.value("longInstrumentOffset");
            longName.x = -4.5;
            style.setValue("longInstrumentOffset", longName );
            
            sym = newElement(Element.STAFF_TEXT);
            sym.text = "<sym>staff5LinesWide</sym>";
            sym.autoplace = false;
            //sym.fontFace = font;
            cursor.add(sym);
            sym.fontSize = 25;
            sym.offsetX = posX - 2;
            sym.offsetY = 4;
            
            sym = newElement(Element.STAFF_TEXT);
            sym.text = "<sym>staff5LinesWide</sym>";
            sym.autoplace = false;
            //sym.fontFace = font;
            cursor.add(sym);
            sym.fontSize = 25;
            sym.offsetX = posX - 5;
            sym.offsetY = 4;
            console.log("symbol position x: ", sym.pagePos.x);
        }
        
        //tuning is scordatura tuning
        var tuning = tunings[1];
        for (var i = tuning.length; i-- > 0; ) {
            var t = tuning[i],
                y = ( posY + 14 ) - ( diatonic.indexOf(t.name[0]) / 2 ) - ( 3.5 * Number(t.name[t.name.length-1]) ),
                
                createLedgerLine = function(offsetY){
                    console.log("createLedgerLine", offsetY);
                    sym = newElement(Element.STAFF_TEXT);
                    sym.text = "<sym>legerLine</sym>"
                    sym.autplace = false;
                    //sym.fontFace = font;
                    cursor.add(sym);
                    sym.fontSize = 25;
                    sym.offsetX = posX - 3.4;
                    sym.offsetY = offsetY;
                }
            
            console.log("offset: ", y);
            console.log("i: ", i)
            console.log(t.name);
            
            //create ledger linef, if neccesary
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
            
            //create noteheads
            sym = newElement(Element.STAFF_TEXT);
            sym.text = "<sym>noteheadBlack</sym>"
            sym.autplace = false;
            //sym.fontFace = font;
            cursor.add(sym);
            sym.fontSize = 20;
            sym.offsetX = posX - 3;
            sym.offsetY = y;
            
            //add accidentals
            if (t.tpc < 13){
                sym = newElement(Element.STAFF_TEXT);
                sym.text = "<sym>accidentalFlat</sym>"
                sym.autplace = false;
                //sym.fontFace = font;
                cursor.add(sym);
                sym.fontSize = 20;
                sym.offsetX = posX - 3.8;
                sym.offsetY = y + 1.6;
            }
            if (t.tpc > 19){
                sym = newElement(Element.STAFF_TEXT);
                sym.text = "<sym>accidentalSharp</sym>"
                sym.autplace = false;
                //sym.fontFace = font;
                cursor.add(sym);
                sym.fontSize = 20;
                sym.offsetX = posX - 3.8;
                sym.offsetY = y + 1.6;
            }
        }
        curScore.endCmd();
    }
    
    /*
    // TODO - rethink, not just notes on segment, but whole paralel polyphony
    
    function notesOnSegment(segment, topTrack, bottomTrack){
        var notes=[];
        for (var track = topTrack; track < bottomTrack + 1; ++track ) {
              var el = segment.elementAt(track);
              if (el && (el.type == Element.CHORD) ) {
                    for (var j = 0; j < el.notes.length; ++j ){
                        notes.push(el.notes[j])
                    }
              }
        }
        return notes
    }
    */
    
    function updateCurrentScore() {
        console.log("FN update score");
        console.log("is curent: ", score && curScore.is(score), ", curScore: ", curScore, ", score: ", score);
        if (!curScore || !curScore.is(score)){
            console.log("reset");
            tunings = [];
            staffLines = [null, null];
            menuBar.currentIndex = 1;
            standDef.text = "";
            scordDef.text = "";
            staffDefs.state = "DEFAULT";
            stringDefs.state = "";
            aplyDef.state = "";
            modeSwitch.checked = false;
        }
        if (curScore && !curScore.is(score)) {
            console.log("update");
            score = curScore;
            cmd("escape");
            cursor = score.newCursor();
            
            // load saved settings
            var metaTracks = score.metaTag("SCORDATURA_PLUGIN_TRACKS");
            var metaScord = score.metaTag("SCORDATURA_PLUGIN_SCORDATURA_TUNING");
            var metaStand = score.metaTag("SCORDATURA_PLUGIN_STANDARD_TUNING");
            if (metaTracks) {
                var tracks = metaTracks.split(",");
                console.log("metaTracks: ", tracks);
                var scordLines = score.firstSegment().elementAt(tracks[0]);
                var standLines = score.firstSegment().elementAt(tracks[1]);
                staffLines = [{"name": scordLines.staff.part.longName, "lines": scordLines}, {"name": standLines.staff.part.longName, "lines": standLines}];
                if ( !scordDef.text.length ) 
                    scordDef.text = metaScord || findTuning(staffLines[0].lines.staff.part.instruments[0]);
                if ( !standDef.text.length )
                    standDef.text = metaStand || findTuning(staffLines[1].lines.staff.part.instruments[0]);
            }
            
        } else if (score && !curScore) {
            console.log("no score");
            score = null;
            cursor = null;
        }
    }
    
    onRun: {
        updateCurrentScore();
    }
    
    
    onScoreStateChanged: {
        updateCurrentScore();
        
        //highlight coresponding string button
        stringButtons.noteIndex = getSelectedString();
        
        //live mode
        if (liveMode && !state.undoRedo && state.startLayoutTick > -1){
            console.log("liveMode note input");
            
            //temporarily disable liveMode to prevent infinite cerusion
            liveMode = false;
            
            var els = score ? score.selection.elements : [];
            for (var i = 0; i < els.length; ++i) {
                var el = els[i];
                if ( el.type == Element.REST || el.type == Element.NOTE ) {
                    
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
            // enable liveMode back again
            liveMode = true;
        }
        
        // save settings
        if (staffLines[0] && staffLines[1]){
            var tracks = [staffLines[0].lines.track, staffLines[1].lines.track].toString();
            var saved = score.metaTag("SCORDATURA_PLUGIN_TRACKS");
            if (saved !== tracks) {
                console.log("Old setting: \n", tracks, "\n", saved);
                score.startCmd();
                score.setMetaTag("SCORDATURA_PLUGIN_TRACKS", tracks);
                score.endCmd();
                console.log("new: ", score.metaTag("SCORDATURA_PLUGIN_TRACKS"));
            }
        }
        if (tunings.length){
            var scordTun = [];
            var standTun = [];
            for (var i = tunings[1].length; i-- > 0; ) {
                scordTun.push(tunings[1][i].name);
                standTun.push(tunings[0][i].name);
            }
            var savedScord = score.metaTag("SCORDATURA_PLUGIN_SCORDATURA_TUNING");
            var savedStand = score.metaTag("SCORDATURA_PLUGIN_STANDARD_TUNING");
            scordTun = scordTun.toString();
            standTun = standTun.toString();
            if (savedScord !== scordTun) {
                console.log("Old setting - tunings: \n", scordTun, ", ", standTun);
                score.startCmd();
                score.setMetaTag("SCORDATURA_PLUGIN_SCORDATURA_TUNING", scordTun);
                score.endCmd();
                console.log("newScordTun: ", score.metaTag("SCORDATURA_PLUGIN_SCORDATURA_TUNING"));
            }
            if (savedStand !== standTun) {
                score.startCmd();
                score.setMetaTag("SCORDATURA_PLUGIN_STANDARD_TUNING", standTun);
                score.endCmd();
                console.log("newStandTun: ", score.metaTag("SCORDATURA_PLUGIN_STANDARD_TUNING"));
            }
        }
            
        //highlight coresponding string button
        stringButtons.noteIndex = getSelectedString();
    }
    
    // plugin white background
    Rectangle {
        color: "#fff"
        anchors.fill: parent
    }
    
    TabBar {
        id:menuBar
        width: parent.width
        currentIndex: 1
        enabled: !!score
        //position: TabBar.Header
        TabButton {
            text: "Main"
            enabled: stringDefs.state == "DONE"
        }
        TabButton {
            text: "Settings"
        }
        TabButton {
            text: "Tools"
        }
    }

    StackLayout {
        width: parent.width
        currentIndex: menuBar.currentIndex
        anchors.top: menuBar.bottom
        anchors.topMargin: 10
        enabled: !!score
        
        Item {
            id: main
            Column {
                id: modeSwitchPanel
                spacing: 3
                leftPadding: 6
                rightPadding: 6
                
                Label {
                    text: "Mode"
                    font.pixelSize: 16
                }
                Switch {
                    id: modeSwitch
                    text: "Live (experimental)"
                    onPositionChanged: {
                        console.log("switch changed", position);
                        if (checked){
                            if ( !noNotesOnStaff(staffLines[transSelect.currentIndex ^ 1].lines) )
                                nonEmptyWarning.open();
                            else 
                                transcribe();
                        }
                        else
                            liveMode = false;
                    }
                }
            }
            
            ToolSeparator {
                anchors.top: modeSwitchPanel.bottom
                width: parent.width
                orientation: Qt.Horizontal
            }
            
            Column {
                id: stringPanel
                anchors.top: modeSwitchPanel.bottom
                anchors.topMargin: 13
                spacing: 3
                leftPadding: 6
                rightPadding: 6
                
                Label {
                    text: "Strings"
                    font.pixelSize: 16
                }
                
                Repeater {
                    id: stringButtons
                    property var noteIndex: false
                    model: tunings[0] //standTun
                    Button {
                        height: 30
                        text: modelData.name
                        onClicked: setSelectedString(index)
                        highlighted: index === stringButtons.noteIndex
                    }
                }

            }
            
            ToolSeparator {
                anchors.top: stringPanel.bottom
                width: parent.width
                orientation: Qt.Horizontal
            }
            
            Column {
                id: translatorPanel
                width: parent.width
                anchors.top: stringPanel.bottom
                anchors.topMargin: 13
                spacing: 6
                leftPadding: 6
                rightPadding: 6
                enabled: !modeSwitch.checked
                property color textColor: enabled ? "black" : "darkgray"
                
                Label {
                    text: "Translate"
                    font.pixelSize: 16
                    color: translatorPanel.textColor
                }
                Row {
                    Label {
                        anchors.verticalCenter: transSelect.verticalCenter
                        text: "Source staff:"
                        color: translatorPanel.textColor
                    }
                    ComboBox {
                        id: transSelect
                        height: 30
                        model: ["Scordatura", "Sounding"]
                    }
                }
                Row {
                    spacing: 16
                    Label {
                        text: "Target staff:"
                        color: translatorPanel.textColor
                    }
                    Label {
                        text: transSelect.currentIndex ? "Scordatura" : "Sounding"
                        color: translatorPanel.textColor
                    }
                }
                Button {
                    width: parent.width - 12
                    text: "Translate"
                    onClicked: {
                        if ( !noNotesOnStaff(staffLines[transSelect.currentIndex ^ 1].lines) ) {
                            nonEmptyWarning.open();
                        }
                        else {
                            transcribe();
                        }
                    }
                }
            }
            
            ToolSeparator {
                anchors.top: translatorPanel.bottom
                width: parent.width
                orientation: Qt.Horizontal
            }
            
            /*
            Column {
                id: correctionPanel
                anchors.top: translatorPanel.bottom
                anchors.topMargin: 20
                spacing: 3
                property bool activeButton: (corrections.length > 0)
                
                Label {
                    text: "Collisions"
                    font.pixelSize: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                    
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Find"
                    //onClicked: 
                    ToolTip.visible: hovered
                    ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
                    ToolTip.text: "Find string collisions"
                }
                
                ToolSeparator {
                    width: 100
                    topPadding: 0
                    bottomPadding: 0
                    orientation: Qt.Horizontal
                }
                
                Row {
                    spacing: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                
                    Button {
                        width: 47
                        text: "<"
                        enabled: correctionPanel.activeButton
                        //onClicked: // prev problem

                        ToolTip.visible: hovered
                        ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
                        ToolTip.text: "Previous Collision"
                    }
                    
                    Button {
                        width: 47
                        text: ">"
                        //onClicked: // next problem
                        enabled: correctionPanel.activeButton

                        ToolTip.visible: hovered
                        ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
                        ToolTip.text: "Next Collision"
                    }
                }
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    text: "Fixed"
                    //onClicked: // mark as fixed = remove problem
                    enabled: correctionPanel.activeButton

                    ToolTip.visible: hovered
                    ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
                    ToolTip.text: "Mark collision as fixed"
                }
            
            }
            
            ToolSeparator {
                anchors.top: correctionPanel.bottom
                anchors.topMargin: 8
                width: parent.width
                orientation: Qt.Horizontal
            }
            */
        }
        
        Item {
            id: settings
            width: parent.width
            Column {
                id: staffDefs
                leftPadding: 6
                rightPadding: 6
                spacing: 6
                
                Label {
                    text: "Working Staves"
                    font.pixelSize: 16
                }
                
                states: [
                    State {
                        name: "DONE"
                    },
                    State {
                        name: "DEFAULT"
                    }
                ]
                
                Repeater {
                    model: ["Scordatura", "Sounding"]
                    Row {
                        spacing: 3
                        
                        Column {
                            spacing: 3
                            Label {
                                text: modelData + " staff: "
                            }
                        
                            Text {
                                id: staffName
                                width: 160
                                //property var name: ""
                                text: staffLines[index] ? staffLines[index].name : "Select staff and click 'Set'."
                            }
                        }
                        
                        Button {
                            id: setStaff
                            height: parent.height
                            width: 70
                            text: staffLines[index] ? "Change" : "Set"
                            states: [
                                State {
                                    name: "DEFAULT"
                                    when: staffDefs.state == "DEFAULT"
                                },
                                State {
                                    name: "UNSELECTED"
                                    PropertyChanges { target: staffName; text: "Select some (staff) element"}
                                },
                                State {
                                    name: "SET"
                                    //PropertyChanges { target: setStaff; text: "Change"}
                                    //PropertyChanges { target: staffName; text: staffLines[index] ? staffLines[index].name : ""}
                                }
                            ]
                            onClicked: {
                                var tunDef = index ? scordDef : standDef;
                                
                                if (staffLines[index]) {
                                    staffLines[index] = null;
                                    staffLinesChanged();
                                    modeSwitch.checked = false;
                                    //setStaff.state = ""
                                    //tunings = [];
                                }
                                else {
                                    var sel = score ? score.selection.elements[0] : null;
                                        
                                        if ( sel && sel.track > -1 ) {
                                            var lines = score.firstSegment().elementAt(parseInt(sel.track/4)*4);
                                            staffLines[index] = {"name": lines.staff.part.longName, "lines": lines};
                                            staffLinesChanged();
                                            tunDef.text = (index ? score.metaTag("SCORDATURA_PLUGIN_SCORDATURA_TUNING") : score.metaTag("SCORDATURA_PLUGIN_STANDARD_TUNING")) || findTuning(staffLines[index].lines.staff.part.instruments[0]);
                                            setStaff.state = "SET";
                                        }
                                        else setStaff.state = "UNSELECTED"
                                }
                                staffDefs.state = staffLines.indexOf(null) == -1 ? "DONE" : "";
                                aplyDef.state = "";
                            }
                        }
                    }
                }
            }
            
            ToolSeparator {
                width: parent.width
                anchors.top: staffDefs.bottom
                orientation: Qt.Horizontal
            }
            
            Column {
                id: stringDefs
                anchors.top: staffDefs.bottom
                leftPadding: 6
                rightPadding: 6
                anchors.topMargin: 12
                spacing: 6
                enabled: staffLines[0] && staffLines[1]

                states: [
                    State {
                        name: "DONE"
                        when: aplyDef.state == "SET"
                    }
                ]
                
                Label {
                    text: "Tunings"
                    font.pixelSize: 16
                }

                Row {
                    spacing: 6
                    Column {
                        spacing: 3
                        Label {
                            text: "Scordatura tuning:"
                            font.weight: Font.Bold
                        }
                        TextField {
                            id: scordDef
                            height: 25
                            width: 158
                            font.weight: Font.Bold
                            text: ""
                            readOnly: false
                            activeFocusOnPress: true
                            ToolTip.visible: hovered
                            ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
                            ToolTip.text: "Tuning in format: G3, D#4, Ab4, E5"
                        }
                        Label {
                            text: "Standard tuning:"
                        }
                        TextField {
                            id: standDef
                            height: 25
                            width: 158
                            text: ""
                            readOnly: false
                            activeFocusOnPress: true
                            ToolTip.visible: hovered
                            ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
                            ToolTip.text: "Tuning in format: G3, D#4, Ab4, E5"
                        }
                    }
                    Button {
                        id: aplyDef
                        anchors.bottom: parent.bottom
                        height: 53
                        width: 70
                        enabled: aplyDef.state == "SET" || standDef.text && scordDef.text && standDef.text.split(/\s*,\s*/).length === scordDef.text.split(/\s*,\s*/).length
                        text: "Set" 
                        
                        states: [
                            State {
                                name: "SET"
                                PropertyChanges { target: aplyDef; text: "Edit"} 
                                PropertyChanges { target: standDef; readOnly: true}
                                PropertyChanges { target: standDef; activeFocusOnPress: false}
                                PropertyChanges { target: scordDef; readOnly: true}
                                PropertyChanges { target: scordDef; activeFocusOnPress: false}
                            }
                        ]
                        
                        ToolTip.visible: hovered
                        ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
                        ToolTip.text: aplyDef.state == "SET" ? "Edit tunings" : aplyDef.enabled ? "Set tunings" : "Both tunings need to have same count of strings" // qt bug - tooltip doesnt show on disabled button - hack below
                        
                        onClicked: {
                            if (aplyDef.state == "SET") {
                                tunings = [];
                                aplyDef.state = ""
                                modeSwitch.checked = false;
                                muteSwitch(staffLines[0].lines.staff.part, true); //unmute ex-scordatura staff
                                console.log("String defs - set");
                            }
                            else {
                                tunings = [getTun(standDef.text), getTun(scordDef.text)];
                                var validator = validateTuns(tunings);
                                console.log("Set string defs - validator: ", validator.valid, ", ", validator.instruments);
                                aplyDef.state = "SET";
                                muteSwitch(staffLines[0].lines.staff.part); //mute scordatura staff
                                if (validator.valid) {
                                    menuBar.currentIndex = 0;
                                    validate.visible = false
                                }
                                else {
                                    validate.visible = true;
                                    validatorMessage.text = "Given string values are different to instrument(s) string data values. \n" +
                                                            "You should correct it. \n\nCheck instrument(s): " + validator.instruments.toString()
                                                            + "\n\nScordatura staff needs standard tuning and Sounding staff needs scordatura tuning."
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    id: validate
                    visible: false
                    width: settings.width
                    height: validatorMessage.implicitHeight + validatorButtons.implicitHeight
                    color: "transparent"
                    border.color: "#FF0000"
                    border.width: 1
                    
                    Text {
                        id: validatorMessage
                        width: parent.width
                        padding: 3
                        leftPadding: 6
                        rightPadding: 6
                        wrapMode: Text.Wrap
                    }
                    Row {
                        id: validatorButtons
                        anchors.bottom: parent.bottom
                        width: parent.width
                        padding: 1
                        spacing: 6
                        
                        Button {
                            width: parent.width / 2 - 4
                            text: "Change"
                            onClicked: {
                                aplyDef.state = "";
                            }
                        }
                        Button {
                            width: parent.width / 2 - 4
                            text: "Ignore"
                            onClicked: {
                                aplyDef.state = "SET";
                                menuBar.currentIndex = 0;
                            }
                        }
                    }
                }
            }
            Item { //HACK - tooltip for disabled button (QT 5 bug)                
                anchors.bottom: stringDefs.bottom
                anchors.right: stringDefs.right
                width: aplyDef.width
                height: aplyDef.height
                visible: !aplyDef.enabled
                ToolTip.visible: ma.containsMouse
                ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
                ToolTip.text: "Both tunings need to have same count of strings"
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
        
        Item {
            id: tools
            width: parent.width
            Column {
                //id: hideAccs
                width: parent.width
                leftPadding: 6
                rightPadding: 6
                spacing: 6
                Label {
                    text: "Hide Accidentals"
                    font.pixelSize: 16
                }
                Text {
                    width: parent.width - 12
                    text: "Select notes, on which You want to hide accidentals."
                    wrapMode: Text.Wrap
                }
                Button {
                    text: "Hide"
                    onClicked: hideAccidentals()
                }

                ToolSeparator {
                    width: parent.width - 12
                    orientation: Qt.Horizontal
                }

                Label {
                    text: "Create Scordatura Symbol\n(experimental)"
                    font.pixelSize: 16
                }
                Button {
                    text: "Create"
                    enabled: !!tunings[1]
                    onClicked: createScordaturaSymbol();
                }
                CheckBox {
                    id: symAlternative
                    text: "Alternative"
                }
            }
        }
    }
    
    Dialog {
        id: nonEmptyWarning

        width: scordaturaPlugin.width
        //parent: Overlay.overlay

        modal: true
        title: "Warning"
        standardButtons: Dialog.Ok | Dialog.Cancel
        
        onAccepted: { transcribe(); }
        
        onRejected: { modeSwitch.checked = false; }
        
        background: Rectangle {
            border.color: "#f00"
        }
        
        Column {
            spacing: 20
            anchors.fill: parent
            Label {
                text: staffLines[transSelect.currentIndex ^ 1] ? "<b>" + staffLines[transSelect.currentIndex ^ 1].name + "</b> staff is not empty. Content will be overwritten." : ""
                width: parent.width
                wrapMode: Text.Wrap
            }
            /*CheckBox {
                text: "Do not ask again"
                anchors.right: parent.right
            }*/
        }
    }
}
