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

	Keys.onEscapePressed: {
		if (root.context.pamActivated) {
			root.context.cancelPam();
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

		// Fingerprint indicator - shown while PAM is asking for a fingerprint
		Label {
			id: fingerprintIndicator
			visible: root.context.isFingerprintPrompt
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
				placeholderText: "Enter password"

				implicitWidth: 200
				padding: 12

				focus: true

				enabled: !root.context.unlockInProgress
				echoMode: TextInput.Password
				inputMethodHints: Qt.ImhSensitiveData

				color: Qt.rgba(1, 1, 1, 0.7)
				selectionColor: "#666666"
				selectedTextColor: bg
				placeholderTextColor: Qt.rgba(1, 1, 1, 0.4)

				background: Rectangle {
					color: Qt.rgba(1, 1, 1, 0.1)
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

			// Button {
			// 	id: unlockButton
			// 	implicitWidth: passwordBox.implicitHeight * .8
			// 	implicitHeight: passwordBox.implicitHeight * .8
			//
			// 	focusPolicy: Qt.NoFocus
			//
			// 	enabled: !root.context.unlockInProgress && root.context.currentText !== "";
			//
			// 	contentItem: Text {
			// 		text: "›"
			// 		color: parent.enabled ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(1, 1, 1, 0.3)
			// 		font.pointSize: 28
			// 		horizontalAlignment: Text.AlignHCenter
			// 		verticalAlignment: Text.AlignVCenter
			// 	}
			//
			// 	background: Rectangle {
			// 		color: parent.enabled ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
			// 		radius: width / 2
			// 	}
			//
			// 	onClicked: {
			// 		if (root.context.pamResponseRequired) {
			// 			root.context.respondToPam(passwordBox.text);
			// 		} else {
			// 			Qt.callLater(root.context.tryUnlock);
			// 		}
			// 	}
			// }
		}

		// Spinner loader - shown while verifying
		Item {
			visible: root.context.unlockInProgress && root.context.pamResponseRequired
			implicitWidth: 24
			implicitHeight: 24
			Layout.alignment: Qt.AlignHCenter

			Rectangle {
				anchors.centerIn: parent
				width: 20
				height: 20
				color: "transparent"
				transform: Rotation {
					origin.x: 10
					origin.y: 10
					angle: 0

					NumberAnimation on angle {
						from: 0
						to: 360
						duration: 800
						loops: Animation.Infinite
					}
				}

				Canvas {
					anchors.fill: parent
					anchors.margins: 2

					onPaint: {
						var ctx = getContext("2d");
						ctx.reset();
						ctx.lineWidth = 2;
						ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.6);
						ctx.lineCap = "round";
						ctx.beginPath();
						ctx.arc(width / 2, height / 2, width / 2 - 1, 0, Math.PI * 1.5);
						ctx.stroke();
					}
				}
			}
		}

		// Retry button - shown after failed auth
		Column {
			visible: root.context.pamActivated && root.context.showFailure && !root.context.unlockInProgress
			spacing: 6
			Layout.alignment: Qt.AlignHCenter

			Button {
				implicitWidth: 48
				implicitHeight: 48

				contentItem: Text {
					text: "↻"
					color: Qt.rgba(1, 1, 1, 0.5)
					font.pointSize: 16
					font.weight: Font.Bold
					horizontalAlignment: Text.AlignHCenter
					verticalAlignment: Text.AlignVCenter
				}

				background: Rectangle {
					color: Qt.rgba(1, 1, 1, 0.08)
					radius: width / 2
				}

				onClicked: root.context.tryUnlock();
			}

			Text {
				text: "Retry"
				color: Qt.rgba(1, 1, 1, 0.35)
				font.pointSize: 9
				anchors.horizontalCenter: parent.horizontalCenter
			}
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
			color: root.context.pamMessageIsError ? error : Qt.rgba(1, 1, 1, 0.55)
			font.pointSize: 13
			Layout.alignment: Qt.AlignHCenter
		}
	}

	Column {
		visible: root.context.pamActivated
		anchors {
			horizontalCenter: parent.horizontalCenter
			bottom: parent.bottom
			bottomMargin: 40
		}
		spacing: 6

		Button {
			implicitWidth: 48
			implicitHeight: 48

			contentItem: Text {
				text: "✕"
				color: Qt.rgba(1, 1, 1, 0.5)
				font.pointSize: 16
				font.weight: Font.Bold
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
			}

			background: Rectangle {
				color: Qt.rgba(1, 1, 1, 0.08)
				radius: width / 2
			}

			onClicked: root.context.cancelPam();
		}

		Text {
			text: "Cancel"
			color: Qt.rgba(1, 1, 1, 0.35)
			font.pointSize: 9
			anchors.horizontalCenter: parent.horizontalCenter
		}
	}
}
