import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    // --- Slide 1: Welcome ---
    Slide {
        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                GradientStop { position: 0.0; color: "#f5f5eb" }
                GradientStop { position: 0.5; color: "#d4e840" }
                GradientStop { position: 1.0; color: "#f5f5eb" }
            }

            Column {
                anchors.centerIn: parent
                spacing: 30

                Image {
                    source: "logo.png"
                    width: 220
                    height: width * sourceSize.height / sourceSize.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    text: "Welcome to Gaia Linux"
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                    color: "#2a2a2a"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Fast. Clean. Yours."
                    font.pixelSize: 16
                    font.letterSpacing: 2
                    color: "#505050"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // --- Slide 2: Performance ---
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#2a2a2a"

            Column {
                anchors.centerIn: parent
                spacing: 25

                Text {
                    text: "Built for Speed"
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                    color: "#c4d600"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: 60; height: 2
                    color: "#c4d600"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "zRAM compressed swap\nSSD-optimized I/O scheduling\nTuned kernel parameters\nMinimal background services"
                    font.pixelSize: 15
                    color: "#d0d0c8"
                    lineHeight: 1.8
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // --- Slide 3: Desktop ---
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#2a2a2a"

            Column {
                anchors.centerIn: parent
                spacing: 25

                Text {
                    text: "Your Desktop"
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                    color: "#c4d600"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: 60; height: 2
                    color: "#c4d600"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "KDE Plasma 6 with Breeze Dark\nAlacritty GPU-accelerated terminal\nFirefox · Dolphin · Kate\nPipeWire audio · Bluetooth ready"
                    font.pixelSize: 15
                    color: "#d0d0c8"
                    lineHeight: 1.8
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // --- Slide 4: Almost done ---
    Slide {
        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2a2a2a" }
                GradientStop { position: 1.0; color: "#3a3a2a" }
            }

            Column {
                anchors.centerIn: parent
                spacing: 25

                Image {
                    source: "logo.png"
                    width: 160
                    height: width * sourceSize.height / sourceSize.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.9
                    smooth: true
                }

                Text {
                    text: "Almost there..."
                    font.pixelSize: 26
                    font.weight: Font.Light
                    font.letterSpacing: 1
                    color: "#e8e8e0"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Your system will be ready in a moment."
                    font.pixelSize: 14
                    color: "#909088"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
