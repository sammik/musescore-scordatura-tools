import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"
    
    pluginType: "dock"
    dockArea:   "left"

    width:  150
    height: 75

    property var score: null
    property var cursor: null
    property var ticks: [0, 42240, 149760]
    property var pos: 0

    function goTo(tick){
        //navigate to tick, focus by cmd("next-chord")
        //pos = (pos + 1) % ticks.length;
        //var tick = ticks[pos];
        cursor.rewindToTick(tick);

        if (tick) {
            cursor.prev();
        } else {
            cursor.next();
        }

        var el = cursor.element.type == Element.CHORD ? cursor.element.notes[0] : cursor.element;
        score.selection.select(el);
        
        if (tick) {
            cursor.next();
            cmd("next-chord");
        } else {
            cursor.prev();
            cmd("prev-chord");
        }
    }
      
    onRun: {
        score = curScore;
        cursor = score.newCursor();
        cursor.track = 0;
        score.selection.selectRange(42240, 42241, 0, 1);
    }
    
    onScoreStateChanged: {
        if (state.selectionChanged) {
            var el = score.selection.elements[0];
            console.log(el)
            /*if (el && el.type == Element.NOTE){
                console.log(el.parent.parent.tick)
            }*/
        }
    }

    Rectangle {
    color: "grey"
    anchors.fill: parent

        Text {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "click to next"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: nextNote()
        }
    }
}
