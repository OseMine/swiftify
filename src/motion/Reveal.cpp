#include "motion/Reveal.h"

#include "app/Settings.h"

#include <QEasingCurve>
#include <QPropertyAnimation>

#include <algorithm>

namespace swiftify {

RevealAttached::RevealAttached(QObject *parent)
    : QObject(parent)
    , m_item(qobject_cast<QQuickItem *>(parent))
{
    // the two animations are made once and reused. rebuilding them as an
    // animation ends deleted the group's children from inside the group's own
    // state change, which left it stepping over freed animations
    m_fade = new QPropertyAnimation(m_item, "opacity");
    m_animation.addAnimation(m_fade);
    m_grow = new QPropertyAnimation(m_item, "scale");
    m_animation.addAnimation(m_grow);

    // queued, so hiding the item runs once the group has finished changing
    // state, and a reveal that starts meanwhile is not cut short by it
    connect(&m_animation, &QAbstractAnimation::finished, this, [this] {
        if (m_item && !m_shown && m_animation.state() == QAbstractAnimation::Stopped) {
            m_item->setVisible(false);
        }
    }, Qt::QueuedConnection);
}

void RevealAttached::setScaleFrom(qreal scale)
{
    if (qFuzzyCompare(m_scaleFrom, scale)) {
        return;
    }
    m_scaleFrom = scale;
    emit scaleFromChanged();
}

void RevealAttached::setDuration(int duration)
{
    if (m_duration == duration) {
        return;
    }
    m_duration = duration;
    emit timingChanged();
}

void RevealAttached::setOvershoot(qreal overshoot)
{
    if (qFuzzyCompare(m_overshoot, overshoot)) {
        return;
    }
    m_overshoot = overshoot;
    emit timingChanged();
}

void RevealAttached::setShown(bool shown)
{
    if (m_settled && shown == m_shown) {
        return;
    }
    const bool first = !m_settled;
    m_settled = true;
    m_shown = shown;
    emit shownChanged();
    if (!m_item) {
        return;
    }
    const Settings *settings = Settings::instance();
    if (first || (settings && settings->performanceMode())) {
        m_animation.stop();
        m_item->setOpacity(shown ? 1 : 0);
        m_item->setScale(1);
        m_item->setVisible(shown);
        return;
    }
    animate(shown);
}

void RevealAttached::animate(bool shown)
{
    if (!m_item || !m_fade || !m_grow) {
        return;
    }
    m_animation.stop();

    if (shown && !m_item->isVisible()) {
        m_item->setOpacity(0);
        m_item->setScale(m_scaleFrom);
    }
    m_item->setVisible(true);

    m_fade->setEndValue(shown ? 1.0 : 0.0);
    m_fade->setDuration(shown ? std::min(200, m_duration) : std::min(150, m_duration));
    m_fade->setEasingCurve(shown ? QEasingCurve::OutCubic : QEasingCurve::InCubic);

    m_grow->setEndValue(shown ? 1.0 : m_scaleFrom);
    m_grow->setDuration(shown ? m_duration : std::min(170, m_duration));
    QEasingCurve spring(shown ? (m_overshoot > 0 ? QEasingCurve::OutBack : QEasingCurve::OutCubic) : QEasingCurve::InCubic);
    if (shown && m_overshoot > 0) {
        spring.setOvershoot(m_overshoot);
    }
    m_grow->setEasingCurve(spring);

    m_animation.start();
}

} // namespace swiftify
