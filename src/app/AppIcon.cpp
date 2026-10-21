#include "app/AppIcon.h"

#include "app/Paths.h"
#include "app/Settings.h"
#include "theme/Theme.h"

#ifdef Q_OS_MACOS
#include "system/macos/MacWindow.h"
#endif

#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QPainter>
#include <QPixmap>
#include <QQmlEngine>
#include <QWindow>

namespace swiftify {

namespace {

AppIcon *s_instance = nullptr;

const QString kDefaultIcon = QStringLiteral(":/qt/qml/Swiftify/resources/swiftify-icon.png");
const QString kMaterialIcon = QStringLiteral(":/qt/qml/Swiftify/resources/app-icon-material.png");
const QString kMaterialBlob = QStringLiteral(":/qt/qml/Swiftify/resources/app-icon-material-blob.png");
const QString kMaterialMark = QStringLiteral(":/qt/qml/Swiftify/resources/app-icon-material-mark.png");

} // namespace

AppIcon::AppIcon(Settings *settings, Theme *theme, QObject *parent)
    : QObject(parent)
    , m_settings(settings)
    , m_theme(theme)
{
    if (!s_instance) {
        s_instance = this;
    }
    connect(settings, &Settings::appIconChanged, this, &AppIcon::refresh);
    connect(settings, &Settings::tintAppIconChanged, this, &AppIcon::refresh);
    connect(theme, &Theme::schemeChanged, this, [this] {
        if (m_settings->appIcon() == QLatin1StringView("material") && m_settings->tintAppIcon()) {
            refresh();
        }
    });
    refresh();
}

AppIcon::~AppIcon()
{
    if (s_instance == this) {
        s_instance = nullptr;
    }
}

AppIcon *AppIcon::instance()
{
    return s_instance;
}

AppIcon *AppIcon::create(QQmlEngine *, QJSEngine *)
{
    if (!s_instance) {
        return nullptr;
    }
    QJSEngine::setObjectOwnership(s_instance, QJSEngine::CppOwnership);
    return s_instance;
}

QImage AppIcon::tinted(const QImage &mask, const QColor &color)
{
    QImage layer(mask.size(), QImage::Format_ARGB32_Premultiplied);
    layer.fill(color);
    QPainter painter(&layer);
    painter.setCompositionMode(QPainter::CompositionMode_DestinationIn);
    painter.drawImage(0, 0, mask);
    return layer;
}

void AppIcon::refresh()
{
    const bool material = m_settings->appIcon() == QLatin1StringView("material");
    const bool tint = material && m_settings->tintAppIcon();

    if (tint) {
        const QColor background = m_theme->colors()->primary();
        const QColor mark = m_theme->colors()->onPrimary();
        QImage image(1024, 1024, QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::transparent);
        QPainter painter(&image);
        painter.drawImage(0, 0, tinted(QImage(kMaterialBlob), background));
        painter.drawImage(0, 0, tinted(QImage(kMaterialMark), mark));
        painter.end();

        const QString name = QStringLiteral("app-icon-material-%1-%2.png")
                                 .arg(background.name(QColor::HexArgb).mid(1),
                                      mark.name(QColor::HexArgb).mid(1));
        const QString path = QDir(paths::cacheDirectory()).filePath(name);
        image.save(path, "PNG");
        // only the newest tint is worth keeping around
        if (!m_generatedPath.isEmpty() && m_generatedPath != path) {
            QFile::remove(m_generatedPath);
        }
        m_generatedPath = path;
        m_image = image;
        m_source = QUrl::fromLocalFile(path);
    } else {
        m_image = QImage(material ? kMaterialIcon : kDefaultIcon);
        m_source = QUrl(material ? QStringLiteral("qrc:") + kMaterialIcon
                                 : QStringLiteral("qrc:") + kDefaultIcon);
    }

    m_icon = QIcon(QPixmap::fromImage(m_image));
    QGuiApplication::setWindowIcon(m_icon);
    // windows already made keep the icon they were given
    const auto windows = QGuiApplication::topLevelWindows();
    for (QWindow *window : windows) {
        window->setIcon(m_icon);
    }
#ifdef Q_OS_MACOS
    // the bundle's own icon is the default; the dock falls back to it
    macos::setApplicationIcon(material ? m_image : QImage());
#endif
    emit sourceChanged();
}

} // namespace swiftify
