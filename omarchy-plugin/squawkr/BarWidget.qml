import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Squawkr bar module — the Squawkr mark in the Omarchy status bar. Click toggles the native
// panel (Panel.qml, loaded below); the shell routes summon/hide/toggle here, and the bar's
// popout coordinator closes other panels through closeForPopoutSwitch.
//
// The mark is a monochrome SVG. Bar glyphs take the button foreground so they follow the bar
// (dark on a light/transparent bar, light on a dark one); a plain Image would not, so it is
// recoloured to button.foreground with a MultiEffect.
BarWidget {
  id: root
  moduleName: "squawkr.panel"

  function injectPanel() {
    var target = panelLoader.item;
    if (!target) return;
    if ("bar" in target) target.bar = root.bar;
    if ("anchorItem" in target) target.anchorItem = button;
    if ("hostWidget" in target) target.hostWidget = root;
  }
  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle();
  }
  function openPanel() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey();
  }
  function closePanel() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close();
  }

  IpcHandler {
    target: "squawkr.panel"
    function open(): string { root.openPanel(); return "open"; }
    function close(): string { root.closePanel(); return "closed"; }
    function show(): string { root.openPanel(); return "open"; }
    function hide(): string { root.closePanel(); return "closed"; }
    function toggle(): string { root.togglePanel(); return "toggled"; }
  }

  // Shape contract for shell summon/hide/toggle routing (Bar.findPanelWidget
  // requires open/close/opened on the bar-widget root).
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey();
  }
  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close();
  }
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch();
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel();
      Qt.callLater(root.injectPanel);
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "Squawkr — airspace & weather"
    iconComponent: markIcon
    onPressed: function (b) {
      if (!root.bar) return;
      root.togglePanel();
    }
  }

  Component {
    id: markIcon
    Item {
      // The raw SVG, hidden — used only as the shape/source for the tint below.
      Image {
        id: markSrc
        anchors.fill: parent
        source: Qt.resolvedUrl("squawkr-mark.svg")
        fillMode: Image.PreserveAspectFit
        sourceSize.width: 48
        sourceSize.height: 48
        smooth: true
        visible: false
      }
      // colorization 1.0 replaces the source colour with colorizationColor, keeping the
      // alpha shape — so the mark adopts the bar foreground like the shell's own glyphs.
      MultiEffect {
        anchors.fill: markSrc
        source: markSrc
        colorization: 1.0
        colorizationColor: button.foreground
      }
    }
  }
}
