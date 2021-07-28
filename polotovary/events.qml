import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.pluginName"
    description: "Description goes here"
    version: "1.0"
    onScoreStateChanged: {
        console.log("Score State Changed");
        console.log("selectionChanged: ", state.selectionChanged, 
        "\nexcerptsChanged: ", state.excerptsChanged, 
        "\ninstrumentsChanged: ", state.instrumentsChanged, 
        "\nstartLayoutTick: ", state.startLayoutTick, 
        "\nendLayoutTick: ", state.endLayoutTick, 
        "\nundoRedo: ", state.undoRedo);
    }
}
