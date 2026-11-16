// Deluxe System 1 installer slideshow (Calamares slideshow API 2)
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    function nextSlide() { presentation.goToNextSlide(); }

    Timer {
        id: advanceTimer
        interval: 7000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        FeatureSlide {
            glyph: "D1"
            heading: "Welcome to Deluxe System 1"
            body: "Version 1.0 “Aurora”. A polished, fast desktop that is ready to use the moment the installation finishes."
        }
    }
    Slide {
        FeatureSlide {
            glyph: "◐"
            heading: "Beautiful, day and night"
            body: "A custom theme with rounded corners, a bottom dock and five original wallpapers. It switches between light and dark automatically, and Night Light warms your screen in the evening."
        }
    }
    Slide {
        FeatureSlide {
            glyph: "⚡"
            heading: "Fast by default"
            body: "Compressed-RAM swap, smart preloading, SSD TRIM and a tuned boot keep everything snappy, even on modest hardware."
        }
    }
    Slide {
        FeatureSlide {
            glyph: "✎"
            heading: "Everything you need, installed"
            body: "Firefox, LibreOffice, VLC, GIMP, VSCodium, Git, Python, Node.js and Docker are ready. Inkscape, OBS Studio and more are one click away in the Welcome app."
        }
    }
    Slide {
        FeatureSlide {
            glyph: "🔒"
            heading: "Secure from the first boot"
            body: "The firewall is on, AppArmor is active and security updates install automatically. If you chose encryption, your whole disk is protected."
        }
    }
    Slide {
        FeatureSlide {
            glyph: "⟳"
            heading: "Updates made simple"
            body: "Run  deluxe-update  or use the Welcome app to update system packages, Flatpak apps and firmware in one step. Timeshift is installed to take system snapshots."
        }
    }

    function onActivate() { }
    function onLeave() { }
}
