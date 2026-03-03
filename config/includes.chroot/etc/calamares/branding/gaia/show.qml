import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1e1b4b"

            Column {
                anchors.centerIn: parent
                spacing: 30

                Image {
                    source: "logo.png"
                    width: 128
                    height: 128
                    anchors.horizontalCenter: parent.horizontalCenter
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    text: "Welcome to Gaia Linux"
                    font.pixelSize: 28
                    font.weight: Font.Light
                    color: "#e9d5ff"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "A clean, beautiful Debian-based distribution."
                    font.pixelSize: 16
                    color: "#c4b5fd"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1e1b4b"

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    text: "Designed for You"
                    font.pixelSize: 28
                    font.weight: Font.Light
                    color: "#e9d5ff"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "• XFCE desktop with a macOS-inspired layout\n• Arc Dark theme with purple accents\n• Alacritty terminal, Firefox, Thunar\n• Powered by Debian Stable"
                    font.pixelSize: 15
                    color: "#c4b5fd"
                    lineHeight: 1.5
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1e1b4b"

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    text: "Almost There..."
                    font.pixelSize: 28
                    font.weight: Font.Light
                    color: "#e9d5ff"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Gaia is being installed on your system.\nThis will only take a few minutes."
                    font.pixelSize: 16
                    color: "#c4b5fd"
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
