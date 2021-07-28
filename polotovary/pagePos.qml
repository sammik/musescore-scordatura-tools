import QtQuick 2.0
import MuseScore 3.0

MuseScore {
      menuPath: "Plugins.pluginName"
      description: "Description goes here"
      version: "1.0"
      onRun: {
        var score = curScore;
        var cursor = score.newCursor();
        
        console.log(score.firstSegment().elementAt(0).pagePos.x);
        cursor.rewind(0);
        cursor.track = 0; //scordatura staff first track
        
        var sym = newElement(Element.STAFF_TEXT);
        sym.text = "<sym>staff5LinesWide</sym>";
        sym.autoplace = false;
        cursor.add(sym);
        sym.fontSize = 25;
        //sym.offsetY = 4;
        var oX = score.firstSegment().elementAt(0).pagePos.x - sym.pagePos.x;
        console.log(oX);
        sym.offsetX = oX - 3;
            
        Qt.quit()
    }
}
