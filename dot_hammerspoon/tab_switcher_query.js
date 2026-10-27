// ABOUTME: JXA script that lists the windows and tabs of every running scriptable browser/terminal as JSON.
// ABOUTME: Run with `osascript -l JavaScript tab_switcher_query.js`; output shape is what tab_switcher_core expects.

// Each reader fetches whole properties across all windows in one Apple Event per property,
// which keeps a query of hundreds of tabs fast. Windows come back front to back.

function chromium(appName) {
	return (app) => {
		const windows = app.windows;
		const ids = windows.id();
		const titles = windows.tabs.title();
		const urls = windows.tabs.url();
		const activeIndexes = windows.activeTabIndex();
		return {
			appName,
			windows: ids.map((id, w) => ({
				id,
				tabs: titles[w].map((title, t) => ({
					id: String(t + 1),
					index: t + 1,
					title,
					url: urls[w][t],
					active: activeIndexes[w] === t + 1,
				})),
			})),
		};
	};
}

function safari(app) {
	const windows = app.windows.whose({ visible: true });
	const ids = windows.id();
	const titles = windows.tabs.name();
	const urls = windows.tabs.url();
	const activeIndexes = windows.currentTab.index();
	return {
		appName: "Safari",
		windows: ids.map((id, w) => ({
			id,
			tabs: titles[w].map((title, t) => ({
				id: String(t + 1),
				index: t + 1,
				title,
				url: urls[w][t],
				active: activeIndexes[w] === t + 1,
			})),
		})),
	};
}

function dia(app) {
	const windows = app.windows;
	const ids = windows.id();
	const tabIds = windows.tabs.id();
	const titles = windows.tabs.title();
	const urls = windows.tabs.url();
	const activeIds = windows.activeTab.id();
	return {
		appName: "Dia",
		windows: ids.map((id, w) => ({
			id,
			tabs: tabIds[w].map((tabId, t) => ({
				id: tabId,
				index: t + 1,
				title: titles[w][t],
				url: urls[w][t],
				active: activeIds[w] === tabId,
			})),
		})),
	};
}

function ghostty(app) {
	const windows = app.windows;
	const ids = windows.id();
	const tabIds = windows.tabs.id();
	const names = windows.tabs.name();
	const selectedIds = windows.selectedTab.id();
	return {
		appName: "Ghostty",
		windows: ids.map((id, w) => ({
			id,
			tabs: tabIds[w].map((tabId, t) => ({
				id: tabId,
				index: t + 1,
				title: names[w][t],
				active: selectedIds[w] === tabId,
			})),
		})),
	};
}

const READERS = {
	"com.google.Chrome": chromium("Google Chrome"),
	"com.google.Chrome.beta": chromium("Google Chrome Beta"),
	"com.brave.Browser": chromium("Brave"),
	"com.microsoft.edgemac": chromium("Microsoft Edge"),
	"company.thebrowser.Browser": chromium("Arc"),
	"com.apple.Safari": safari,
	"company.thebrowser.dia": dia,
	"com.mitchellh.ghostty": ghostty,
};

function run() {
	const result = {};
	for (const bundleID of Object.keys(READERS)) {
		try {
			const app = Application(bundleID);
			if (!app.running()) continue;
			result[bundleID] = READERS[bundleID](app);
		} catch (error) {
			// Not installed, mid-launch, or Automation permission denied: the app's windows
			// stay in the switcher as plain window rows instead of tabs.
		}
	}
	return JSON.stringify(result);
}
