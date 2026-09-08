import QtQuick
import "../.."
import ".."
import "../../services"

// One square button of the control centre's footer, chosen by id.
//
// A SquareButton directly rather than a Loader over components, unlike
// the tiles: every entry here is the same glyph-only square, and only the
// glyph and the action differ. A Loader would buy nothing and cost a
// wrapper whose size the footer's RowLayout would then have to be told.
SquareButton {
    id: btn
    required property string itemId
    required property var cc

    visible: btn.applies
    readonly property bool applies:
        btn.itemId !== "night" || NightLight.available

    icon: CcRegistry.icon("footer", btn.itemId)
    lit: btn.itemId === "night" && NightLight.active
    danger: btn.itemId === "power"

    onActivated: {
        // Night light is the only one that acts in place. Everything else
        // opens something the size of the screen, so the panel gets out
        // of the way first.
        if (btn.itemId === "night") {
            NightLight.toggle();
            return;
        }
        btn.cc.requestClose();
        switch (btn.itemId) {
        case "screenshot": GlobalState.screenshotOpen = true; break;
        case "displays":   GlobalState.displaysOpen = true; break;
        case "cheatsheet": GlobalState.cheatsheetOpen = true; break;
        case "settings":   GlobalState.settingsOpen = true; break;
        case "reload":     Power.reloadAll(); break;
        case "lock":       Power.lock(); break;
        case "power":      GlobalState.sessionOpen = true; break;
        default: break;
        }
    }
}
