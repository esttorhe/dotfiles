// ABOUTME: Violentmonkey userscript that forces Refined GitHub's conversation
// ABOUTME: activity filter to "hideEventsAndCollapsedComments" by default on PRs and issues.

// ==UserScript==
// @name         RGH Default: Hide Events & Collapsed Comments
// @namespace    https://github.com/esteban-torres
// @version      3.0.0
// @description  Forces Refined GitHub to default to hiding events and collapsed comments on PRs and issues
// @author       Esteban Torres
// @match        https://github.com/*/pull/*
// @match        https://github.com/*/issues/*
// @run-at       document-start
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    const DESIRED_STATE = 'hideEventsAndCollapsedComments';

    // Seed sessionStorage so RGH's dropdown UI shows the correct selection
    const key = `rgh-conversation-activity-filter-state:${location.pathname}`;
    if (!sessionStorage.getItem(key)) {
        sessionStorage.setItem(key, DESIRED_STATE);
    }

    // Inject CSS that hides items directly using the same classes RGH adds.
    // RGH's own CSS only activates when a container has the right data-attribute,
    // but that attribute may not get set due to timing issues with GitHub's React
    // rendering. This CSS works unconditionally on RGH-classified items.
    const style = document.createElement('style');
    style.textContent = `
        .rgh-conversation-activity-filtered-event,
        .rgh-conversation-activity-collapsed-comment,
        .js-resolvable-timeline-thread-container[data-resolved='true'],
        .minimized-comment {
            display: none !important;
        }
    `;
    document.documentElement.appendChild(style);
})();
