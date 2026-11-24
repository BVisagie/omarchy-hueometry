QT += testlib
QT -= gui
CONFIG += c++17 testcase
TARGET = tst_host
SOURCES += tst_host.cpp ../../src/host.cpp
HEADERS += ../../src/host.h
