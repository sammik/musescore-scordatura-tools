import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"
    onRun: {
        //var seg = curScore.firstSegment();
        var cursor = curScore.newCursor();
        cursor.rewind(Cursor.SCORE_START);
        var annotations = cursor.segment.annotations;
        for (var i = 0; i < annotations.length; ++i){
            var an = annotations[i];
            if ( an.track == 4 && ( an.text == "<sym>staff5LinesWide</sym>" || an.text == "<sym>legerLine</sym>" || an.text == "<sym>noteheadBlack</sym>" || an.text == "<sym>accidentalSharp</sym>" || an.text == "<sym>accidentalFlat</sym>" ) ){
                console.log(an.text);
                removeElement(an);
                console.log(annotations.length)
                --i;
            }
        }
        Qt.quit()
    }
}
