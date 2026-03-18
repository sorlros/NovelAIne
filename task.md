# UI Revamp Task: Auth & Story Creation

## Objective
To revamp the current Login/Registration UI and Story Creation UI so that they match the high-quality, dark-themed, and responsive aesthetic established in the newly updated Home Screen (Web & App). The goal is to make the entry points of the application more engaging and attractive to users while ensuring flawless responsiveness across both mobile and desktop views.

## Scope of Work
- **Auth Screen (`auth_screen.dart`):** Refactor the login and registration forms to use the dark theme (`#151515`, `#1E1E1E`), purple accents (`#6B4EFF`), and rounded aesthetics (Radius 16~20) found in the home screen.
- **Story Creation UI (`creation/mode_selection_screen.dart` / `wizard_screen.dart`):** Align the creation flow with the brand's new modern, clean dark mode. Ensure the blocky/pixel-art aesthetic (if kept) blends well with the sleek components, or update it to match the home screen's gradient and glassmorphism feels.
- **Responsiveness:** Ensure both screens look great on mobile (column layout, bottom nav if applicable) and desktop (centered cards, wide layout utilization, or sidebar integration if they are part of the main app shell).

## Checklists

### UI/UX Design Phase
- [x] Define the color palette and layout structure for Auth Screen (Mobile & Desktop).
- [x] Define the layout structure for the Story Creation Screens (Mode Selection & Wizard).
- [x] Document the design specs in `implementation_plan.md`.

### Frontend Implementation Phase
- [x] Update `auth_screen.dart` to apply the new UI/UX guidelines and ensure responsiveness (using `LayoutBuilder` or `ResponsiveLayout`).
- [x] Update `mode_selection_screen.dart` and related creation screens to match the new theme.
- [x] Verify there are no overflow errors on mobile views.
- [x] Verify desktop views do not stretch UI components unnaturally (e.g., max-width constraints on forms).

### QA & Validation Phase
- [x] Run `flutter analyze` to ensure no syntax errors.
- [x] Verify that UI transitions are smooth and no regressions occurred in the authentication flow or creation state logic.
- [x] Confirm visual consistency with `example_web_ui.png` aesthetic.

## Edge Cases to Consider
- Extremely wide desktop screens (forms should have a `maxWidth`).
- Small mobile screens (ensure scrollability so keyboard doesn't hide input fields).
- State retention during layout shifts (resizing the browser window shouldn't lose form data).
