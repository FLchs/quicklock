import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Fusion
import Quickshell.Wayland

Rectangle {
	id: root
	required property LockContext context

	readonly property color bg: "#000000"
	readonly property color fg: "#ffffff"
	readonly property color surface: "#1a1a1a"
	readonly property color border: "#333333"
	readonly property color accent: "#4a4a4a"
	readonly property color error: "#ff4444"

	color: bg

	Image {
		anchors.fill: parent
		source: "background.jpg"
		fillMode: Image.PreserveAspectCrop
		opacity: 0.6
	}

	Rectangle {
		anchors.fill: parent
		color: "#000000"
		opacity: 0.3
	}

	focus: true

	MouseArea {
		anchors.fill: parent
		visible: !root.context.pamActivated
		onClicked: root.context.requestUnlock()
	}

	Keys.onPressed: (event) => {
		if (!root.context.pamActivated) {
			root.context.requestUnlock();
		}
	}

		Label {
			id: dateLabel
			property var date: new Date()

			anchors {
				horizontalCenter: parent.horizontalCenter
				top: parent.top
				topMargin: 60
			}

			renderType: Text.NativeRendering
			font.pointSize: 24
			color: Qt.rgba(1, 1, 1, 0.7)

			Timer {
				running: true
				repeat: true
				interval: 1000

				onTriggered: dateLabel.date = new Date();
			}

			text: {
				const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
				const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
				return `${days[this.date.getDay()]}, ${months[this.date.getMonth()]} ${this.date.getDate()}, ${this.date.getFullYear()}`;
			}
		}

		Label {
			id: clock
			property var date: new Date()

			anchors {
				horizontalCenter: parent.horizontalCenter
				top: dateLabel.bottom
				topMargin: 8
			}

			renderType: Text.NativeRendering
			font.pointSize: 80
			color: Qt.rgba(1, 1, 1, 0.7)

			Timer {
				running: true
				repeat: true
				interval: 1000

				onTriggered: clock.date = new Date();
			}

			text: {
				const hours = this.date.getHours().toString().padStart(2, '0');
				const minutes = this.date.getMinutes().toString().padStart(2, '0');
				return `${hours}:${minutes}`;
			}
		}

	ColumnLayout {
		anchors {
			horizontalCenter: parent.horizontalCenter
			top: parent.verticalCenter
		}

		spacing: 16

		// Hint label - shown before any auth attempt
		Label {
			id: hintLabel
			visible: !root.context.pamActivated
			text: "Click or press any key to unlock"
			color: Qt.rgba(1, 1, 1, 0.4)
			font.pointSize: 14
			Layout.alignment: Qt.AlignHCenter

			SequentialAnimation {
				id: hintPulseAnimation
				running: hintLabel.visible
				loops: Animation.Infinite

				NumberAnimation {
					target: hintLabel
					property: "opacity"
					to: 0.5
					duration: 2000
				}
				NumberAnimation {
					target: hintLabel
					property: "opacity"
					to: 1.0
					duration: 2000
				}
			}
		}

		// Fingerprint indicator - shown while scanning and not waiting for password
		Label {
			id: fingerprintIndicator
			visible: root.context.pamActivated && !root.context.pamResponseRequired && root.context.unlockInProgress
			text: "󰈷"
			color: fg
			font.pointSize: 25
			Layout.alignment: Qt.AlignHCenter

			SequentialAnimation {
				id: pulseAnimation
				running: fingerprintIndicator.visible
				loops: Animation.Infinite

				NumberAnimation {
					target: fingerprintIndicator
					property: "opacity"
					to: 0.4
					duration: 2000
				}
				NumberAnimation {
					target: fingerprintIndicator
					property: "opacity"
					to: 1.0
					duration: 2000
				}
			}
		}

		// Password field - shown when PAM requests a response (password fallback after fingerprint)
		RowLayout {
			visible: root.context.pamActivated && root.context.pamResponseRequired
			Layout.alignment: Qt.AlignHCenter

			TextField {
				id: passwordBox

				implicitWidth: 400
				padding: 12

				focus: true
				enabled: !root.context.unlockInProgress
				echoMode: TextInput.Password
				inputMethodHints: Qt.ImhSensitiveData

				color: fg
				selectionColor: "#666666"
				selectedTextColor: bg
				placeholderTextColor: Qt.rgba(1, 1, 1, 0.4)

				background: Rectangle {
					color: surface
					border.color: passwordBox.activeFocus ? "#555555" : border
					border.width: 1
					radius: 6
				}

				onTextChanged: root.context.currentText = this.text;

				onAccepted: {
					if (root.context.pamResponseRequired) {
						root.context.respondToPam(passwordBox.text);
					} else {
						Qt.callLater(root.context.tryUnlock);
					}
				}

				Connections {
					target: root.context

					function onCurrentTextChanged() {
						passwordBox.text = root.context.currentText;
					}
				}

				Connections {
					target: root.context

					function onPamResponseRequiredChanged() {
						if (root.context.pamResponseRequired) {
							passwordBox.forceActiveFocus();
						}
					}
				}
			}

			Button {
				text: "Unlock"
				padding: 12

				focusPolicy: Qt.NoFocus

				enabled: !root.context.unlockInProgress && root.context.currentText !== "";

				contentItem: Text {
					text: parent.text
					color: fg
					font: parent.font
					horizontalAlignment: Text.AlignHCenter
					verticalAlignment: Text.AlignVCenter
				}

				background: Rectangle {
					color: parent.enabled ? accent : Qt.darker(accent, 1.5)
					radius: 6
				}

				onClicked: {
					if (root.context.pamResponseRequired) {
						root.context.respondToPam(passwordBox.text);
					} else {
						Qt.callLater(root.context.tryUnlock);
					}
				}
			}
		}

		// Retry button - shown after failed auth
		Button {
			visible: root.context.pamActivated && root.context.showFailure && !root.context.unlockInProgress
			text: "Retry"
			padding: 12
			Layout.alignment: Qt.AlignHCenter

			contentItem: Text {
				text: parent.text
				color: fg
				font: parent.font
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
			}

			background: Rectangle {
				color: parent.enabled ? accent : Qt.darker(accent, 1.5)
				radius: 6
			}

			onClicked: root.context.tryUnlock();
		}

		// Status message
		Label {
			id: statusLabel
			visible: text !== ""
			text: {
				if (root.context.pamMessageIsError)
					return root.context.pamMessage;
				if (root.context.showFailure)
					return "Authentication failed";
				return "";
			}
			color: root.context.pamMessageIsError ? error : fg
			Layout.alignment: Qt.AlignHCenter
		}
	}
}
