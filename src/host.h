#pragma once

#include <QObject>
#include <QString>

// Saves for the standalone app: settings in $XDG_CONFIG_HOME/hueometry,
// everything else in $XDG_DATA_HOME/hueometry, written atomically. The shell
// plugin uses the same folders, so both channels share progress.
class Host : public QObject {
  Q_OBJECT
public:
  explicit Host(QObject *parent = nullptr);

  // name is a plain file name such as "progress.json"; anything else is
  // refused, so the interface can never write outside the save folders
  Q_INVOKABLE QString readText(const QString &name) const;
  Q_INVOKABLE bool writeText(const QString &name, const QString &text) const;

  static bool validName(const QString &name);
  QString pathFor(const QString &name) const;
};
