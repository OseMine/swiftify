#pragma once

#include <QColor>
#include <QIcon>
#include <QImage>
#include <QObject>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

namespace swiftify {

class Settings;
class Theme;

/// the icon the desktop shows for swiftify: the app's own, or the material
/// one, its blob and wave in the theme's colours when the settings ask for
/// a tint. the window, the dock and the tray all take it from here.
class AppIcon : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    /// where the tray and the settings' preview read the icon from: a qrc
    /// path, or a png written to the cache for a tinted one
    Q_PROPERTY(QUrl source READ source NOTIFY sourceChanged FINAL)

public:
    /// settings and theme are the app's own, and outlive this
    explicit AppIcon(Settings *settings, Theme *theme, QObject *parent = nullptr);
    ~AppIcon() override;

    static AppIcon *instance();
    static AppIcon *create(QQmlEngine *, QJSEngine *);

    QUrl source() const { return m_source; }

signals:
    void sourceChanged();

private:
    void refresh();
    /// the image's alpha, filled with the colour
    static QImage tinted(const QImage &mask, const QColor &color);

    Settings *m_settings;
    Theme *m_theme;
    QImage m_image;
    QIcon m_icon;
    QUrl m_source;
    /// the tinted png in the cache, to replace when the colours move
    QString m_generatedPath;
};

} // namespace swiftify
