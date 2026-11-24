# The standalone Hueometry app: a thin C++ host around the shared QML module.
QT += quick qml
CONFIG += c++17
TARGET = hueometry
VERSION = 0.2.0

# The version, and which commit this build is (tools/version/build-id.sh),
# written into a source file in the build folder rather than a define (a
# changed define does not recompile) or a header (a stray copy in the source
# folder would come first in the include path and stay stale).
BUILD_ID = $$system(bash $$shell_quote($$PWD/tools/version/build-id.sh) $$VERSION)
BUILDINFO = "extern const char hueometryVersion[] = \"$$VERSION\";" \
            "extern const char hueometryBuild[] = \"$$BUILD_ID\";"
write_file($$OUT_PWD/buildinfo.cpp, BUILDINFO)|error("could not write buildinfo.cpp")
SOURCES += $$OUT_PWD/buildinfo.cpp

SOURCES += src/main.cpp src/host.cpp
HEADERS += src/host.h

# The QML, the engine and the sounds are compiled into the binary.
game.files = src/Main.qml \
  $$files(qml/Hueometry/qmldir) \
  $$files(qml/Hueometry/*.qml) \
  $$files(qml/Hueometry/js/*.mjs) \
  $$files(qml/Hueometry/sounds/*) \
  $$files(qml/Hueometry/fonts/*)
game.prefix = /
RESOURCES += game

target.path = /usr/bin
INSTALLS += target
