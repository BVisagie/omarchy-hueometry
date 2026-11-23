# The standalone Hueometry app: a thin C++ host around the shared QML module.
QT += quick qml
CONFIG += c++17
TARGET = hueometry
VERSION = 0.1.0
DEFINES += HUEOMETRY_VERSION=\\\"$$VERSION\\\"

SOURCES += src/main.cpp src/host.cpp
HEADERS += src/host.h

# The QML, the engine and the sounds are compiled into the binary.
game.files = src/Main.qml \
  $$files(qml/Hueometry/qmldir) \
  $$files(qml/Hueometry/*.qml) \
  $$files(qml/Hueometry/js/*.mjs) \
  $$files(qml/Hueometry/sounds/*)
game.prefix = /
RESOURCES += game

target.path = /usr/bin
INSTALLS += target
