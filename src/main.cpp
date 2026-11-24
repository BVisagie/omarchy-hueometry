#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "buildinfo.h"
#include "host.h"

int main(int argc, char *argv[]) {
  QGuiApplication app(argc, argv);
  app.setApplicationName(QStringLiteral("hueometry"));
  app.setApplicationDisplayName(QStringLiteral("Hueometry"));
  app.setApplicationVersion(QStringLiteral(HUEOMETRY_VERSION));
  // matches hueometry.desktop, so the compositor and launcher find the icon
  app.setDesktopFileName(QStringLiteral("hueometry"));

  Host host;
  QQmlApplicationEngine engine;
  engine.rootContext()->setContextProperty(QStringLiteral("appHost"), &host);
  // the commit, for a build that is not the release itself (or "")
  engine.rootContext()->setContextProperty(QStringLiteral("appBuild"), QStringLiteral(HUEOMETRY_BUILD));
  QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                   [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
  engine.load(QUrl(QStringLiteral("qrc:/src/Main.qml")));
  return app.exec();
}
