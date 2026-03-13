# Implementation Plan: Auth & Story Creation UI Revamp

## 1. Auth Screen Revamp (`auth_screen.dart`)
**Goal**: Transform the login/registration screen to match the modern "StoryForge" dark aesthetic, ensuring it looks like a premium web application on desktop and a sleek app on mobile.

### Layout & Responsiveness
- **Desktop (Width >= 800)**: 
  - Split screen layout (`Row`). Left side: An engaging hero image or gradient branding graphic featuring the "StoryForge" concept. Right side: A centered, max-width constrained (`~400px`) login/signup card.
- **Mobile (Width < 800)**: 
  - Single column layout (`Column`). The form is centered vertically, taking up most of the screen width with appropriate padding (`24px`), without the hero image.

### Theming Details
- **Background**: Deep dark `#0D0D12` or `#121212`.
- **Form Card**: `Color(0xFF151515)` with a subtle `Border.all(color: Colors.white10)` and `BorderRadius.circular(20)`.
- **Inputs**: Solid filled background `#1E1E1E` or similar, with no borders until focused. Focused border color: `#6B4EFF`.
- **Buttons**: Primary CTA button should be vibrant `#6B4EFF` (purple) with `BorderRadius.circular(12)`.
- **Typography**: Crisp, white text for headings (`28px` or `32px` bold), and `Colors.white54` for labels and secondary text.

## 2. Story Creation UI Revamp
**Goal**: Make the `CreationModeSelectionScreen` and `WizardScreen` feel like an integrated part of the new dark theme, maintaining consistency with the Home Screen.

### Layout & Responsiveness (`mode_selection_screen.dart`)
- **Wrapper**: This screen is already wrapped in `ResponsiveLayout`, which handles the sidebar on desktop. We just need to polish the inner `Scaffold`.
- **Desktop & Mobile Handling**: 
  - Ensure the cards/options ("Quick Start", "Detailed Setup") do not stretch infinitely on desktop. Use a `Wrap` or constrain their `maxWidth` (e.g., `800px` total width for the content area) and center them.
  
### Theming Details
- **Background**: Change from the pure dark purple (`#0F0524`) or pixel art backgrounds to the unified `#121212` background, perhaps keeping subtle starry or gradient effects but making them less intrusive.
- **Cards**: 
  - Replace heavy "Pixel Bezel" borders with the sleek `#151515` card style with subtle `white10` borders and `Radius 20`.
  - Add hover effects or subtle glowing gradients (e.g., an animated `BoxShadow` with `#6B4EFF` opacity) to make the creation modes feel magical.
- **Typography**: Match the Home screen headings (bold, clean white).

## Action Items for UI/UX & Frontend
1. **[UI/UX Designer]**: Finalize these specs. The plan is clear, transitioning to Frontend implementation.
2. **[Frontend Developer]**: 
   - Open `auth_screen.dart` and refactor using `LayoutBuilder`.
   - Open `mode_selection_screen.dart` and refactor the visual components (`_PixelBezelCard`, backgrounds) to sleek modern cards.
   - Test locally for responsive overflows.