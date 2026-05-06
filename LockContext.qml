import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
	id: root
	signal unlocked()
	signal failed()

	property string currentText: ""
	property bool unlockInProgress: false
	property bool showFailure: false
	property bool pamActivated: false
	property bool timedOut: false

	// Expose PAM state for the UI
	readonly property alias pamMessage: pam.message
	readonly property alias pamMessageIsError: pam.messageIsError
	readonly property alias pamResponseRequired: pam.responseRequired
	readonly property alias pamResponseVisible: pam.responseVisible

	onCurrentTextChanged: {
		showFailure = false;
		if (pamActivated) timeoutTimer.restart();
	}

	function requestUnlock() {
		if (root.unlockInProgress) return;
		if (root.pamActivated) return;
		root.pamActivated = true;
		root.timedOut = false;
		root.showFailure = false;
		timeoutTimer.restart();
		tryUnlock();
	}

	function tryUnlock() {
		if (root.unlockInProgress) return;
		root.unlockInProgress = true;
		root.showFailure = false;
		pam.start();
	}

	function cancelPam() {
		timeoutTimer.stop();
		root.timedOut = true;
		if (pam.active) {
			pam.abort();
		}
		root.pamActivated = false;
		root.unlockInProgress = false;
		root.showFailure = false;
		root.currentText = "";
	}

	function respondToPam(response) {
		if (pam.responseRequired) {
			root.unlockInProgress = true;
			timeoutTimer.restart();
			pam.respond(response);
		}
	}

	Timer {
		id: timeoutTimer
		interval: 10000
		repeat: false
		onTriggered: cancelPam()
	}

	PamContext {
		id: pam

		configDirectory: "pam"
		config: "password.conf"

		onPamMessage: {
			if (this.responseRequired) {
				root.unlockInProgress = false;
				timeoutTimer.restart();
			}
		}

		onCompleted: result => {
			if (root.timedOut) return;
			if (result == PamResult.Success) {
				root.unlocked();
			} else {
				root.currentText = "";
				root.showFailure = true;
			}

			root.unlockInProgress = false;
		}

		onError: error => {
			if (root.timedOut) return;
			root.unlockInProgress = false;
		}
	}
}
