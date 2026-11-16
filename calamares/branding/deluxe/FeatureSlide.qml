// One slideshow page: navy gradient, gold headline, short text.
import QtQuick 2.0;

Rectangle {
    id: slide
    property string heading: ""
    property string body: ""
    property string glyph: ""
    anchors.fill: parent
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#1a2a63" }
        GradientStop { position: 1.0; color: "#070c20" }
    }

    Rectangle {          // soft gold glow, bottom left
        width: parent.width * 0.8; height: parent.height * 0.5
        x: -parent.width * 0.2; y: parent.height * 0.75
        radius: width / 2; color: "#f5c542"; opacity: 0.10
    }

    Text {
        id: icon
        text: slide.glyph
        font.pixelSize: 92
        color: "#f5c542"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.14
    }
    Text {
        id: title
        text: slide.heading
        font.pixelSize: 30
        font.bold: true
        color: "#f5c542"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: icon.bottom
        anchors.topMargin: 18
        horizontalAlignment: Text.AlignHCenter
        width: parent.width * 0.8
        wrapMode: Text.WordWrap
    }
    Text {
        text: slide.body
        font.pixelSize: 17
        color: "#cdd6ff"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: title.bottom
        anchors.topMargin: 14
        horizontalAlignment: Text.AlignHCenter
        width: parent.width * 0.72
        wrapMode: Text.WordWrap
        lineHeight: 1.25
    }
}
