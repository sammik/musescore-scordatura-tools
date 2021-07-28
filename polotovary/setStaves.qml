import QtQuick 2.6
import QtQuick.Controls 2.1
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"
    
    pluginType: "dock"
    dockArea:   "right"

    //width:  200
    
    property var score: null
    property var cursor: null
    //property var selection: null
    
    property var scordStaffLines: null
    property var standStaffLines: null
    
    onRun: {
        score = curScore;
        cursor = curScore.newCursor();
    }
    
    Column {
        id: stafDefs
        padding: 6
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Staves"
            font.pixelSize: 14
        }
        
        Repeater {
            model: ["Scordatura", "Standard"]
            
            Column {
                
                Label {
                    text: modelData
                    //font.pixelSize: 14
                }
                
                Row {
                    spacing: 5
                    Text {
                        id: scordStaffName
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Select staff and click 'Set'."
                    }
                    Button {
                        id: setScordStaff
                        height: 25
                        width: 60
                        property var staff: index ? standStaffLines : scordStaffLines
                        text: staff ? "Change" : "Set"
                        onClicked: {
                            if (staff) {
                                staff = null;
                                scordStaffName.text = "Select staff and click 'Set'."
                            }
                            else {
                                var sel = score.selection.elements[0];
                                if ( sel && sel.track > -1 ) {
                                    staff = score.firstSegment().elementAt(parseInt(sel.track/4)*4);
                                    scordStaffName.text = staff.staff.part.longName;
                                }
                                else scordStaffName.text = "Select some staff element";
                            }
                        }
                    }
                }
            }
        }
    }
}
