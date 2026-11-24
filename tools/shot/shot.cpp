// Renders a QML scene on the GPU without showing a window, steps animations
// by fixed frames, and saves PNG screenshots.
#include <QAnimationDriver>
#include <QCommandLineParser>
#include <QElapsedTimer>
#include <QThread>
#include <QGuiApplication>
#include <QImage>
#include <QOffscreenSurface>
#include <QOpenGLContext>
#include <QOpenGLFunctions>
#include <QPropertyAnimation>
#include <QVariantAnimation>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickGraphicsDevice>
#include <QQuickItem>
#include <QQuickRenderControl>
#include <QQuickRenderTarget>
#include <QQuickWindow>
#include <cstdio>

class StepDriver : public QAnimationDriver {
public:
  qint64 t = 0;
  void step(qint64 ms) { t += ms; advance(); }
  qint64 elapsed() const override { return t; }
};

int main(int argc, char **argv) {
  QGuiApplication app(argc, argv);
  QCommandLineParser p;
  p.addPositionalArgument("qml", "QML file");
  p.addPositionalArgument("out", "output PNG (use %1 for the frame number with --every)");
  p.addPositionalArgument("words", "words the scene reads from Qt.application.arguments", "[words...]");
  p.addOption({"size", "WxH (default: the scene's own width and height)", "size"});
  p.addOption({"frames", "frames to run before the shot", "n", "60"});
  p.addOption({"every", "also save every n frames", "n", "0"});
  p.addOption({"settle", "real milliseconds to let worker threads finish before stepping", "ms", "1500"});
  p.addHelpOption();
  p.process(app);
  const QStringList pos = p.positionalArguments();
  if (pos.size() < 2) p.showHelp(2);  // more words are for the scene (Qt.application.arguments)
  const int frames = p.value("frames").toInt(), every = p.value("every").toInt();

  StepDriver driver;
  driver.install();
  // With only pause animations running, Qt times them with a real-time
  // timer instead of the animation driver, and stepped frames outrun it. An
  // endless animation keeps the stepped driver in charge.
  QVariantAnimation keepAlive;
  keepAlive.setStartValue(0.0);
  keepAlive.setEndValue(1.0);
  keepAlive.setDuration(1000);
  keepAlive.setLoopCount(-1);
  keepAlive.start();

  QQmlEngine engine;
  QQmlComponent comp(&engine, QUrl::fromLocalFile(pos[0]));
  QObject *root = comp.create();
  if (!root) { fprintf(stderr, "shot: %s\n", qPrintable(comp.errorString())); return 1; }
  QQuickItem *item = qobject_cast<QQuickItem *>(root);
  if (!item) { fprintf(stderr, "shot: root must be an Item\n"); return 1; }
  QSize size(qRound(item->width()), qRound(item->height()));
  if (p.isSet("size")) {
    const QStringList wh = p.value("size").split('x');
    size = QSize(wh.value(0).toInt(), wh.value(1).toInt());
  }
  if (size.isEmpty()) size = QSize(1920, 1080);

  QSurfaceFormat fmt; fmt.setDepthBufferSize(24); fmt.setStencilBufferSize(8);
  QOpenGLContext ctx; ctx.setFormat(fmt);
  if (!ctx.create()) { fprintf(stderr, "shot: no OpenGL context\n"); return 1; }
  QOffscreenSurface surface; surface.setFormat(ctx.format()); surface.create();
  ctx.makeCurrent(&surface);

  QQuickRenderControl control;
  QQuickWindow window(&control);
  window.setGraphicsDevice(QQuickGraphicsDevice::fromOpenGLContext(&ctx));
  window.resize(size);
  if (!control.initialize()) { fprintf(stderr, "shot: render control failed\n"); return 1; }

  QOpenGLFunctions *gl = ctx.functions();
  GLuint tex = 0;
  gl->glGenTextures(1, &tex);
  gl->glBindTexture(GL_TEXTURE_2D, tex);
  gl->glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, size.width(), size.height(), 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
  gl->glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  window.setRenderTarget(QQuickRenderTarget::fromOpenGLTexture(tex, size));

  item->setParentItem(window.contentItem());
  item->setSize(size);
  window.contentItem()->setSize(size);

  auto render = [&]() {
    control.polishItems();
    control.beginFrame();
    control.sync();
    control.render();
    control.endFrame();
  };
  auto save = [&](const QString &path) {
    ctx.makeCurrent(&surface);
    GLuint fbo = 0;
    gl->glGenFramebuffers(1, &fbo);
    gl->glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    gl->glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);
    QImage img(size, QImage::Format_RGBA8888_Premultiplied);
    gl->glReadPixels(0, 0, size.width(), size.height(), GL_RGBA, GL_UNSIGNED_BYTE, img.bits());
    gl->glBindFramebuffer(GL_FRAMEBUFFER, ctx.defaultFramebufferObject());
    gl->glDeleteFramebuffers(1, &fbo);
    img = img.flipped(Qt::Vertical);
    if (!img.save(path)) { fprintf(stderr, "shot: cannot write %s\n", qPrintable(path)); return false; }
    printf("shot: %s\n", qPrintable(path));
    return true;
  };
  // Worker threads (the game prepares boards on one) run in real time while
  // frames are simulated: let them finish first, without advancing time.
  QElapsedTimer settle;
  settle.start();
  while (settle.elapsed() < p.value("settle").toInt()) {
    QCoreApplication::processEvents(QEventLoop::AllEvents, 20);
    QThread::msleep(5);
  }
  for (int i = 1; i <= frames; ++i) {
    QCoreApplication::processEvents();
    driver.step(16);
    render();
    if (every > 0 && i % every == 0) save(QString(pos[1]).arg(i, 4, 10, QChar('0')));
  }
  return save(QString(pos[1]).arg(frames, 4, 10, QChar('0'))) ? 0 : 1;
}
