# CutLink design standard

Agreed 27 September 2026: all new features and changes must use the current CutLink commercial workspace design. Never reintroduce legacy Material default screens. Upgrade old styling encountered in the area being edited, while preserving behaviour and data.

- Use current Supplier Sales, Inventory and Butcher Browse as visual references.
- Burgundy actions (#741C1C), navy text (#101D2B), pale workspace background, white surfaces, subtle borders and rounded corners.
- Reuse `CutLinkWorkspaceTheme`, existing CutLink pickers and responsive workspace components. Do not create a competing theme.
- Compact, readable information hierarchy; responsive controls; no overflow; whole-page scrolling on phones.
- Keep desktop working areas spacious without large empty gaps. Preserve document and account actions.
- Prefer labelled actions, meaningful empty/error states and consistent icon treatments.
- Notifications belong in the activity inbox; preferences belong in Settings.
- Dashboard bell: current Sydney calendar day only, unread count for enabled alerts, live additions, reset at Sydney midnight, no mark-all-read on panel open. Its footer links to the full history.
- Credit notes remain within invoice workflows. Keep invoice allocation and available-credit amounts accurate when changing presentation.
- Inspect current exact source before editing. Preserve existing features and validate Dart changes.
