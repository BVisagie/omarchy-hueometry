#include "host.h"

#include <QDir>
#include <QFile>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>

Host::Host(QObject *parent) : QObject(parent) {}

bool Host::validName(const QString &name) {
  static const QRegularExpression ok(QStringLiteral("^[a-z][a-z0-9-]*\\.json$"));
  return ok.match(name).hasMatch();
}

QString Host::pathFor(const QString &name) const {
  const auto where = name == QStringLiteral("settings.json") ? QStandardPaths::GenericConfigLocation
                                                              : QStandardPaths::GenericDataLocation;
  return QStandardPaths::writableLocation(where) + QStringLiteral("/hueometry/") + name;
}

QString Host::readText(const QString &name) const {
  if (!validName(name)) return {};
  QFile file(pathFor(name));
  if (!file.open(QIODevice::ReadOnly)) return {};
  return QString::fromUtf8(file.readAll());
}

bool Host::writeText(const QString &name, const QString &text) const {
  if (!validName(name)) return false;
  const QString path = pathFor(name);
  if (!QDir().mkpath(QFileInfo(path).absolutePath())) return false;
  QSaveFile file(path);
  if (!file.open(QIODevice::WriteOnly)) return false;
  file.write(text.toUtf8());
  return file.commit();
}
