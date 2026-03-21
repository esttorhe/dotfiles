// ABOUTME: Tampermonkey/Violentmonkey userscript that sets Refined GitHub's
// ABOUTME: conversation activity filter to "hideEventsAndCollapsedComments" by default.

// ==UserScript==
// @name         RGH Default: Hide Events & Collapsed Comments
// @namespace    https://github.com/esteban-torres
// @version      1.0.0
// @description  Pre-seeds sessionStorage so Refined GitHub defaults to hiding events and collapsed comments on PRs and issues
// @author       Esteban Torres
// @match        https://github.com/*/pull/*
// @match        https://github.com/*/issues/*
// @run-at       document-start
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    const key = `rgh-conversation-activity-filter-state:${location.pathname}`;
    if (!sessionStorage.getItem(key)) {
        sessionStorage.setItem(key, 'hideEventsAndCollapsedComments');
    }
})();
