# The standalone Hueometry app: a thin C++ host around the shared QML module.
QT += quick qml
CONFIG += c++17
TARGET = hueometry
VERSION = 0.1.0

# The version, and which commit this build is (tools/version/build-id.sh),
# written into a header rather than a define: a changed header recompiles
# main.cpp, a changed define does not, so the build never shows a stale id.
BUILD_ID = $$system(bash $$shell_quote($$PWD/tools/version/build-id.sh) $$VERSION)
BUILDINFO = "$${LITERAL_HASH}define HUEOMETRY_VERSION \"$$VERSION\"" \
            "$${LITERAL_HASH}define HUEOMETRY_BUILD \"$$BUILD_ID\""
write_file($$OUT_PWD/buildinfo.h, BUILDINFO)|error("could not write buildinfo.h")
INCLUDEPATH += $$OUT_PWD

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
