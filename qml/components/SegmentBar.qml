import QtQuick
import "."

// A meter in the active look's gauge shape (DynamicMetricGauge): the
// Guide's segmented blocks, or the skin's. `fill` defaults to the load
// colour of the level.
DynamicMetricGauge {
    id: bar

    property real fraction: 0            // 0..1
    property real segmentHeight: 8
    property color fill: Theme.gaugeLoad(fraction * 100)

    value: fraction
    fillColor: fill
    implicitHeight: segmentHeight
}
