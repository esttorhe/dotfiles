// ABOUTME: JXA script that brings one tab of a scriptable browser/terminal to the front.
// ABOUTME: Run with `osascript -l JavaScript tab_switcher_activate.js <bundleID> <windowId> <tabId> <tabIndex>`.

function chromium(app, windowId, tabId, tabIndex) {
	const window = app.windows.byId(Number(windowId));
	window.activeTabIndex = tabIndex;
	window.index = 1;
}

function safari(app, windowId, tabId, tabIndex) {
	const window = app.windows.byId(Number(windowId));
	window.currentTab = window.tabs[tabIndex - 1];
	window.index = 1;
}

function dia(app, windowId, tabId) {
	app.windows.byId(windowId).tabs.byId(tabId).focus();
}

function ghostty(app, windowId, tabId) {
	const window = app.windows.byId(windowId);
	app.selectTab(window.tabs.byId(tabId));
	app.activateWindow(window);
}

const ACTIVATORS = {
	"com.google.Chrome": chromium,
	"com.google.Chrome.beta": chromium,
	"com.brave.Browser": chromium,
	"com.microsoft.edgemac": chromium,
	"company.thebrowser.Browser": chromium,
	"com.apple.Safari": safari,
	"company.thebrowser.dia": dia,
	"com.mitchellh.ghostty": ghostty,
};

function run(argv) {
	const [bundleID, windowId, tabId, tabIndex] = argv;
	const app = Application(bundleID);
	ACTIVATORS[bundleID](app, windowId, tabId, Number(tabIndex));
	app.activate();
}
