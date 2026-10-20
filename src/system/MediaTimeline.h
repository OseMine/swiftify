#pragma once

#include <QtGlobal>

#include <algorithm>

namespace swiftify {

/// what windows' media session publishes as a track's timeline. SMTC counts
/// TimeSpans in 100-nanosecond units, not milliseconds, so the conversion and
/// its bounds live here, apart from winrt, and are tested on every platform
struct MediaTimeline {
    qint64 end = 0;
    qint64 position = 0;

    static MediaTimeline fromMilliseconds(bool hasSong, quint32 engineDuration,
                                          int metadataDuration, quint32 livePosition)
    {
        if (!hasSong) {
            return {};
        }
        // the engine reports a duration once it has opened the stream; until
        // then the song's own metadata is the only end there is
        const qint64 duration = engineDuration > 0 ? qint64(engineDuration) : std::max(0, metadataDuration);
        return {duration * 10000, std::clamp(qint64(livePosition), qint64(0), duration) * 10000};
    }
};

} // namespace swiftify
