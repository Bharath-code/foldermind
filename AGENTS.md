


To help you build your macOS app, I have organized the key design principles and technical requirements mentioned in the video into a structured format that you can copy into a .md file for your AI IDE.

macOS App Design Reference Guide
1. System-First Integration 
Not a Destination: Apps should act as systems (like Spotlight or Raycast) that appear when needed and vanish when done.
Interaction Design: Use floating windows, popovers, and keyboard shortcuts (e.g., Command+Shift+S) to maintain accessibility.
Optimistic UI: Process tasks in the background and provide immediate visual feedback (e.g., move to trash before server confirmation).
2. Layout & Composition 
Content-First: Use a simple layout—top bar for global actions, main center area for content.
Drag to Move: Leave the top ~50px of the window free for dragging.
Progressive Disclosure: Hide filters or advanced data until the user actually needs them (e.g., clicking on an image).
Empty States: Provide clean, inviting empty states to guide users when no content exists.
3. Visuals & Color 
System Respect: Support both Light and Dark modes.
Refined Contrast: Don't just invert colors. Adjust brightness and saturation so that Light and Dark modes feel consistent but distinct.
4. Interaction & Feedback 
Universal Search: Make search prominent and accessible. Use image recognition/metadata to improve relevance.
Keyboard First: Include shortcuts for every major action, with visual reminders (e.g., in a settings popover).
Micro-Animations: Use state changes (e.g., expansion, collapse, toast notifications) to provide immediate feedback for all user actions.
Drag & Drop: Implement seamless drag-and-drop both into and out of your application.
5. Onboarding
Guided Experience: Use a simple modal to introduce the app and core shortcuts, similar to the process used by Raycast.
