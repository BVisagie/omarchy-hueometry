#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtTest>

#include "../../src/host.h"

class TestHost : public QObject {
  Q_OBJECT
private slots:
  void initTestCase() { QStandardPaths::setTestModeEnabled(true); }

  void writesAndReadsBack() {
    Host host;
    QVERIFY(host.writeText(QStringLiteral("progress.json"), QStringLiteral("{\"a\":1}")));
    QCOMPARE(host.readText(QStringLiteral("progress.json")), QStringLiteral("{\"a\":1}"));
    QVERIFY(host.writeText(QStringLiteral("progress.json"), QStringLiteral("{}")));
    QCOMPARE(host.readText(QStringLiteral("progress.json")), QStringLiteral("{}"));
  }

  void settingsGoToConfig() {
    Host host;
    QVERIFY(host.pathFor(QStringLiteral("settings.json")).startsWith(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)));
    QVERIFY(host.pathFor(QStringLiteral("progress.json")).startsWith(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)));
    QVERIFY(host.pathFor(QStringLiteral("progress.json")).endsWith(QStringLiteral("/hueometry/progress.json")));
  }

  void refusesOtherNames() {
    Host host;
    for (const char *bad : {"../x.json", "/etc/passwd", "a/b.json", "x.txt", "", ".json", "X.json"}) {
      QVERIFY2(!host.writeText(QString::fromLatin1(bad), QStringLiteral("x")), bad);
      QCOMPARE(host.readText(QString::fromLatin1(bad)), QString());
    }
  }

  void missingFileReadsEmpty() {
    Host host;
    QCOMPARE(host.readText(QStringLiteral("nothing-here.json")), QString());
  }
};

QTEST_GUILESS_MAIN(TestHost)
#include "tst_host.moc"
