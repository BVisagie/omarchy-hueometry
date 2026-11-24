#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "host.h"

// written by qmake into the build folder (hueometry.pro)
extern const char hueometryVersion[];
extern const char hueometryBuild[];

int main(int argc, char *argv[]) {
  QGuiApplication app(argc, argv);
  app.setApplicationName(QStringLiteral("hueometry"));
  app.setApplicationDisplayName(QStringLiteral("Hueometry"));
  app.setApplicationVersion(QString::fromLatin1(hueometryVersion));
  // matches hueometry.desktop, so the compositor and launcher find the icon
  app.setDesktopFileName(QStringLiteral("hueometry"));

  Host host;
  QQmlApplicationEngine engine;
  engine.rootContext()->setContextProperty(QStringLiteral("appHost"), &host);
  // the commit, for a build that is not the release itself (or "")
  engine.rootContext()->setContextProperty(QStringLiteral("appBuild"), QString::fromLatin1(hueometryBuild));
  QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                   [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
  engine.load(QUrl(QStringLiteral("qrc:/src/Main.qml")));
  return app.exec();
}
