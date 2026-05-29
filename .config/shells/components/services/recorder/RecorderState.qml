pragma Singleton

import QtQuick

QtObject {
    id: root

    property bool isRecording: false
    property bool isPaused: false
    property bool isVisible: false
    property int elapsedSeconds: 0
    property string outputPath: ""
    property int recorderPid: -1

    function toggle() {
        isVisible = !isVisible
    }

    function open() {
        isVisible = true
    }

    function close() {
        if (!isRecording)
            isVisible = false
    }

    function start(path) {
        outputPath = path
        elapsedSeconds = 0
        recorderPid = -1
        isPaused = false
        isRecording = true
        isVisible = true
    }

    function pause() {
        if (isRecording)
            isPaused = true
    }

    function resume() {
        if (isRecording)
            isPaused = false
    }

    function stop() {
        isRecording = false
        isPaused = false
        recorderPid = -1
    }

    function reset() {
        isRecording = false
        isPaused = false
        isVisible = false
        elapsedSeconds = 0
        outputPath = ""
        recorderPid = -1
    }
}
